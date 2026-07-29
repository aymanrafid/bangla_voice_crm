# 🎙️ বাংলা Voice CRM — Flutter Mobile App

A Flutter mobile app that records Bangla speech, transcribes it via BanglaASR, auto-extracts CRM fields (Name, Phone, Address, Location, Product Interest), and manages leads in a local database.

---

## 📱 Features

| Feature | Description |
|---|---|
| 🎤 Voice Recording | Record Bangla speech directly on the phone |
| 📁 Audio Upload | Upload existing `.wav/.mp3` files |
| ⌨️ Text Input | Paste Bangla text manually (no mic needed) |
| 🧠 Auto-Extraction | Extracts name, phone, address, location, product from transcript |
| 📊 CRM Dashboard | List, search, and manage all leads |
| 📋 Lead Detail | View/edit lead status, copy fields |
| 📥 CSV Export | Export all leads to CSV and share |
| ✏️ Manual Override | Fix any incorrectly extracted field |

---

## 🗂️ Project Structure

```
bangla_voice_crm/
├── lib/
│   ├── main.dart                    # App entry + bottom nav
│   ├── theme.dart                   # Colors, typography
│   ├── models/
│   │   └── lead.dart                # Lead data model
│   ├── services/
│   │   ├── asr_service.dart         # BanglaASR API client
│   │   ├── crm_extractor.dart       # Dart port of Python extraction logic
│   │   ├── database_service.dart    # SQLite CRUD
│   │   └── export_service.dart      # CSV export + share
│   ├── screens/
│   │   ├── voice_input_screen.dart  # Tab 1: Record/upload audio
│   │   ├── text_input_screen.dart   # Tab 2: Type/paste transcript
│   │   ├── dashboard_screen.dart    # Tab 3: All leads
│   │   ├── lead_detail_screen.dart  # Lead detail + status update
│   │   └── settings_screen.dart    # API URL + config
│   └── widgets/
│       └── field_card.dart          # Reusable CRM field UI + badges
├── android/
│   └── app/src/main/AndroidManifest.xml  # Mic + internet permissions
├── ios/
│   └── Runner/Info.plist            # iOS mic permission strings
└── pubspec.yaml                     # Dependencies
```

---

## 🚀 Setup & Run

### Prerequisites
- Flutter SDK ≥ 3.10 → [Install Flutter](https://flutter.dev/docs/get-started/install)
- Android Studio / Xcode for device/emulator
- A deployed BanglaASR API server (see below)

### 1. Install dependencies
```bash
cd bangla_voice_crm
flutter pub get
```

### 2. Run on Android
```bash
flutter run -d android
```

### 3. Run on iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

### 4. Build release APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧠 Deploying the BanglaASR API

The app sends recorded audio to a REST API that runs the Python BanglaASR model. Here's how to deploy it:

### Option A — FastAPI (recommended)

```python
# api_server.py
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import tempfile, os

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"])

# Load model once at startup (from your notebook)
from your_notebook_code import transcribe_bangla

@app.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    # Save uploaded audio to temp file
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        content = await audio.read()
        f.write(content)
        tmp_path = f.name
    
    try:
        result = transcribe_bangla(tmp_path)
        return result  # {"text": "...", "debug": "..."}
    finally:
        os.unlink(tmp_path)
```

```bash
pip install fastapi uvicorn python-multipart
uvicorn api_server:app --host 0.0.0.0 --port 8000
```

### Option B — Google Colab + ngrok

Run your existing Colab notebook + expose it with ngrok:

```python
# Add to your Colab notebook
!pip install pyngrok
from pyngrok import ngrok

# After FastAPI app is defined
public_url = ngrok.connect(8000)
print(f"API URL: {public_url}/transcribe")
```

Then paste the ngrok URL in the app's **Settings** screen.

### Option C — Demo Mode (no server needed)

In **Settings**, enable **"Use Mock ASR"** to test field extraction logic with pre-typed text using the Text Input tab — no API required.

---

## 📡 API Contract

**POST** `/transcribe`

| | |
|---|---|
| Content-Type | `multipart/form-data` |
| Field | `audio` (WAV file, 16kHz mono) |

**Response (success):**
```json
{
  "text": "আমার নাম করিম। ফোন ০১৭১২৩৪৫৬৭৮। মিরপুরে থাকি।",
  "debug": "Model: BanglaASR\nDevice: CUDA\nDuration: 4.2s\nStatus: OK ✅"
}
```

**Response (error):**
```json
{
  "error": "⚠️ Audio too short. Please speak for at least 2 seconds."
}
```

---

## 🔧 Key Dependencies

| Package | Purpose |
|---|---|
| `record` | Audio recording (WAV, 16kHz) |
| `file_picker` | Upload audio files |
| `sqflite` | Local SQLite CRM database |
| `http` | API calls to BanglaASR server |
| `csv` + `share_plus` | CSV export and sharing |
| `permission_handler` | Microphone permission |
| `path_provider` | Temp file storage |

---

## 🇧🇩 CRM Field Extraction Logic

The Dart `CrmExtractor` class is a port of the Python logic from the notebook:

- **Lead Type**: Auto-detected by counting Sales vs Support keywords
- **Phone**: Regex patterns for BD numbers (`01XXXXXXXXX`, `+880...`)
- **Name**: Keyword phrases (`আমার নাম ...`) → token fallback
- **Location**: Matched against 50+ BD districts/thanas/areas
- **Product**: Keyword dictionary (25 sales categories, 15 support issues)
- **Confidence**: 0–100% based on how many fields were found

---

## 📊 Database Schema

```sql
CREATE TABLE leads (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  leadId            TEXT,      -- LEAD-0001, LEAD-0002, ...
  dateTime          TEXT,      -- 2025-01-15 14:30:00
  leadType          TEXT,      -- Sales Lead / Customer Support
  name              TEXT,      -- নাম
  phone             TEXT,      -- 01XXXXXXXXX
  address           TEXT,      -- ঠিকানা
  location          TEXT,      -- এলাকা
  productInterest   TEXT,      -- Real Estate — Flat
  transcript        TEXT,      -- Full Bangla transcript
  status            TEXT,      -- New / Contacted / Converted / Closed
  confidence        INTEGER    -- 0–100
);
```
"# bangla_voice_crm" 
