# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bangla Voice CRM** is a full-stack mobile and web application for lead management and field operations. It features Bangla audio transcription via BanglaASR, CRM field auto-extraction, and multi-tenant role-based access.

**Stack:**
- **Frontend:** Flutter (Dart) — Android/iOS mobile app
- **Backend:** Python FastAPI — Dual servers (ASR + CRM)
- **Database:** SQLite (mobile), PostgreSQL (backend production)
- **Key Libraries:** FastAPI, SQLAlchemy, Transformers, Librosa, Provider (Flutter state management)

---

## Architecture & Key Modules

### Frontend (Flutter)

**Three main shells based on user role:**
- `admin_shell_screen.dart` — SuperAdmin/Admin dashboard with company management, user management, live monitoring
- `employee_shell_screen.dart` — Employee field ops: voice leads, text leads, field reports, meetings, alerts
- `login_screen.dart` — Authentication with JWT token exchange

**Core services:**
- **auth_service.dart** — JWT token management, user initialization, role detection
- **asr_service.dart** — Posts audio to backend `/transcribe` endpoint, handles retries
- **crm_api_client.dart** — All REST calls to CRM backend (leads, reports, tracking, users)
- **lead_remote_service.dart** — Lead CRUD, syncing, assignment
- **database_service.dart** — Local SQLite for offline lead data
- **field_tracking_service.dart** — GPS, location, and field visit tracking
- **offline_report_queue_service.dart** — Queues field reports when offline, syncs on reconnect
- **media_upload_service.dart** — Handles image/video uploads with resumable chunks
- **notification_service.dart** — Local and push notifications via Firebase

**Screens follow a pattern:**
- Voice/text input → ASR/extraction → Lead creation
- Dashboard displays all leads, filterable by status/employee
- Lead detail shows full transcript, allows manual override of extracted fields
- Field reports capture location, images, and structured data
- Meetings and alerts for follow-ups

### Backend (Python)

**Two separate FastAPI servers:**

1. **asr_server.py** — Audio transcription
   - Loads BanglaASR model at startup (GPU or CPU)
   - Handles audio preprocessing: resampling, silence trimming, noise reduction
   - Returns JSON with `text`, `debug` (timings/device info), and `error`
   - Supports async job processing for long audio via ThreadPoolExecutor
   - Config via env vars: `BANGLA_ASR_DEVICE` (cuda:0 or cpu), `BANGLA_ASR_MIN_SECONDS`, `BANGLA_ASR_MAX_AUDIO_MB`

2. **crm_server.py** — Core CRM + multi-tenant management
   - **Auth:** JWT-based login, password reset tokens, role-based access (SuperAdmin/Admin/Employee)
   - **Multi-tenant:** All data scoped by `company_id`; SuperAdmin can view all companies
   - **Models:** User, Company, Lead, FieldReport, TrackingEvent, UploadedMedia, AuditLog, Meeting
   - **Lead management:** CRUD, status updates, assignment, AI fields (intent, sentiment, priority, lead_score)
   - **Field reports:** Structured capture with images, GPS coordinates, timestamp
   - **Tracking:** Real-time GPS logs and field visit events
   - **Audit logging:** All user actions logged for compliance

**Database setup:**
- SQLAlchemy ORM with PostgreSQL (production) or SQLite (development)
- Migrations handled by ORM schema creation
- Multi-tenant schema ensures isolation via `company_id` on all tenant tables

**Key endpoints (CRM):**
- `/auth/login` — JWT authentication
- `/leads` — CRUD + list (scoped to user's company)
- `/field-reports` — Submit structured field reports with media
- `/tracking/events` — Log GPS and field visit events
- `/users` — User management (Admin only)
- `/companies` — Company provisioning (SuperAdmin only)
- `/audit-logs` — Audit trail (Admin only)

---

## Common Development Tasks

### Running Flutter

```bash
# Install dependencies
cd bangla_voice_crm
flutter pub get

# Run on connected Android device/emulator
flutter run -d android

# Run on iOS
flutter run -d ios

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Build release bundle (for Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Running Backend

```bash
# Setup Python environment
cd backend
python -m venv .venv
.venv\Scripts\activate  # Windows
source .venv/bin/activate  # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Run CRM server (port 8000)
python -m uvicorn crm_server:app --host 0.0.0.0 --port 8000 --reload

# Run ASR server (port 8001)
python -m uvicorn asr_server:app --host 0.0.0.0 --port 8001 --reload

# For production, set environment variables:
# CRM_DATABASE_URL=postgresql+psycopg://user:pwd@host/dbname
# CRM_JWT_SECRET=your-secret
# BANGLA_ASR_DEVICE=cuda:0  # or 'cpu' if no GPU
```

### Testing

**Flutter:**
```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/services/crm_extractor_test.dart

# Run with coverage
flutter test --coverage
lcov --list coverage/lcov.info
```

**Backend:**
```bash
# Run pytest (if test files exist)
pytest backend/

# Or use Python's built-in unittest
python -m unittest discover backend/
```

---

## Configuration & Environment Variables

### Backend CRM Server (`crm_server.py`)
```
CRM_APP_NAME                        # App name in docs
CRM_ENV                             # 'development' or 'production'
CRM_DATABASE_URL                    # SQLite or PostgreSQL connection string
CRM_JWT_SECRET                      # Secret for JWT signing (change in production)
CRM_JWT_ALGORITHM                   # Default: HS256
CRM_ACCESS_TOKEN_EXPIRE_MINUTES     # Default: 720 (12 hours)
CRM_BOOTSTRAP_COMPANY_NAME          # First company name
CRM_BOOTSTRAP_ADMIN_USERNAME        # Initial admin username
CRM_BOOTSTRAP_ADMIN_PASSWORD        # Initial admin password
CRM_PUBLIC_BASE_URL                 # For password reset links
CRM_CORS_ORIGINS                    # Comma-separated or '*'
```

### Backend ASR Server (`asr_server.py`)
```
BANGLA_ASR_MODEL_ID                 # Default: bangla-speech-processing/BanglaASR
BANGLA_ASR_DEVICE                   # 'cuda:0', 'cpu', etc.
BANGLA_ASR_MIN_SECONDS              # Minimum audio duration (default: 1.8)
BANGLA_ASR_MAX_AUDIO_MB             # File size limit (default: 50 MB)
BANGLA_ASR_MAX_SYNC_SECONDS         # Timeout for sync requests (default: 45)
BANGLA_ASR_JOB_WORKERS              # Async job workers (default: 1)
BANGLA_ASR_NOISE_REDUCTION          # 'auto', 'always', or 'off'
```

### Flutter (Settings Screen)
Users configure:
- **API Base URL** — Points to backend CRM server (e.g., `http://192.168.0.113:8000`)
- **ASR URL** — Points to ASR server (e.g., `http://192.168.0.113:8001/transcribe`)
- API credentials are stored in `FlutterSecureStorage`

---

## Key Design Patterns

### Multi-Tenant Isolation
- Every user belongs to one company (`user.company_id`)
- Queries automatically scope to `current_user.company_id` via `_scope_company()` helper
- SuperAdmin bypasses company scoping via `_is_super_admin()` check
- Company data isolation enforced at the database level (no cross-company leaks)

### Role-Based Access
- **SuperAdmin** — Manage all companies and users, bypass all company scoping
- **Admin** — Manage own company's users, leads, and reports
- **Employee** — Create leads, submit field reports, view own assignments

### State Management (Flutter)
- **Provider** — Used for auth state (`AuthService`) and critical service initialization
- **ChangeNotifier** — Services that notify listeners of state changes
- **Consumer/Watch** — UI rebuilds when dependent services change

### Offline-First for Field Ops
- **offline_report_queue_service.dart** — Stores field reports locally when offline
- Syncs automatically when connectivity restored
- Local SQLite serves as cache; backend PostgreSQL is source of truth

### Audio Preprocessing Pipeline
1. Check file size and duration
2. Resample to 16kHz mono (required for BanglaASR)
3. Trim leading/trailing silence
4. Apply noise reduction if audio quality is poor
5. Normalize audio level
6. Send to ASR model

---

## Important Files & Patterns

### Frontend
- `lib/main.dart` — Entry point, auth gate, role-based shell routing
- `lib/services/auth_service.dart` — JWT token lifecycle and current user state
- `lib/services/crm_api_client.dart` — All backend HTTP calls, error handling
- `lib/screens/voice_input_screen.dart` — Record/upload audio, call ASR, create lead
- `lib/screens/dashboard_screen.dart` — List leads, filter, search
- `pubspec.yaml` — Dependencies; note `provider` for state, `sqflite` for offline storage

### Backend
- `backend/crm_server.py` — Main FastAPI app; auth routes, CRUD endpoints, multi-tenant logic
- `backend/asr_server.py` — Audio transcription; async job processing with ThreadPoolExecutor
- `backend/models.py` — SQLAlchemy ORM: User, Company, Lead, FieldReport, TrackingEvent, AuditLog
- `backend/database.py` — SQLAlchemy session, engine, base class
- `backend/deps.py` — Dependency injection: `get_current_user`, `require_roles`
- `backend/audio_preprocessing.py` — Librosa audio pipeline: resample, trim, denoise, normalize
- `backend/config.py` — Settings class; environment variable parsing and validation

---

## Recent Work & Known Issues

**Recent commits:**
- Fixed login timeout and added Render startup banner
- Prepared backend for production (PostgreSQL, env-based config)
- Employee monitoring and tracking sync improvements
- Voice UI and ASR cleanup, phone number parsing fixes

**Deployment:**
- Backend deployed to Render.com with PostgreSQL
- Mobile app connects to Render backend URL
- Local development uses SQLite; `CRM_DATABASE_URL` env var switches to PostgreSQL

---

## Tips for Development

1. **Local Backend Setup:**
   - Run both `crm_server:app` and `asr_server:app` in separate terminals on ports 8000 and 8001
   - In Flutter Settings, set API URL to your machine's IP (not `localhost`; mobile can't reach it)
   
2. **Audio Testing:**
   - Place `.wav` files in a known directory; use file picker to upload
   - ASR expects 16kHz mono WAV; preprocessing handles conversion
   - If ASR is slow, check GPU availability via `/model-info` endpoint

3. **Database Debugging:**
   - For SQLite: Open `crm_prod.db` with SQLiteBrowser or similar
   - For PostgreSQL: Use `psql` or DataGrip
   - Check `audit_logs` table to trace user actions

4. **Multi-Tenant Testing:**
   - Create multiple companies in Settings > Company Management
   - Create users under different companies
   - Verify that users only see their company's data

5. **Mobile Permissions:**
   - Android: Declared in `android/app/src/main/AndroidManifest.xml` (mic, internet, location, read/write storage)
   - iOS: Declared in `ios/Runner/Info.plist`
   - Request at runtime via `permission_handler` package

6. **API Error Handling:**
   - All CRM endpoints return `{ "detail": "..." }` on error with HTTP status code
   - ASR endpoint returns `{ "error": "..." }` on audio quality issues
   - Flutter `crm_api_client.dart` wraps errors and shows user-facing messages

---

## Rendering / Deployment Notes

- **Render PostgreSQL** requires `CRM_DATABASE_URL` in format: `postgresql+psycopg://user:pwd@host/dbname`
- **ASR Model** (~2GB) is loaded once at startup; first request is slow but subsequent calls are fast
- **Concurrent Requests:** Backend handles multi-threaded load via `ThreadPoolExecutor`; scale workers via `BANGLA_ASR_JOB_WORKERS`
