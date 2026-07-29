# Render ASR Deployment Guide for Bangla Voice CRM

This guide deploys the BanglaASR server as a separate web service from the CRM API.

## Why deploy ASR separately?

The ASR server loads a Hugging Face speech model, uses PyTorch, processes audio chunks, and can take much more CPU and memory than the CRM API. Keeping ASR separate prevents voice jobs from slowing login, users, leads, and reporting.

## Files prepared in this repo

- `backend/requirements-asr.txt`: ASR-only Python dependencies
- `backend/.env.render.asr.example`: example ASR environment variables
- `render.asr.yaml`: Render blueprint for the ASR web service

## Important reality before you deploy

Render free services are usually too weak for stable speech model hosting. Use at least the `starter` plan for the ASR service. This is why `render.asr.yaml` is set to `plan: starter`.

If the service still runs out of memory or restarts often, use Railway, Azure VM, or another stronger host for ASR.

## Step 1: Push the latest repo changes to GitHub

Why: Render deploys from your repository.

```powershell
git add backend/.env.render.asr.example render.asr.yaml docs/DEPLOY_ASR_RENDER.md
git commit -m "Prepare ASR Render deployment"
git push
```

## Step 2: Create the ASR Blueprint in Render

Why: this creates a separate ASR web service with the correct build and start commands.

1. Open Render dashboard.
2. Click **New** -> **Blueprint**.
3. Select your `bangla_voice_crm` repository again.
4. In **Blueprint Path**, enter:

```txt
render.asr.yaml
```

5. Give the blueprint a name like:

```txt
bangla-voice-asr-prod
```

## Step 3: Set optional secret values

Why: Hugging Face can rate-limit anonymous downloads. A token makes the initial model download more reliable.

Set this if possible:

- `HF_TOKEN`

If you do not have one yet, you can leave it blank and try the deploy first.

## Step 4: Deploy the ASR service

Why: this starts the online ASR API.

Render will use:

- Build command:

```bash
pip install -r backend/requirements-asr.txt
```

- Start command:

```bash
python -m uvicorn backend.asr_server:app --host 0.0.0.0 --port $PORT
```

## Step 5: Wait for the first startup

Why: the first startup may take much longer than normal because the model may need to download from Hugging Face.

Be patient during the first deploy. The service can take several minutes depending on network speed and model download time.

## Step 6: Verify the ASR service

Open these URLs after deploy:

- `/`
- `/model-info`

Example:

- `https://your-asr-service.onrender.com/`
- `https://your-asr-service.onrender.com/model-info`

Good signs:

- `status: ok`
- `startup_error` is empty
- `device: cpu`
- `model` shows `bangla-speech-processing/BanglaASR`

## Step 7: Connect the mobile app

In app settings, set:

- CRM API URL -> your CRM Render URL
- ASR API URL -> `https://your-asr-service.onrender.com/transcribe`

Example:

- `https://bangla-voice-crm-api.onrender.com`
- `https://bangla-voice-asr-api.onrender.com/transcribe`

## Step 8: Test transcription

Why: this confirms the phone can reach the public ASR service and the model is loaded.

1. Open the app.
2. Go to voice input.
3. Record a short Bangla sample.
4. Wait for transcript response.

## If deployment fails

Common causes:

- out-of-memory during model load
- slow Hugging Face download
- missing `HF_TOKEN`
- plan too small for model startup

If Render shows memory-related crashes or repeated restarts, move ASR to a stronger host.

## Recommended production next step

For serious production use:

- keep CRM on Render or similar PaaS
- move ASR to a stronger CPU/GPU machine
- keep the app pointed at the public `/transcribe` endpoint
