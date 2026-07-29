# Bangla Voice CRM Production Upgrade Guide

This project now supports a production-oriented CRM API foundation in addition to the local BanglaASR server.

## What was added

- `backend/crm_server.py`
  - JWT login
  - role-based access for `Admin`, `Manager`, `Employee`
  - users API
  - leads API
  - field tracking API
  - field reports API
  - audit logs API
  - sync changes API
  - password reset token flow
- SQLAlchemy-backed storage with PostgreSQL-ready configuration
- Flutter auth mode that switches to remote production auth when a CRM API URL is configured
- settings fields for both:
  - production CRM API base URL
  - BanglaASR `/transcribe` URL

## Local startup

### 1. Install dependencies

```powershell
cd E:\cse499\bangla_voice_crm\backend
python -m pip install -r requirements.txt
```

### 2. Set environment variables

```powershell
$env:CRM_DATABASE_URL="sqlite:///./crm_prod.db"
$env:CRM_JWT_SECRET="replace-with-a-long-random-secret"
$env:CRM_BOOTSTRAP_ADMIN_USERNAME="admin"
$env:CRM_BOOTSTRAP_ADMIN_PASSWORD="ChangeThisNow123"
$env:CRM_BOOTSTRAP_ADMIN_FULL_NAME="System Admin"
```

For PostgreSQL:

```powershell
$env:CRM_DATABASE_URL="postgresql+psycopg://postgres:password@localhost:5432/bangla_voice_crm"
```

### 3. Run the CRM API

```powershell
python -m uvicorn backend.crm_server:app --host 0.0.0.0 --port 9000
```

### 4. Run the ASR API

```powershell
cd E:\cse499\bangla_voice_crm\backend
python -m uvicorn asr_server:app --host 0.0.0.0 --port 8000
```

## Flutter app setup

In Settings:

- set `Production CRM API` to something like `http://192.168.0.113:9000` for local network testing
- set `BanglaASR Server URL` to `http://192.168.0.113:8000/transcribe`

When the CRM API URL is filled in:

- login uses JWT-backed remote auth
- default admin hint is hidden
- user creation goes through the API

When the CRM API URL is empty:

- the app falls back to local demo mode

## Next production steps still recommended

- move token storage from shared preferences to secure storage
- add refresh tokens
- add email/SMS delivery for password reset
- add file upload storage for proof images and audio to S3/Cloudinary/Azure Blob
- add Alembic migrations
- add background sync queue for leads, tracking, reports
- add crash reporting and analytics
- add HTTPS reverse proxy with Nginx or Caddy
- remove `usesCleartextTraffic` once everything is on HTTPS
- create privacy policy and Play Console data safety entries
