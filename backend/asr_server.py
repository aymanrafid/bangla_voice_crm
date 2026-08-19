import os
import re
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from tempfile import NamedTemporaryFile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import librosa
import numpy as np
import torch
from transformers import pipeline

try:
    from .audio_preprocessing import (
        DEFAULT_TOP_DB,
        check_audio_quality,
        preprocess_for_asr,
    )
except ImportError:  # Allows running with `uvicorn asr_server:app` from backend/.
    from audio_preprocessing import (  # type: ignore
        DEFAULT_TOP_DB,
        check_audio_quality,
        preprocess_for_asr,
    )


MODEL_ID = os.getenv('BANGLA_ASR_MODEL_ID', 'bangla-speech-processing/BanglaASR')
DEVICE = os.getenv('BANGLA_ASR_DEVICE', 'cuda:0')
MIN_AUDIO_SECONDS = float(os.getenv('BANGLA_ASR_MIN_SECONDS', '1.8'))
RETURN_TIMINGS = os.getenv('BANGLA_ASR_RETURN_TIMINGS', 'true').lower() == 'true'
CPU_CHUNK_SECONDS = int(os.getenv('BANGLA_ASR_CPU_CHUNK_SECONDS', '8'))
GPU_CHUNK_SECONDS = int(os.getenv('BANGLA_ASR_GPU_CHUNK_SECONDS', '20'))
CPU_BATCH_SIZE = int(os.getenv('BANGLA_ASR_CPU_BATCH_SIZE', '1'))
GPU_BATCH_SIZE = int(os.getenv('BANGLA_ASR_GPU_BATCH_SIZE', '8'))
CPU_THREADS = int(os.getenv('BANGLA_ASR_CPU_THREADS', '4'))
NOISE_REDUCTION_MODE = os.getenv('BANGLA_ASR_NOISE_REDUCTION', 'auto').lower()
JOB_WORKERS = max(1, int(os.getenv('BANGLA_ASR_JOB_WORKERS', '1')))
JOB_RETENTION_MINUTES = max(10, int(os.getenv('BANGLA_ASR_JOB_RETENTION_MINUTES', '180')))
CPU_SEGMENT_SECONDS = float(os.getenv('BANGLA_ASR_CPU_SEGMENT_SECONDS', '12'))
GPU_SEGMENT_SECONDS = float(os.getenv('BANGLA_ASR_GPU_SEGMENT_SECONDS', '24'))
SEGMENT_MIN_SECONDS = float(os.getenv('BANGLA_ASR_SEGMENT_MIN_SECONDS', '2.0'))
SEGMENT_PAD_SECONDS = float(os.getenv('BANGLA_ASR_SEGMENT_PAD_SECONDS', '0.15'))
SEGMENT_SPLIT_TOP_DB = int(os.getenv('BANGLA_ASR_SEGMENT_SPLIT_TOP_DB', str(DEFAULT_TOP_DB)))
MAX_AUDIO_MB = int(os.getenv('BANGLA_ASR_MAX_AUDIO_MB', '50'))
MAX_SYNC_SECONDS = float(os.getenv('BANGLA_ASR_MAX_SYNC_SECONDS', '45'))
LANGUAGE = os.getenv('BANGLA_ASR_LANGUAGE', 'bn')
# Default OFF: Bangladeshi mobile numbers legitimately repeat digits, and a
# dictated 01711117777 produces repeated n-grams that this would suppress,
# corrupting valid numbers. repetition_penalty plus condition_on_prev_tokens
# handle the runaway-loop case without that risk. Raise it only if loops return.
NO_REPEAT_NGRAM = int(os.getenv('BANGLA_ASR_NO_REPEAT_NGRAM', '0'))
REPETITION_PENALTY = float(os.getenv('BANGLA_ASR_REPETITION_PENALTY', '1.15'))
CONDITION_ON_PREV = os.getenv('BANGLA_ASR_CONDITION_ON_PREV', 'false').lower() == 'true'
_generate_kwargs_supported = True

_model_lock = threading.Lock()
_asr_pipe = None
_startup_error = None
_loaded_device = 'unknown'
_runtime_chunk_seconds = CPU_CHUNK_SECONDS
_runtime_batch_size = CPU_BATCH_SIZE
_jobs_lock = threading.Lock()
_jobs: dict[str, 'AsrJob'] = {}
_job_executor = ThreadPoolExecutor(max_workers=JOB_WORKERS, thread_name_prefix='bangla-asr-job')


@dataclass
class TranscriptionOutcome:
    text: str
    debug: str
    error: str = ''
    chunk_count: int = 0
    duration_seconds: float = 0.0
    latency_ms: float = 0.0


@dataclass
class AsrJob:
    job_id: str
    filename: str
    temp_path: str
    status: str = 'queued'
    progress: int = 0
    stage: str = 'queued'
    message: str = 'Waiting to start.'
    text: str = ''
    debug: str = ''
    error: str = ''
    chunk_count: int = 0
    completed_chunks: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    completed_at: datetime | None = None

    def to_dict(self):
        return {
            'job_id': self.job_id,
            'status': self.status,
            'progress': self.progress,
            'stage': self.stage,
            'message': self.message,
            'text': self.text,
            'debug': self.debug,
            'error': self.error,
            'chunk_count': self.chunk_count,
            'completed_chunks': self.completed_chunks,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat(),
            'completed_at': self.completed_at.isoformat() if self.completed_at else None,
            'filename': self.filename,
        }


def _resolve_device(value: str):
    normalized = value.strip().lower()
    if normalized == 'cpu':
        return -1
    if normalized in {'cuda', 'cuda:0'}:
        return 0 if torch.cuda.is_available() else -1
    if normalized.startswith('cuda:'):
        if torch.cuda.is_available():
            try:
                return int(normalized.split(':', 1)[1])
            except ValueError:
                return 0
        return -1
    return value


def _device_label(device_value) -> str:
    if device_value == -1:
        return 'cpu'
    if isinstance(device_value, int):
        return f'cuda:{device_value}'
    return str(device_value)


def _should_use_noise_reduction(is_cpu: bool) -> bool:
    if NOISE_REDUCTION_MODE == 'always':
        return True
    if NOISE_REDUCTION_MODE == 'never':
        return False
    return not is_cpu


def _segment_seconds() -> float:
    return CPU_SEGMENT_SECONDS if _loaded_device == 'cpu' else GPU_SEGMENT_SECONDS


def _load_pipeline():
    global _asr_pipe, _startup_error, _loaded_device
    global _runtime_batch_size, _runtime_chunk_seconds
    if _asr_pipe is not None:
        return _asr_pipe

    resolved_device = _resolve_device(DEVICE)
    _loaded_device = _device_label(resolved_device)
    is_cpu = resolved_device == -1
    _runtime_chunk_seconds = CPU_CHUNK_SECONDS if is_cpu else GPU_CHUNK_SECONDS
    _runtime_batch_size = CPU_BATCH_SIZE if is_cpu else GPU_BATCH_SIZE

    if is_cpu:
        torch.set_num_threads(max(1, CPU_THREADS))
        try:
            torch.set_num_interop_threads(max(1, min(2, CPU_THREADS)))
        except RuntimeError:
            pass

    try:
        kwargs = {
            'task': 'automatic-speech-recognition',
            'model': MODEL_ID,
            'device': resolved_device,
            'model_kwargs': {'low_cpu_mem_usage': True},
        }
        kwargs['torch_dtype'] = torch.float32 if is_cpu else torch.float16

        _asr_pipe = pipeline(**kwargs)
        _startup_error = None
        return _asr_pipe
    except Exception as exc:  # pragma: no cover - runtime startup safety
        _startup_error = f'{type(exc).__name__}: {exc}'
        raise


app = FastAPI(title='Bangla Voice CRM ASR Server')
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.on_event('startup')
def _startup():
    _load_pipeline()


@app.get('/')
def healthcheck():
    return {
        'status': 'ok' if _startup_error is None else 'degraded',
        'service': 'Bangla Voice CRM ASR',
        'model': MODEL_ID,
        'device': _loaded_device,
        'startup_error': _startup_error or '',
        'async_jobs': True,
        'segment_seconds': _segment_seconds(),
    }


@app.get('/model-info')
def model_info():
    return {
        'model': MODEL_ID,
        'device': _loaded_device,
        'min_audio_seconds': MIN_AUDIO_SECONDS,
        'chunk_seconds': _runtime_chunk_seconds,
        'segment_seconds': _segment_seconds(),
        'batch_size': _runtime_batch_size,
        'cpu_threads': CPU_THREADS,
        'noise_reduction_mode': NOISE_REDUCTION_MODE,
        'job_workers': JOB_WORKERS,
        'startup_error': _startup_error or '',
    }


@app.post('/transcribe')
async def transcribe_audio(audio: UploadFile = File(...)):
    temp_path = _save_upload_to_temp(audio)
    started_at = time.perf_counter()
    try:
        outcome = _transcribe_audio_file(temp_path)
        if outcome.error:
            return {
                'text': '',
                'debug': outcome.debug,
                'error': outcome.error,
            }
        debug = outcome.debug
        if RETURN_TIMINGS:
            debug = f'{debug}; latency_ms={(time.perf_counter() - started_at) * 1000:.0f}'
        return {
            'text': outcome.text,
            'debug': debug,
            'error': '',
        }
    except Exception as exc:  # pragma: no cover - runtime safety
        return {
            'text': '',
            'debug': f'failure={type(exc).__name__}; device={_loaded_device}',
            'error': f'Transcription failed: {exc}',
        }
    finally:
        _remove_file(temp_path)


@app.post('/transcribe-jobs')
async def submit_transcription_job(audio: UploadFile = File(...)):
    _prune_jobs()
    temp_path = _save_upload_to_temp(audio)
    filename = audio.filename or Path(temp_path).name
    file_size = Path(temp_path).stat().st_size
    if file_size > MAX_AUDIO_MB * 1024 * 1024:
        _remove_file(temp_path)
        raise HTTPException(
            status_code=413,
            detail=f'Audio file is too large. Maximum supported size is {MAX_AUDIO_MB} MB.',
        )

    job = AsrJob(
        job_id=uuid.uuid4().hex,
        filename=filename,
        temp_path=temp_path,
        message='Audio uploaded. Waiting in queue.',
    )
    with _jobs_lock:
        _jobs[job.job_id] = job
    _job_executor.submit(_run_job, job.job_id)
    return job.to_dict()


@app.get('/transcribe-jobs/{job_id}')
def get_transcription_job(job_id: str):
    _prune_jobs()
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail='Transcription job not found.')
        return job.to_dict()


def _run_job(job_id: str):
    job = _get_job(job_id)
    if job is None:
        return
    try:
        _update_job(
            job_id,
            status='processing',
            progress=5,
            stage='loading_model',
            message='Preparing ASR model.',
        )
        outcome = _transcribe_audio_file(job.temp_path, job_id=job_id)
        if outcome.error:
            _update_job(
                job_id,
                status='failed',
                progress=100,
                stage='failed',
                message=outcome.error,
                error=outcome.error,
                debug=outcome.debug,
                completed_at=datetime.utcnow(),
            )
        else:
            _update_job(
                job_id,
                status='completed',
                progress=100,
                stage='completed',
                message='Transcription complete.',
                text=outcome.text,
                debug=outcome.debug,
                chunk_count=outcome.chunk_count,
                completed_chunks=outcome.chunk_count,
                completed_at=datetime.utcnow(),
            )
    except Exception as exc:  # pragma: no cover - runtime safety
        _update_job(
            job_id,
            status='failed',
            progress=100,
            stage='failed',
            message=f'Transcription failed: {exc}',
            error=f'Transcription failed: {exc}',
            debug=f'failure={type(exc).__name__}; device={_loaded_device}',
            completed_at=datetime.utcnow(),
        )
    finally:
        if job is not None:
            _remove_file(job.temp_path)


def _transcribe_audio_file(audio_path: str, *, job_id: str | None = None) -> TranscriptionOutcome:
    started_at = time.perf_counter()
    pipe = _load_pipeline()
    quality = check_audio_quality(audio_path)
    if quality['duration'] < MIN_AUDIO_SECONDS:
        return TranscriptionOutcome(
            text='',
            debug=_debug_line(quality=quality),
            error=(
                f'Audio too short ({quality["duration"]:.2f}s). '
                f'Speak for at least {MIN_AUDIO_SECONDS:.1f} seconds.'
            ),
            duration_seconds=quality['duration'],
        )
    if quality['is_silent']:
        return TranscriptionOutcome(
            text='',
            debug=_debug_line(quality=quality),
            error='Audio is too quiet or mostly silent. Please speak closer to the microphone.',
            duration_seconds=quality['duration'],
        )

    _update_job_if_needed(
        job_id,
        progress=10,
        stage='preprocessing',
        message='Reducing noise and trimming silence.',
    )
    use_noise_reduction = _should_use_noise_reduction(_loaded_device == 'cpu')
    processed_audio, sample_rate, prep = preprocess_for_asr(
        audio_path,
        use_noise_reduction=use_noise_reduction,
    )

    segment_seconds = _segment_seconds()
    segments = _segment_audio(processed_audio, sample_rate, segment_seconds)
    if not segments:
        segments = [processed_audio]

    total_chunks = len(segments)
    _update_job_if_needed(
        job_id,
        progress=18,
        stage='segmenting',
        message=f'Split audio into {total_chunks} chunk(s).',
        chunk_count=total_chunks,
        completed_chunks=0,
    )

    texts: list[str] = []
    for index, segment in enumerate(segments, start=1):
        segment_duration = len(segment) / sample_rate
        _update_job_if_needed(
            job_id,
            progress=min(95, 20 + int(((index - 1) / total_chunks) * 70)),
            stage='transcribing',
            message=f'Transcribing chunk {index} of {total_chunks} ({segment_duration:.1f}s).',
            chunk_count=total_chunks,
            completed_chunks=index - 1,
        )
        with _model_lock:
            result = _run_pipeline(
                pipe,
                segment,
                sample_rate,
                chunk_length_s=max(1, min(_runtime_chunk_seconds, int(np.ceil(segment_duration)) or 1)),
            )
        text = _normalize_text(result.get('text') or '')
        if text:
            texts.append(text)
        _update_job_if_needed(
            job_id,
            progress=min(95, 20 + int((index / total_chunks) * 70)),
            stage='transcribing',
            message=f'Finished chunk {index} of {total_chunks}.',
            chunk_count=total_chunks,
            completed_chunks=index,
        )

    transcript = _merge_chunk_texts(texts)
    elapsed_ms = (time.perf_counter() - started_at) * 1000
    debug = (
        f'model={MODEL_ID}; '
        f'device={_loaded_device}; '
        f'duration={quality["duration"]:.2f}s; '
        f'trimmed={prep.trimmed_seconds:.2f}s; '
        f'noise_reduction={prep.used_noise_reduction}; '
        f'rms_before={prep.rms_before:.4f}; '
        f'rms_after={prep.rms_after:.4f}; '
        f'chunk_seconds={_runtime_chunk_seconds}; '
        f'segment_seconds={segment_seconds:.1f}; '
        f'segment_count={total_chunks}; '
        f'batch_size={_runtime_batch_size}'
    )
    if RETURN_TIMINGS:
        debug = f'{debug}; latency_ms={elapsed_ms:.0f}'
    return TranscriptionOutcome(
        text=transcript,
        debug=debug,
        chunk_count=total_chunks,
        duration_seconds=quality['duration'],
        latency_ms=elapsed_ms,
    )


def _segment_audio(samples: np.ndarray, sample_rate: int, max_seconds: float) -> list[np.ndarray]:
    if samples.size == 0:
        return []
    max_len = max(1, int(max_seconds * sample_rate))
    min_len = max(1, int(SEGMENT_MIN_SECONDS * sample_rate))
    pad = int(SEGMENT_PAD_SECONDS * sample_rate)
    intervals = librosa.effects.split(samples, top_db=SEGMENT_SPLIT_TOP_DB)
    if len(intervals) == 0:
        return _fixed_chunks(samples, max_len)

    ranges: list[tuple[int, int]] = []
    current_start: int | None = None
    current_end: int | None = None

    for raw_start, raw_end in intervals:
        start = max(0, int(raw_start) - pad)
        end = min(len(samples), int(raw_end) + pad)
        if current_start is None:
            current_start, current_end = start, end
            continue
        assert current_end is not None
        if end - current_start <= max_len:
            current_end = end
            continue
        ranges.extend(_split_range(current_start, current_end, max_len))
        current_start, current_end = start, end

    if current_start is not None and current_end is not None:
        ranges.extend(_split_range(current_start, current_end, max_len))

    if not ranges:
        return _fixed_chunks(samples, max_len)

    merged: list[np.ndarray] = []
    for start, end in ranges:
        chunk = samples[start:end].astype(np.float32, copy=False)
        if chunk.size == 0:
            continue
        if merged and chunk.size < min_len:
            previous = merged.pop()
            if previous.size + chunk.size <= max_len:
                merged.append(np.concatenate([previous, chunk]).astype(np.float32, copy=False))
            else:
                merged.append(previous)
                merged.append(chunk)
        else:
            merged.append(chunk)

    return merged or _fixed_chunks(samples, max_len)


def _split_range(start: int, end: int, max_len: int) -> list[tuple[int, int]]:
    if end - start <= max_len:
        return [(start, end)]
    items: list[tuple[int, int]] = []
    cursor = start
    while cursor < end:
        next_cursor = min(end, cursor + max_len)
        items.append((cursor, next_cursor))
        cursor = next_cursor
    return items


def _fixed_chunks(samples: np.ndarray, max_len: int) -> list[np.ndarray]:
    return [
        samples[index:index + max_len].astype(np.float32, copy=False)
        for index in range(0, len(samples), max_len)
        if samples[index:index + max_len].size > 0
    ]


_NUMBER_WORDS = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    '?????', '????', '??', '???', '???', '???', '????', '??', '???', '???', '??', '??', '???',
    '?', '?', '?', '?', '?', '?', '?', '?', '?', '?',
}


def _decode_kwargs() -> dict:
    """Whisper decoding settings that suppress runaway repetition.

    Without these the decoder loops on unclear audio - long spoken digit
    sequences are the worst case - emitting near-identical tokens that the
    exact-match collapsers downstream cannot catch, plus partial byte
    sequences that decode to the Unicode replacement character.
    """
    return {
        # Pin the language. Left to auto-detect it can drift per chunk and
        # degrade badly mid-utterance.
        'language': LANGUAGE,
        'task': 'transcribe',
        # Hard block on repeating any n-gram: the direct fix for the loop.
        **({'no_repeat_ngram_size': NO_REPEAT_NGRAM} if NO_REPEAT_NGRAM > 0 else {}),
        'repetition_penalty': REPETITION_PENALTY,
        # Critical: stops a chunk's own looping output being fed back as
        # context for the next chunk, which is what lets a loop compound.
        'condition_on_prev_tokens': CONDITION_ON_PREV,
    }


def _run_pipeline(pipe, segment, sample_rate: int, *, chunk_length_s: int):
    """Transcribe one segment, degrading gracefully if kwargs are rejected.

    Model and library versions differ in which generation kwargs they accept,
    and a rejected kwarg must not take the whole service down - so on the first
    failure this falls back to a bare call and stops retrying.
    """
    global _generate_kwargs_supported
    payload = {'array': segment, 'sampling_rate': sample_rate}
    if _generate_kwargs_supported:
        try:
            return pipe(
                payload,
                chunk_length_s=chunk_length_s,
                batch_size=_runtime_batch_size,
                return_timestamps=False,
                generate_kwargs=_decode_kwargs(),
            )
        except (TypeError, ValueError) as exc:
            _generate_kwargs_supported = False
            print(f'[asr] generation kwargs rejected, falling back: {exc}')
    return pipe(
        payload,
        chunk_length_s=chunk_length_s,
        batch_size=_runtime_batch_size,
        return_timestamps=False,
    )


def _merge_chunk_texts(texts: list[str]) -> str:
    merged_tokens: list[str] = []
    for text in texts:
        incoming = _normalize_text(text).split()
        if not incoming:
            continue
        if not merged_tokens:
            merged_tokens.extend(incoming)
            continue

        overlap = 0
        max_overlap = min(8, len(merged_tokens), len(incoming))
        for size in range(max_overlap, 0, -1):
            if merged_tokens[-size:] == incoming[:size]:
                overlap = size
                break
        merged_tokens.extend(incoming[overlap:])

    return _normalize_text(' '.join(merged_tokens))


def _normalize_text(text: str) -> str:
    # U+FFFD appears when the decoder emits a partial multi-byte sequence
    # during a repetition loop. It is never valid output, so drop it.
    text = text.replace(chr(0xFFFD), '')
    normalized = ' '.join(text.replace('\n', ' ').split()).strip()
    if not normalized:
        return ''

    tokens = normalized.split()
    tokens = _collapse_repeated_tokens(tokens)
    tokens = _collapse_repeated_phrases(tokens)
    tokens = _collapse_repeated_tokens(tokens)
    return ' '.join(tokens).strip()


def _collapse_repeated_tokens(tokens: list[str], *, max_repeats: int = 2) -> list[str]:
    collapsed: list[str] = []
    previous = None
    repeat_count = 0

    for token in tokens:
        lowered = token.lower()
        if lowered == previous and not _is_sensitive_token(lowered):
            repeat_count += 1
            if repeat_count <= max_repeats:
                collapsed.append(token)
            continue

        previous = lowered
        repeat_count = 1
        collapsed.append(token)

    return collapsed


def _collapse_repeated_phrases(tokens: list[str]) -> list[str]:
    if len(tokens) < 4:
        return tokens

    collapsed: list[str] = []
    index = 0
    while index < len(tokens):
        matched = False
        max_size = min(5, (len(tokens) - index) // 2)
        for size in range(max_size, 1, -1):
            phrase = tokens[index:index + size]
            lowered = [item.lower() for item in phrase]
            if any(_is_sensitive_token(item) for item in lowered):
                continue

            repeats = 1
            while index + ((repeats + 1) * size) <= len(tokens):
                candidate = tokens[index + repeats * size:index + (repeats + 1) * size]
                if [item.lower() for item in candidate] != lowered:
                    break
                repeats += 1

            if repeats >= 2:
                collapsed.extend(phrase)
                index += repeats * size
                matched = True
                break

        if not matched:
            collapsed.append(tokens[index])
            index += 1

    return collapsed


def _is_sensitive_token(token: str) -> bool:
    lowered = token.lower()
    return lowered in _NUMBER_WORDS or bool(re.fullmatch(r'[0-9?-?]+', lowered))


def _save_upload_to_temp(audio: UploadFile) -> str:
    raw_suffix = Path(audio.filename or 'audio.wav').suffix or '.wav'
    with NamedTemporaryFile(prefix='asr_raw_', suffix=raw_suffix, delete=False) as raw_temp:
        raw_temp.write(audio.file.read())
        return raw_temp.name


def _update_job(job_id: str, **changes):
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            return
        for key, value in changes.items():
            setattr(job, key, value)
        job.updated_at = datetime.utcnow()


def _update_job_if_needed(job_id: str | None, **changes):
    if job_id:
        _update_job(job_id, **changes)


def _get_job(job_id: str) -> AsrJob | None:
    with _jobs_lock:
        return _jobs.get(job_id)


def _remove_file(path: str):
    if path and os.path.exists(path):
        try:
            os.unlink(path)
        except OSError:
            pass


def _prune_jobs():
    cutoff = datetime.utcnow() - timedelta(minutes=JOB_RETENTION_MINUTES)
    stale: list[AsrJob] = []
    with _jobs_lock:
        stale_ids = [job_id for job_id, job in _jobs.items() if job.updated_at < cutoff]
        for job_id in stale_ids:
            stale.append(_jobs.pop(job_id))
    for job in stale:
        _remove_file(job.temp_path)


def _debug_line(*, quality):
    return (
        f'model={MODEL_ID}; '
        f'device={_loaded_device}; '
        f'duration={quality["duration"]:.2f}s; '
        f'rms={quality["rms"]:.4f}; '
        f'is_too_short={quality["is_too_short"]}; '
        f'is_silent={quality["is_silent"]}; '
        f'chunk_seconds={_runtime_chunk_seconds}; '
        f'segment_seconds={_segment_seconds():.1f}; '
        f'batch_size={_runtime_batch_size}'
    )
