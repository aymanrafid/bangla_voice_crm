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
    samples, sample_rate = librosa.load(
        path.as_posix(),
        sr=TARGET_SAMPLE_RATE,
        mono=True,
        res_type='kaiser_fast',
    )

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
            enhanced = nr.reduce_noise(
                y=trimmed,
                sr=sample_rate,
                y_noise=noise_clip,
                stationary=True,
                prop_decrease=0.85,
            )
            used_noise_reduction = True

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
    samples, sample_rate = librosa.load(
        Path(audio_path).as_posix(),
        sr=TARGET_SAMPLE_RATE,
        mono=True,
        res_type='kaiser_fast',
    )
    duration_seconds = float(len(samples) / sample_rate) if sample_rate else 0.0
    rms = _rms(samples)
    return {
        'duration': duration_seconds,
        'rms': rms,
        'is_too_short': duration_seconds < 1.8,
        'is_silent': rms < 0.0035,
    }


def _select_noise_profile(samples, sample_rate):
    if samples.size == 0:
        return np.array([], dtype=np.float32)

    window_size = min(len(samples), int(sample_rate * 0.35))
    if window_size <= 0:
        return np.array([], dtype=np.float32)

    first_window = samples[:window_size]
    last_window = samples[-window_size:]
    quieter = first_window if _rms(first_window) <= _rms(last_window) else last_window
    return quieter.astype(np.float32, copy=False)


def _normalize_audio(samples):
    peak = float(np.max(np.abs(samples))) if samples.size else 0.0
    if peak == 0.0:
        return samples.astype(np.float32, copy=False)

    normalized = samples / peak
    target_peak = 0.92
    normalized = normalized * target_peak
    return normalized.astype(np.float32, copy=False)


def _rms(samples):
    if samples.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(np.square(samples), dtype=np.float64)))
