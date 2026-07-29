# Render Deployment Guide for Bangla Voice CRM

This guide deploys the CRM API first. Deploy the ASR service separately after CRM login, companies, leads, and reports are working online.

## Why deploy CRM first?

The CRM API is lightweight compared with ASR. It handles login, JWT auth, users, companies, leads, reports, tracking, and audit logs. The ASR server uses heavy ML dependencies and is better hosted separately.

## Files prepared in this repo

- `backend/requirements-crm.txt`: only CRM dependencies
- `backend/requirements-asr.txt`: only ASR dependencies
- `backend/.env.render.example`: example environment variables
- `render.yaml`: Render blueprint for the CRM API and PostgreSQL

## Step 1: Push this project to GitHub

Why: Render deploys from a GitHub repository.

1. Create a GitHub repository.
2. Push `E:\cse499\bangla_voice_crm` to GitHub.

## Step 2: Deploy with Render Blueprint

Why: `render.yaml` creates the PostgreSQL database and CRM web service with the right commands.

1. Log in to Render.
2. Click **New** -> **Blueprint**.
3. Select your GitHub repo.
4. Render will detect `render.yaml`.
5. Continue the setup.

## Step 3: Set the required secret values

Why: a few values should not be hardcoded into version control.

In the Render dashboard, set these values if Render asks for them:

- `CRM_BOOTSTRAP_ADMIN_PASSWORD`
- `CRM_PUBLIC_BASE_URL`

Recommended values:

- `CRM_BOOTSTRAP_ADMIN_PASSWORD=ChangeThisNow123`
- `CRM_PUBLIC_BASE_URL=https://your-service-name.onrender.com`

After deploy succeeds, your main service URL will be something like:

- `https://bangla-voice-crm-api.onrender.com`

Use that real URL for `CRM_PUBLIC_BASE_URL` if needed, then redeploy.

## Step 4: Verify the deployment

Why: before testing from the mobile app, make sure the API and database are alive.

Open:

- `/health`
- `/docs`

Example:

- `https://your-service-name.onrender.com/health`
- `https://your-service-name.onrender.com/docs`

You should see:

- `status: ok`
- `database: connected`

## Step 5: First SuperAdmin login

Why: this verifies bootstrap admin creation and tenant bootstrap both worked.

Use these values in the mobile app:

- CRM API URL: `https://your-service-name.onrender.com`
- Company Slug: `platform-default`
- Username: `admin`
- Password: your `CRM_BOOTSTRAP_ADMIN_PASSWORD`

## Step 6: Create company workspaces from the app

Why: your app is now multi-tenant. Each company gets separate users and data.

After login as `SuperAdmin`:

1. Open **Company Management**
2. Create a company, for example:
   - Name: `Demo Company A`
   - Slug: `demo-a`
   - Admin Username: `admin_a`
   - Admin Password: `AdminA123`
3. Log out.
4. Log in with:
   - Company Slug: `demo-a`
   - Username: `admin_a`
   - Password: `AdminA123`

## Step 7: Verify tenant isolation

Why: this is the most important SaaS behavior in your project.

Test this way:

1. Create `Demo Company A`
2. Create `Demo Company B`
3. Add users/leads/reports inside company A
4. Log in as company B admin
5. Confirm company B cannot see company A data

## Step 8: Point the mobile app to the public CRM backend

Why: once deployed, users should not depend on your laptop IP or Wi-Fi.

In app settings:

- CRM API URL -> `https://your-service-name.onrender.com`

Do not use a local `192.168.x.x` address anymore for CRM after deployment.

## Step 9: Deploy ASR separately

Why: BanglaASR is heavy and should not compete with CRM auth and data APIs.

Use `backend/requirements-asr.txt` when deploying the ASR server.

Recommended ASR start command:

```bash
python -m uvicorn backend.asr_server:app --host 0.0.0.0 --port $PORT
```

Recommended ASR environment variables:

```txt
BANGLA_ASR_MODEL_ID=bangla-speech-processing/BanglaASR
BANGLA_ASR_DEVICE=cpu
BANGLA_ASR_CPU_THREADS=4
BANGLA_ASR_JOB_WORKERS=1
BANGLA_ASR_MAX_AUDIO_MB=50
```

## Step 10: Point the app to the public ASR backend

Why: after ASR is public, speech transcription will work for all users.

In app settings:

- ASR API URL -> `https://your-asr-domain.com/transcribe`

## Notes for production readiness

- Use a strong random value for `CRM_JWT_SECRET`
- Change the bootstrap admin password after first login
- Keep `CRM_EXPOSE_RESET_TOKENS=false` in production
- Back up the PostgreSQL database regularly
- Add proper cloud file storage later for uploaded media instead of relying on local service disk
