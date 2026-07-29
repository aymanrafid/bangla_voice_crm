from zipfile import ZipFile, ZIP_DEFLATED
from pathlib import Path
from html import escape
import datetime

OUT = Path(r"E:\cse499\bangla_voice_crm\Bangla Voice CRM Management - Complete Project Report.docx")


def esc(value):
    return escape(str(value), quote=False)


def paragraph(text="", style=None, align=None, bold=False, color=None, size=None, page_break=False):
    props = []
    if style:
        props.append(f'<w:pStyle w:val="{style}"/>')
    if align:
        props.append(f'<w:jc w:val="{align}"/>')
    p_props = f"<w:pPr>{''.join(props)}</w:pPr>" if props else ""

    run_props = []
    if bold:
        run_props.append("<w:b/>")
    if color:
        run_props.append(f'<w:color w:val="{color}"/>')
    if size:
        run_props.append(f'<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>')
    r_props = f"<w:rPr>{''.join(run_props)}</w:rPr>" if run_props else ""
    page = '<w:br w:type="page"/>' if page_break else ""
    return f'<w:p>{p_props}<w:r>{r_props}<w:t xml:space="preserve">{esc(text)}</w:t>{page}</w:r></w:p>'


def bullet(text):
    return (
        '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/>'
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>'
        f'<w:r><w:t xml:space="preserve">{esc(text)}</w:t></w:r></w:p>'
    )


def table(rows, widths=None, header=True, shade_header="1565C0", border="B7C9E2", diagram=False):
    columns = max(len(row) for row in rows)
    fixed_rows = [row + [""] * (columns - len(row)) for row in rows]
    if widths is None or len(widths) != columns:
        widths = [int(9000 / columns)] * columns

    grid = "".join(f'<w:gridCol w:w="{width}"/>' for width in widths)
    xml = [
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/>'
        f'<w:tblBorders><w:top w:val="single" w:sz="6" w:space="0" w:color="{border}"/>'
        f'<w:left w:val="single" w:sz="6" w:space="0" w:color="{border}"/>'
        f'<w:bottom w:val="single" w:sz="6" w:space="0" w:color="{border}"/>'
        f'<w:right w:val="single" w:sz="6" w:space="0" w:color="{border}"/>'
        f'<w:insideH w:val="single" w:sz="6" w:space="0" w:color="{border}"/>'
        f'<w:insideV w:val="single" w:sz="6" w:space="0" w:color="{border}"/></w:tblBorders>'
        '<w:tblCellMar><w:top w:w="90" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
        '<w:bottom w:w="90" w:type="dxa"/><w:right w:w="90" w:type="dxa"/></w:tblCellMar>'
        f"</w:tblPr><w:tblGrid>{grid}</w:tblGrid>"
    ]

    for row_index, row in enumerate(fixed_rows):
        xml.append("<w:tr>")
        for col_index, cell in enumerate(row):
            shade = ""
            color = None
            bold = False
            align = "left"
            if header and row_index == 0:
                shade = f'<w:shd w:fill="{shade_header}"/>'
                color = "FFFFFF"
                bold = True
                align = "center"
            elif diagram:
                align = "center"
                if str(cell).strip() in {"↓", "→", "↔"}:
                    shade = '<w:shd w:fill="EAF2FF"/>'
                    bold = True
                elif cell:
                    shade = '<w:shd w:fill="F7FAFF"/>'

            xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{widths[col_index]}" w:type="dxa"/>{shade}</w:tcPr>')
            for line_index, line in enumerate(str(cell).split("\n")):
                run_props = ""
                if bold or (diagram and row_index > 0 and cell and line_index == 0 and str(cell).strip() not in {"↓", "→", "↔"}):
                    run_props += "<w:b/>"
                if color:
                    run_props += f'<w:color w:val="{color}"/>'
                run_props = f"<w:rPr>{run_props}</w:rPr>" if run_props else ""
                xml.append(
                    f'<w:p><w:pPr><w:jc w:val="{align}"/></w:pPr>'
                    f'<w:r>{run_props}<w:t xml:space="preserve">{esc(line)}</w:t></w:r></w:p>'
                )
            xml.append("</w:tc>")
        xml.append("</w:tr>")
    xml.append("</w:tbl>")
    return "".join(xml)


content = []
content.append(paragraph("Bangla Voice CRM Management", style="Title", align="center", bold=True, color="1565C0", size="40"))
content.append(paragraph("Comprehensive Project Report with System Design", align="center", bold=True, size="28"))
content.append(paragraph("Prepared for: CSE/EEE/ETE 499A Final Report (CO5)", align="center"))
content.append(paragraph("Project Type: Flutter Mobile Application + BanglaASR Backend", align="center"))
content.append(paragraph(f'Date: {datetime.date.today().strftime("%d %B %Y")}', align="center"))
content.append(paragraph("", page_break=True))

content.append(paragraph("Executive Summary", style="Heading1"))
content.append(paragraph("Bangla Voice CRM Management is a Bengali voice-enabled customer relationship management system designed to reduce manual CRM data entry and make lead capture easier for Bengali-speaking users. The system allows a user to record Bangla speech, upload audio, or paste Bangla text. It then transcribes the voice input using BanglaASR, extracts structured CRM fields using Bengali NLP rules, and stores the result as a customer lead in a local SQLite database."))
content.append(paragraph("The project demonstrates a practical client-server design: a Flutter mobile client handles the user interface, CRM workflow, local database, and export features, while a FastAPI backend hosted through Google Colab and Cloudflare Tunnel performs speech-to-text transcription. The result is a localized CRM prototype suitable for sales teams, service agents, small businesses, and academic demonstration."))

content.append(paragraph("Table of Contents", style="Heading1"))
for item in [
    "1. Project Overview",
    "2. System Features and Functionality",
    "3. Technical Architecture",
    "4. System Design with Visuals",
    "5. Development Process",
    "6. User Interface and User Experience",
    "7. Testing and Quality Assurance",
    "8. Deployment and Implementation",
    "9. Benefits and Impact",
    "10. Future Scope and Enhancements",
    "11. Conclusion",
]:
    content.append(paragraph(item))
content.append(paragraph("", page_break=True))

content.append(paragraph("1. Project Overview", style="Heading1"))
content.append(paragraph("1.1 Project Name", style="Heading2"))
content.append(paragraph("Bangla Voice CRM Management"))
content.append(paragraph("1.2 Purpose and Objectives", style="Heading2"))
for item in [
    "Enable Bengali voice-based CRM lead entry.",
    "Reduce manual typing and form-filling effort.",
    "Automatically extract customer name, phone, address, location, lead type, product interest, and support issue from Bangla speech or text.",
    "Store leads locally and allow search, status tracking, detailed review, and CSV export.",
    "Support Bengali-speaking sales and customer service teams with a practical, localized workflow.",
]:
    content.append(bullet(item))
content.append(paragraph("1.3 Problem Addressed", style="Heading2"))
content.append(paragraph("Many CRM systems are optimized for English-language office workflows and require structured manual entry. In Bengali-speaking business environments, especially field sales, small shops, service centers, and informal customer support teams, customer information is often collected through spoken conversations. Manual CRM entry is slow, error-prone, and inconvenient on mobile devices. This project addresses that gap by allowing users to speak naturally in Bangla and receive structured CRM records automatically."))

content.append(paragraph("2. System Features and Functionality", style="Heading1"))
content.append(paragraph("2.1 Major Features", style="Heading2"))
for item in [
    "Bangla voice recording from mobile microphone.",
    "Audio file upload for existing voice recordings.",
    "Manual Bangla text input for testing and non-audio workflows.",
    "BanglaASR-based speech-to-text transcription.",
    "Rule-based Bengali CRM field extraction.",
    "Automatic Sales Lead vs Customer Support classification.",
    "Local SQLite database for lead persistence.",
    "Dashboard with total leads, sales/support count, average confidence, search, refresh, and export.",
    "Lead detail page with full transcript and status update.",
    "CSV export with share support.",
    "Settings screen for configuring the ASR API URL.",
    "Confidence score showing extraction completeness.",
]:
    content.append(bullet(item))
content.append(paragraph("2.2 Bengali Voice Integration", style="Heading2"))
content.append(paragraph("The voice workflow begins in the Flutter app. On Android, native recording is implemented through a Kotlin MethodChannel connected to Android MediaRecorder. The recorded audio path is passed back to Dart and uploaded to the configured FastAPI transcription endpoint. The backend validates the audio, converts it to 16kHz mono WAV, runs BanglaASR, and returns the Bengali transcript as JSON."))
content.append(paragraph("2.3 Core CRM Functions", style="Heading2"))
content.append(table([
    ["Function", "Implementation"],
    ["Contact/Lead Management", "Stores customer records with name, phone, address, location, transcript, status, and confidence."],
    ["Lead Tracking", "Auto-generates lead IDs such as LEAD-0001 and lists saved leads in the dashboard."],
    ["Interaction Logging", "Stores the full Bangla transcript with each lead for later review."],
    ["Task/Status Management", "Supports New, Contacted, Converted, and Closed status states."],
    ["Reporting", "Exports all leads to CSV for spreadsheet analysis or sharing."],
    ["Search", "Searches leads by name, phone, location, product, and lead ID."],
], widths=[2400, 6600]))
content.append(paragraph("2.4 Innovative Aspects", style="Heading2"))
content.append(paragraph("The system is Bengali-first. Its design focuses on natural Bangla speech rather than English forms. It combines ASR, Bangla digit normalization, spoken phone number extraction, local location matching, product/issue keyword maps, and mobile CRM management in one workflow."))

content.append(paragraph("3. Technical Architecture", style="Heading1"))
content.append(paragraph("3.1 Technology Stack", style="Heading2"))
content.append(table([
    ["Layer", "Technology"],
    ["Mobile App", "Flutter, Dart, Material 3"],
    ["Native Android", "Kotlin, MethodChannel, MediaRecorder"],
    ["Database", "SQLite through sqflite"],
    ["Local Storage", "shared_preferences, path_provider"],
    ["Networking", "HTTP multipart request"],
    ["File Handling", "file_picker, csv, share_plus"],
    ["ASR Backend", "Python, FastAPI, Uvicorn"],
    ["ML/NLP", "Transformers, Torch, BanglaASR, Librosa, SoundFile"],
    ["Deployment Tunnel", "Cloudflare Tunnel / Google Colab public URL"],
], widths=[2500, 6500]))
content.append(paragraph("3.2 Architecture Style", style="Heading2"))
content.append(paragraph("The system follows a client-server architecture. The Flutter mobile app acts as the client and handles user interaction, CRM processing, local persistence, and reporting. The FastAPI backend provides speech-to-text as a remote service. This separation allows the mobile app to remain lightweight while computationally heavy ASR processing runs on a GPU-capable backend."))
content.append(paragraph("3.3 Bengali Speech-to-Text and NLP", style="Heading2"))
content.append(paragraph("The backend loads the Hugging Face model bangla-speech-processing/BanglaASR and creates an automatic speech recognition pipeline. Audio validation checks duration and RMS energy to reject very short or silent audio. The NLP extraction layer uses rule-based Bengali patterns to identify names, Bangladeshi phone numbers, locations, products, support issues, and lead type. The notebook implementation includes 25 sales product categories, 16 support issue categories, and 58 Bangladeshi locations."))
content.append(paragraph("3.4 Data Storage and Security", style="Heading2"))
content.append(paragraph("Leads are stored locally in SQLite. The app requests microphone permission before recording and stores the ASR API URL in shared preferences. For production use, the project should add HTTPS-only endpoints, authentication, encrypted local storage, secure cloud backup, user roles, and audit logging."))

content.append(paragraph("4. System Design with Visuals", style="Heading1"))
content.append(paragraph("4.1 High-Level System Architecture", style="Heading2"))
content.append(table([
    ["Flutter Mobile App", "→", "FastAPI ASR Backend", "→", "BanglaASR Model"],
    ["Voice Input\nText Input\nDashboard\nSettings", "HTTP multipart audio upload\nJSON response", "Audio validation\n16kHz conversion\nTranscription API", "Bengali speech-to-text\nGPU acceleration when available"],
], widths=[2300, 1100, 2300, 1100, 2200], header=False, diagram=True))
content.append(paragraph("Figure 1: High-level client-server architecture of Bangla Voice CRM Management."))

content.append(paragraph("4.2 Data Flow Diagram", style="Heading2"))
content.append(table([
    ["Step", "Process", "Output"],
    ["1", "User records Bangla speech, uploads audio, or enters Bangla text.", "Raw audio or transcript"],
    ["2", "Audio is sent to FastAPI /transcribe endpoint.", "Multipart request"],
    ["3", "Backend validates, converts, and transcribes audio.", "Bangla transcript"],
    ["4", "Flutter app extracts CRM fields using Bengali NLP rules.", "Structured CRM fields"],
    ["5", "User reviews or manually overrides extracted fields.", "Verified lead data"],
    ["6", "Lead is saved into SQLite database.", "Persistent CRM record"],
    ["7", "Dashboard displays, searches, updates, and exports leads.", "CRM management and CSV report"],
], widths=[900, 5600, 2500]))

content.append(paragraph("4.3 Module Design", style="Heading2"))
content.append(table([
    ["Module", "Responsibility"],
    ["main.dart / HomeScreen", "App startup, theme, navigation, and bottom tab structure."],
    ["VoiceInputScreen", "Recording/uploading audio, calling ASR service, displaying extracted fields, saving leads."],
    ["TextInputScreen", "Manual transcript entry and CRM extraction without microphone."],
    ["DashboardScreen", "Lead statistics, search, refresh, list display, and CSV export."],
    ["LeadDetailScreen", "Detailed lead view, transcript copy, status update, and delete action."],
    ["SettingsScreen", "Stores configurable ASR API URL."],
    ["AsrService", "Sends audio to backend and parses transcription response."],
    ["CrmExtractor", "Extracts lead type, name, phone, address, location, product/issue, and confidence."],
    ["DatabaseService", "SQLite database creation and CRUD operations."],
    ["ExportService", "CSV file creation and sharing."],
], widths=[2600, 6400]))

content.append(paragraph("4.4 Database Schema", style="Heading2"))
content.append(table([
    ["Field", "Type", "Purpose"],
    ["id", "INTEGER PRIMARY KEY", "Internal database ID"],
    ["leadId", "TEXT", "User-facing lead identifier"],
    ["dateTime", "TEXT", "Lead creation timestamp"],
    ["leadType", "TEXT", "Sales Lead or Customer Support"],
    ["name", "TEXT", "Customer name"],
    ["phone", "TEXT", "Customer phone number"],
    ["address", "TEXT", "Customer address"],
    ["location", "TEXT", "Area, district, or location"],
    ["productInterest", "TEXT", "Product interest or support issue"],
    ["transcript", "TEXT", "Full Bengali transcript"],
    ["status", "TEXT", "New, Contacted, Converted, or Closed"],
    ["confidence", "INTEGER", "Extraction confidence percentage"],
], widths=[2200, 2500, 4300]))

content.append(paragraph("4.5 Deployment Design", style="Heading2"))
content.append(table([
    ["Colab Notebook", "→", "FastAPI Server", "→", "Cloudflare Tunnel", "→", "Flutter App"],
    ["Loads model\nStarts server", "", "Runs on port 8000", "", "Creates public /transcribe URL\nApp sends audio"],
], widths=[1900, 650, 1900, 650, 1900, 650, 2350], header=False, diagram=True))
content.append(paragraph("Figure 2: Prototype deployment flow using Google Colab and Cloudflare Tunnel."))

content.append(paragraph("5. Development Process", style="Heading1"))
content.append(paragraph("The project followed an iterative Agile-like process. The team first validated the BanglaASR model in a notebook, then built the CRM extraction rules, exposed transcription through FastAPI, and finally integrated the backend with the Flutter mobile application."))
for title, text in [
    ("Planning", "Defined the Bengali voice CRM problem, target users, CRM fields, and expected workflow."),
    ("Design", "Designed mobile screens, database schema, API contract, NLP field extraction rules, and deployment strategy."),
    ("Implementation", "Built the notebook prototype, FastAPI endpoint, Flutter screens, SQLite service, and export flow."),
    ("Testing", "Tested extraction logic, API responses, audio validation, and core mobile workflows."),
    ("Deployment", "Hosted the backend through Colab and exposed it through Cloudflare Tunnel for mobile app access."),
]:
    content.append(paragraph(title, style="Heading2"))
    content.append(paragraph(text))
content.append(paragraph("Development challenges included Bengali ASR accuracy, spoken phone number handling, silent audio detection, temporary backend URLs, and converting natural speech into structured CRM fields. These were handled with audio validation, conversion to 16kHz mono WAV, Bengali keyword dictionaries, regex-based extraction, and manual override fields."))

content.append(paragraph("6. User Interface and User Experience", style="Heading1"))
content.append(paragraph("The UI is mobile-first and built with Flutter Material 3. The experience is organized around three main tabs: Voice Input, Text Input, and Dashboard. A Settings screen allows API configuration. The interface uses cards, badges, confidence bars, clear buttons, and compact CRM field summaries."))
content.append(table([
    ["Screen", "UX Purpose"],
    ["Voice Input", "Primary workflow for recording or uploading audio and reviewing extracted lead fields."],
    ["Text Input", "Testing and fallback workflow where users paste Bangla transcripts manually."],
    ["Dashboard", "CRM overview with statistics, search, refresh, and export actions."],
    ["Lead Detail", "Detailed review of one lead, status update, transcript copy, and deletion."],
    ["Settings", "Simple configuration of the remote ASR API URL."],
], widths=[2200, 6800]))
content.append(paragraph("The UX is optimized by reducing typing effort, allowing direct speech, providing sample Bengali prompts, showing confidence percentages, and supporting manual correction before saving leads."))

content.append(paragraph("7. Testing and Quality Assurance", style="Heading1"))
content.append(paragraph("Testing focused on the ASR pipeline, field extraction rules, database operations, and user workflow. The notebook includes a self-test where the extractor successfully identified lead type, name, phone number, address, location, product interest, and 100% confidence from a sample Bengali transcript."))
content.append(table([
    ["Testing Type", "Description"],
    ["Unit Testing", "CRM extraction functions were tested with Bengali sample transcripts."],
    ["Integration Testing", "Flutter app, ASR API, extraction service, and SQLite storage were tested together."],
    ["API Testing", "FastAPI /transcribe endpoint was tested using audio upload requests."],
    ["Validation Testing", "Silent and very short audio detection was verified."],
    ["User Acceptance Testing", "Manual workflows were checked through voice input, text input, dashboard, and lead detail screens."],
], widths=[2500, 6500]))
content.append(paragraph("Known improvement areas include replacing the default Flutter counter widget test, aligning Android audio extension with the actual recording format, strengthening lead ID generation, and adding automated tests for database and UI workflows."))

content.append(paragraph("8. Deployment and Implementation", style="Heading1"))
content.append(paragraph("The prototype backend is deployed by running the notebook in Google Colab, loading the BanglaASR model, starting the FastAPI server, and exposing it through Cloudflare Tunnel. The generated /transcribe URL is copied into the Flutter app Settings screen."))
content.append(paragraph("The mobile app is implemented as a Flutter project and can be run on an Android device or emulator using Flutter tooling. The current project status is a working academic prototype with implemented voice input, text input, transcription integration, CRM extraction, local database, dashboard, and CSV export."))

content.append(paragraph("9. Benefits and Impact", style="Heading1"))
for item in [
    "Faster lead entry because users can speak instead of filling multiple fields manually.",
    "Better accessibility for Bengali-speaking users and field agents.",
    "Reduced friction for small businesses that do not use complex CRM systems.",
    "Improved follow-up through lead status tracking.",
    "Preserved interaction context through stored transcripts.",
    "Exportable data for reporting, spreadsheet analysis, and business review.",
]:
    content.append(bullet(item))
content.append(paragraph("The system is especially relevant for real estate, retail, education, healthcare, service centers, small businesses, and call-center-style customer support teams in Bengali-speaking regions."))

content.append(paragraph("10. Future Scope and Enhancements", style="Heading1"))
content.append(paragraph("Future development can transform the prototype into a production-grade CRM platform. Recommended improvements include:"))
for item in [
    "Stable cloud backend deployment instead of temporary Colab sessions.",
    "User login, authentication, and role-based access control.",
    "Cloud database synchronization and backup.",
    "Encrypted local storage for sensitive customer information.",
    "Advanced AI-based named entity recognition for Bengali.",
    "Lead assignment, follow-up reminders, and task management.",
    "WhatsApp, SMS, email, and phone-call integration.",
    "Analytics dashboard with conversion rate, agent performance, and campaign reporting.",
    "Improved speech pipeline with noise handling and offline/edge ASR options.",
    "Integration with existing CRM, ERP, Google Sheets, and support ticketing platforms.",
]:
    content.append(bullet(item))
content.append(paragraph("Long-term scalability should use a production backend with PostgreSQL/Firebase, secure object storage for audio, HTTPS APIs, monitoring, centralized logging, and load-balanced ASR inference."))

content.append(paragraph("11. Conclusion", style="Heading1"))
content.append(paragraph("Bangla Voice CRM Management successfully demonstrates how Bengali voice technology can improve CRM workflows. The project combines Flutter mobile development, native audio capture, BanglaASR transcription, Bengali NLP field extraction, SQLite data storage, and CRM dashboard features into a usable prototype."))
content.append(paragraph("Its value proposition is clear: it helps Bengali-speaking users capture leads faster, reduce manual typing, preserve customer conversations, and manage sales or support records from a mobile device. With production deployment, stronger security, and richer CRM integrations, the system can become a practical business solution for Bengali-speaking markets."))

styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Nirmala UI"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr><w:pPr><w:spacing w:after="140" w:line="276" w:lineRule="auto"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Nirmala UI"/><w:b/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr><w:pPr><w:spacing w:after="240"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Nirmala UI"/><w:b/><w:color w:val="1565C0"/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr><w:pPr><w:spacing w:before="300" w:after="160"/><w:outlineLvl w:val="0"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Nirmala UI"/><w:b/><w:color w:val="00897B"/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr><w:pPr><w:spacing w:before="200" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:style>
<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr></w:style>
</w:styles>'''

numbering = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>'''

document = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>{''.join(content)}<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>'''

content_types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>'''

rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'''
doc_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>'''
now = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
core = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>Bangla Voice CRM Management Complete Project Report</dc:title><dc:creator>Codex</dc:creator><cp:lastModifiedBy>Codex</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified></cp:coreProperties>'''
app = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Word</Application></Properties>'''

with ZipFile(OUT, "w", ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("_rels/.rels", rels)
    z.writestr("word/document.xml", document)
    z.writestr("word/_rels/document.xml.rels", doc_rels)
    z.writestr("word/styles.xml", styles)
    z.writestr("word/numbering.xml", numbering)
    z.writestr("docProps/core.xml", core)
    z.writestr("docProps/app.xml", app)

print(OUT)
print(OUT.stat().st_size)
