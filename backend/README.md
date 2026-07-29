# Bangla Voice CRM ASR Backend

This backend runs a self-hosted Bangla ASR model for the Flutter app.
By default it uses:

`bangla-speech-processing/BanglaASR`

Pipeline:
1. accept uploaded mobile audio
2. load and resample to 16 kHz mono
3. trim leading and trailing silence
4. apply stationary noise reduction when possible
5. normalize audio level
6. transcribe with BanglaASR
7. return transcript, debug info, and errors in a Flutter-friendly JSON format

## Setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m uvicorn asr_server:app --host 0.0.0.0 --port 8000
```

Then use this in the Flutter app Settings screen:

`http://<your-pc-ip>:8000/transcribe`

Example on the same Wi-Fi:

`http://192.168.0.113:8000/transcribe`

## Endpoints

- `/` : health check
- `/model-info` : active model/device configuration
- `/transcribe` : ASR endpoint used by Flutter

## Environment variables

```bash
BANGLA_ASR_MODEL_ID=bangla-speech-processing/BanglaASR
BANGLA_ASR_DEVICE=cuda:0
BANGLA_ASR_MIN_SECONDS=1.8
BANGLA_ASR_CHUNK_SECONDS=20
BANGLA_ASR_BATCH_SIZE=8
BANGLA_ASR_RETURN_TIMINGS=true
```

Set `BANGLA_ASR_DEVICE=cpu` if no GPU is available.

## Notes

- The server is fully self-hosted. No outside ASR API is required.
- `noisereduce` is optional but improves noisy recordings.
- The `debug` field helps diagnose silence, duration, RMS, and latency.
- For best CRM accuracy, pair ASR with transcript correction and post-processing for phone numbers and addresses.
