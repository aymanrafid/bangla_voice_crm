# CRM Backend Deployment Guide

This guide prepares the FastAPI CRM backend for a public HTTPS URL using Render.

## 1. Push the repository

From the project root:

```powershell
git status
git add .
git commit -m "Prepare CRM backend for production deployment"
git push origin main
```

## 2. Create the Render Blueprint

In Render:
1. Click `New` -> `Blueprint`
2. Select this GitHub repository
3. Keep branch `main`
4. Render will read `render.yaml`

The blueprint creates:
- PostgreSQL database: `bangla-voice-crm-db`
- Web service: `bangla-voice-crm-api`

## 3. Fill required environment variables

In the Blueprint or service settings, set these values:

- `CRM_BOOTSTRAP_ADMIN_PASSWORD`: choose a strong admin password
- `CRM_PUBLIC_BASE_URL`: your public service URL, for example `https://bangla-voice-crm-api.onrender.com`
- `CRM_CORS_ORIGINS`: comma-separated allowed frontend origins

Examples:

```text
CRM_BOOTSTRAP_ADMIN_PASSWORD=UseAVeryStrongPassword123!
CRM_PUBLIC_BASE_URL=https://bangla-voice-crm-api.onrender.com
CRM_CORS_ORIGINS=https://your-admin-web.example.com,https://your-company-app.example.com
```

If the Flutter mobile app is the only client right now, you can temporarily use:

```text
CRM_CORS_ORIGINS=*
```

## 4. Wait for deployment

When deployment succeeds, test:

- `/health`
- `/docs`
- `/`

Examples:

```text
https://your-service-name.onrender.com/health
https://your-service-name.onrender.com/docs
```

## 5. First login

The backend bootstraps a super admin account on startup using:

- username: `admin`
- password: value from `CRM_BOOTSTRAP_ADMIN_PASSWORD`

Login from the app with that account, then create companies and company users.

## 6. Update the app

In the Flutter app settings, set CRM base URL to:

```text
https://your-service-name.onrender.com
```

Do not add `/health` or `/docs`.

## 7. Production notes

- `CRM_EXPOSE_RESET_TOKENS=false` is recommended in production
- `CRM_CORS_ALLOW_CREDENTIALS=false` is fine for token-based mobile API usage
- Keep the ASR backend separate from the CRM backend
- For Play Store release, switch the app from local URLs to this HTTPS CRM URL

## 8. Remaining work after CRM deployment

After CRM is online, the next steps are:
1. host ASR online or use a temporary tunnel for testing
2. replace Android debug signing with release signing
3. change package name from `com.example.bangla_voice_crm`
4. decide whether to remove `ACCESS_BACKGROUND_LOCATION` before Play submission
