from pathlib import Path

import librosa
import numpy as np

try:
    import noisereduce as nr
except ImportError:  # pragma: no cover - optional dependency at runtime
    nr = None


TARGET_SAMPLE_RATE = 16000
DEFAULT_TOP_DB = 28
MIN_AUDIO_SECONDS = 1.0


class PreprocessStats:
    def __init__(
        self,
        sample_rate,
        duration_seconds,
        trimmed_seconds,
        rms_before,
        rms_after,
        used_noise_reduction,
    ):
        self.sample_rate = sample_rate
        self.duration_seconds = duration_seconds
        self.trimmed_seconds = trimmed_seconds
        self.rms_before = rms_before
        self.rms_after = rms_after
        self.used_noise_reduction = used_noise_reduction


def preprocess_for_asr(audio_path, *, use_noise_reduction=True):
    path = Path(audio_path)
    samples, sample_rate = _load_asr_audio(path)

    if samples.size == 0:
        raise ValueError('Audio file is empty after loading.')

    duration_seconds = float(len(samples) / sample_rate)
    rms_before = _rms(samples)

    trimmed, _ = librosa.effects.trim(samples, top_db=DEFAULT_TOP_DB)
    if trimmed.size == 0:
        trimmed = samples

    trimmed_seconds = float(len(trimmed) / sample_rate)

    enhanced = trimmed
    used_noise_reduction = False
    if use_noise_reduction and nr is not None and trimmed_seconds >= MIN_AUDIO_SECONDS:
        noise_clip = _select_noise_profile(trimmed, sample_rate)
        if noise_clip.size > 0:
            try:
                # Moderate reduction removes fan/road noise without cutting
                # consonants from spoken Bangla names and digits.
                enhanced = nr.reduce_noise(
                    y=trimmed,
                    sr=sample_rate,
                    y_noise=noise_clip,
                    stationary=True,
                    prop_decrease=0.65,
                )
                used_noise_reduction = True
            except Exception:
                enhanced = trimmed

    normalized = _normalize_audio(enhanced)
    rms_after = _rms(normalized)

    stats = PreprocessStats(
        sample_rate=sample_rate,
        duration_seconds=duration_seconds,
        trimmed_seconds=trimmed_seconds,
        rms_before=rms_before,
        rms_after=rms_after,
        used_noise_reduction=used_noise_reduction,
    )
    return normalized, sample_rate, stats


def check_audio_quality(audio_path):
    samples, sample_rate = _load_asr_audio(Path(audio_path))
    duration_seconds = float(len(samples) / sample_rate) if sample_rate else 0.0
    rms = _rms(samples)
    frame_length = max(1, int(sample_rate * 0.20))
    frame_rms = [
        _rms(samples[index:index + frame_length])
        for index in range(0, len(samples), frame_length)
        if samples[index:index + frame_length].size
    ]
    noise_rms = float(np.percentile(frame_rms, 15)) if frame_rms else 0.0
    signal_rms = float(np.percentile(frame_rms, 85)) if frame_rms else rms
    estimated_snr_db = 20 * np.log10((signal_rms + 1e-8) / (noise_rms + 1e-8))
    clipping_ratio = float(np.mean(np.abs(samples) >= 0.985)) if samples.size else 0.0
    return {
        'duration': duration_seconds,
        'rms': rms,
        'noise_rms': noise_rms,
        'estimated_snr_db': float(estimated_snr_db),
        'clipping_ratio': clipping_ratio,
        'is_too_short': duration_seconds < 1.8,
        'is_silent': rms < 0.0035,
    }


def _select_noise_profile(samples, sample_rate):
    if samples.size == 0:
        return np.array([], dtype=np.float32)

    window_size = min(len(samples), int(sample_rate * 0.35))
    if window_size <= 0:
        return np.array([], dtype=np.float32)

    candidates = [
        samples[index:index + window_size]
        for index in range(0, max(1, len(samples) - window_size + 1), window_size)
    ]
    quieter = min(candidates, key=_rms)
    return quieter.astype(np.float32, copy=False)


def _normalize_audio(samples):
    if samples.size == 0:
        return samples.astype(np.float32, copy=False)

    samples = samples - np.mean(samples)
    peak = float(np.max(np.abs(samples)))
    rms = _rms(samples)
    if peak == 0.0 or rms == 0.0:
        return samples.astype(np.float32, copy=False)

    # Peak-only normalisation amplifies quiet background noise. Target a
    # speech RMS first, then keep the waveform below a safe peak.
    gain = min(8.0, 0.12 / rms)
    normalized = samples * gain
    normalized_peak = float(np.max(np.abs(normalized)))
    if normalized_peak > 0.92:
        normalized = normalized * (0.92 / normalized_peak)
    return normalized.astype(np.float32, copy=False)


def _load_asr_audio(path):
    """Load mono 16 kHz audio with a quality-first resampler."""
    try:
        return librosa.load(
            path.as_posix(),
            sr=TARGET_SAMPLE_RATE,
            mono=True,
            res_type='soxr_hq',
        )
    except Exception:
        return librosa.load(
            path.as_posix(),
            sr=TARGET_SAMPLE_RATE,
            mono=True,
            res_type='kaiser_fast',
        )


def _rms(samples):
    if samples.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(np.square(samples), dtype=np.float64)))
