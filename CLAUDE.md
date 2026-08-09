# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Bangla Voice CRM is a Flutter mobile app backed by two independent FastAPI services. Field staff capture leads by speaking Bangla; audio is transcribed by a self-hosted BanglaASR model, CRM fields are extracted from the transcript, and leads sync to a multi-tenant server.

The two backends are deployed separately and share no process:

- `backend/crm_server.py` — auth, leads, reports, tracking, media. Postgres.
- `backend/asr_server.py` — audio transcription only. No database.

## Commands

```bash
# Flutter
flutter pub get
flutter run -d android
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
flutter analyze lib/services/foo.dart   # accepts specific paths; fast
flutter test
flutter test test/lead_voice_update_service_test.dart   # single file
```

Only two test files exist: `test/widget_test.dart` and `test/lead_voice_update_service_test.dart`. There is no backend test suite and no pytest dependency.

```bash
# Backend — note the three separate requirements files
cd backend
python -m venv .venv && .venv/Scripts/activate
pip install -r requirements-crm.txt     # lean: fastapi, sqlalchemy, psycopg, jose, passlib
pip install -r requirements-asr.txt     # heavy: torch, transformers, librosa
# requirements.txt is the union of both; installing it pulls torch into a CRM-only env

python -m uvicorn backend.crm_server:app --reload --port 8000   # run from repo root
python -m uvicorn asr_server:app --reload --port 8001           # run from backend/
```

`asr_server.py` has a try/except around its own imports so it works either as `backend.asr_server` or as `asr_server` from inside `backend/`. `crm_server.py` uses relative imports and must be run as `backend.crm_server` from the repo root.

Backend defaults to SQLite (`crm_prod.db`); set `CRM_DATABASE_URL` for Postgres. `config.py` normalizes `postgres://` and `postgresql://` to `postgresql+psycopg://`.

## Deployment

**Only the CRM server is deployed to Render**, via `render.yaml` — as `bangla-voice-crm-api-jdk8` with the `bangla-voice-crm-db-jdk8` Postgres instance.

**ASR is not run on Render.** It is served from a local machine and exposed through an ngrok tunnel, with that tunnel URL entered as the ASR URL in the app's Settings screen. `render.asr.yaml` and the `bangla-voice-asr-api` service are leftovers and are not in use — the deployed instance does not respond, and that is expected. Do not spend time diagnosing it.

**The live CRM host is `bangla-voice-crm-api-jdk8.onrender.com`.** An older service holds the plain `bangla-voice-crm-api` name and is suspended — it returns a 503 HTML page, not JSON. If login or sync fails, verify the URL in the app's Settings screen before touching code. A quick `curl https://<host>/health` distinguishes a real bug from a misrouted client in seconds; do this first.

Free-plan constraints that shape the code:

- Services sleep after inactivity; a cold start takes 30–60s. Every client call needs an explicit timeout or it hangs until the OS TCP timeout, showing a spinner that never resolves.
- Render returns HTML (not JSON) for 502/503, so any `jsonDecode` on an error body must be guarded.
- The filesystem is ephemeral. `crm_server.py` writes uploads to `backend/uploads` and serves them at `/media-files`, so **every deploy permanently 404s previously uploaded report images**. Unresolved; needs a Render disk or object storage.
- `public_url` on `UploadedMedia` is built from `request.base_url` at upload time, baking the hostname into stored rows. Rows written under an old hostname stay broken after a rename.

## Backend architecture

**Multi-tenancy.** Every tenant table carries `company_id`. Queries pass through `_scope_company()`, which filters by `current_user.company_id` unless `_is_super_admin()`. Roles: `SuperAdmin` (crosses companies), `Admin`, `Manager`, `Employee`. Enforced by `require_roles(...)` from `deps.py`.

**Schema management.** No Alembic. `_startup()` calls `Base.metadata.create_all`, then `_ensure_multi_tenant_schema()`, which adds any missing `company_id` columns via raw `ALTER TABLE` and backfills only the tables that actually have unassigned rows. That guard matters: the backfill originally ran six unconditional `UPDATE`s on every boot, and cold starts are frequent here.

**Models** (`models.py`): `Company`, `User`, `Lead`, `TrackingEvent`, `FieldReport`, `UploadedMedia`, `AuditLog`, `PasswordResetToken`. Note that meetings exist only in the Flutter app's local SQLite (`lib/models/meeting.dart`) — there is no server-side meetings table or endpoint.

**Endpoint paths do not match their concepts** — check `crm_server.py` before assuming:

| Concept | Actual path |
|---|---|
| Create user | `POST /auth/users` |
| List users | `GET /users` |
| Field reports | `/reports`, `PUT /reports/{id}/review` |
| GPS / visit tracking | `/field-tracking` |
| Delta sync | `GET /sync/changes` |
| Health | `GET /health` (hits DB), `GET /` (does not) |

`healthCheckPath` in `render.yaml` points at `/` deliberately, so a slow database cannot fail an otherwise-good deploy.

**Passwords** use `pbkdf2_sha256` via passlib (`security.py`) — not bcrypt, despite `passlib[bcrypt]` in requirements. The usual passlib/bcrypt version breakage does not apply here.

**Engine** (`database.py`) sets `pool_pre_ping=True` always and `pool_recycle=280` for Postgres, because managed Postgres drops idle connections and a stale pooled socket stalls rather than failing fast.

## Flutter architecture

`main.dart` gates the entire UI behind `AuthService.initialize()`, routing to `AdminShellScreen` or `EmployeeShellScreen` by role. Any unbounded network call on that path freezes the app at a bare spinner.

**Three HTTP layers, and they are not interchangeable:**

- `remote_auth_service.dart` — auth only (`/auth/*`, `/users`, `/companies`). 60s login timeout, 20s otherwise.
- `crm_api_client.dart` — everything else, used by `lead_remote_service`, `tracking_remote_service`, `report_remote_service`. Reads retry once (20s then 60s); writes get a single 60s attempt and are deliberately **not** retried, since a timed-out POST may already have been applied.
- `media_upload_service.dart` — multipart uploads, 90s.

All three decode error bodies defensively and map 502/503 to distinct "suspended" vs "waking up" messages. When adding a call, route it through one of these rather than calling `http` directly.

**Offline behavior.** `offline_report_queue_service.dart` queues field reports locally and retries on login and reconnect. Local SQLite (`database_service.dart`) is a cache; the server is authoritative for anything with an `external_id`.

**Identity.** Naming differs across the boundary and is easy to get wrong. `Lead` has no `externalId` field — its `leadId` (the `LEAD-0001` string) is what serializes to and from the server's `external_id`, in `lead_remote_service.dart`. `AppUser` does have a real `externalId` UUID. Local integer `id` values are SQLite-only and must never be sent to the server.

## Configuration

App-side settings live in the Settings screen, not in code: CRM API base URL and ASR URL go to `SharedPreferences`; tokens and cached session go to `FlutterSecureStorage` (`api_config_service.dart`). An empty CRM base URL puts the app in local-only mode with a seeded `admin`/`admin123` account — remote mode is inferred purely from that URL being non-empty.

Backend env vars are read in `config.py` (`CRM_*`) and at the top of `asr_server.py` (`BANGLA_ASR_*`); both files list every variable with its default.
