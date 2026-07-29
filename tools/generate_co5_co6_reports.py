from __future__ import annotations

from datetime import date, datetime, timezone
from html import escape
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(r"E:\cse499\bangla_voice_crm")
CO5_OUT = ROOT / "CO5 - Project Management and Financial Viability Report - Completed.docx"
CO6_OUT = ROOT / "CO6 - Ethical and Professional Responsibility Report - Completed.docx"


def esc(value: object) -> str:
    return escape(str(value), quote=False)


def paragraph(
    text: str = "",
    *,
    style: str | None = None,
    align: str | None = None,
    bold: bool = False,
    color: str | None = None,
    size: str | None = None,
    page_break: bool = False,
) -> str:
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
    return (
        f'<w:p>{p_props}<w:r>{r_props}'
        f'<w:t xml:space="preserve">{esc(text)}</w:t>{page}</w:r></w:p>'
    )


def bullet(text: str) -> str:
    return (
        '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/>'
        '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/>'
        "</w:numPr></w:pPr>"
        f'<w:r><w:t xml:space="preserve">{esc(text)}</w:t></w:r></w:p>'
    )


def table(rows: list[list[str]], widths: list[int] | None = None, header: bool = True) -> str:
    columns = max(len(row) for row in rows)
    fixed_rows = [row + [""] * (columns - len(row)) for row in rows]
    if widths is None or len(widths) != columns:
        widths = [int(9000 / columns)] * columns

    grid = "".join(f'<w:gridCol w:w="{width}"/>' for width in widths)
    xml = [
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="6" w:color="B7C9E2"/>'
        '<w:left w:val="single" w:sz="6" w:color="B7C9E2"/>'
        '<w:bottom w:val="single" w:sz="6" w:color="B7C9E2"/>'
        '<w:right w:val="single" w:sz="6" w:color="B7C9E2"/>'
        '<w:insideH w:val="single" w:sz="6" w:color="B7C9E2"/>'
        '<w:insideV w:val="single" w:sz="6" w:color="B7C9E2"/>'
        "</w:tblBorders></w:tblPr>"
        f"<w:tblGrid>{grid}</w:tblGrid>"
    ]

    for row_index, row in enumerate(fixed_rows):
        xml.append("<w:tr>")
        for col_index, cell in enumerate(row):
            cell_fill = ""
            cell_bold = False
            cell_color = None
            align = "left"
            if header and row_index == 0:
                cell_fill = '<w:shd w:fill="1565C0"/>'
                cell_bold = True
                cell_color = "FFFFFF"
                align = "center"

            xml.append(
                f'<w:tc><w:tcPr><w:tcW w:w="{widths[col_index]}" '
                f'w:type="dxa"/>{cell_fill}</w:tcPr>'
            )
            for line in str(cell).split("\n"):
                run_props = []
                if cell_bold:
                    run_props.append("<w:b/>")
                if cell_color:
                    run_props.append(f'<w:color w:val="{cell_color}"/>')
                r_props = f"<w:rPr>{''.join(run_props)}</w:rPr>" if run_props else ""
                xml.append(
                    f'<w:p><w:pPr><w:jc w:val="{align}"/></w:pPr>'
                    f'<w:r>{r_props}<w:t xml:space="preserve">{esc(line)}</w:t></w:r></w:p>'
                )
            xml.append("</w:tc>")
        xml.append("</w:tr>")
    xml.append("</w:tbl>")
    return "".join(xml)


def docx_package(body_parts: list[str], title: str) -> dict[str, str]:
    styles = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Calibri"/><w:b/><w:sz w:val="38"/><w:szCs w:val="38"/></w:rPr><w:pPr><w:spacing w:after="220"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Calibri"/><w:b/><w:color w:val="1565C0"/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr><w:pPr><w:spacing w:before="260" w:after="140"/><w:outlineLvl w:val="0"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:b/><w:color w:val="00897B"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr><w:pPr><w:spacing w:before="180" w:after="80"/><w:outlineLvl w:val="1"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:style>
<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/></w:style>
</w:styles>"""

    numbering = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>"""

    document = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        f"<w:body>{''.join(body_parts)}"
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'
        "</w:sectPr></w:body></w:document>"
    )

    content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>"""
    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>"""
    doc_rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>"""
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    core = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        f"<dc:title>{esc(title)}</dc:title><dc:creator>Codex</dc:creator>"
        "<cp:lastModifiedBy>Codex</cp:lastModifiedBy>"
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>'
        "</cp:coreProperties>"
    )
    app = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>Microsoft Word</Application></Properties>"""

    return {
        "[Content_Types].xml": content_types,
        "_rels/.rels": rels,
        "word/document.xml": document,
        "word/_rels/document.xml.rels": doc_rels,
        "word/styles.xml": styles,
        "word/numbering.xml": numbering,
        "docProps/core.xml": core,
        "docProps/app.xml": app,
    }


def save_docx(path: Path, body_parts: list[str], title: str) -> None:
    package = docx_package(body_parts, title)
    with ZipFile(path, "w", ZIP_DEFLATED) as zf:
        for name, content in package.items():
            zf.writestr(name, content)


def cover_page(report_label: str) -> list[str]:
    today = date.today().strftime("%d %B %Y")
    return [
        paragraph("CSE / EEE / ETE 499A", align="center", bold=True, size="30"),
        paragraph(report_label, align="center", bold=True, color="1565C0", size="34"),
        paragraph("Project Title: Bangla Voice CRM Management", align="center", bold=True, size="28"),
        paragraph("Submitted To: Dr. Shazzad Hosain (SZZ)", align="center"),
        paragraph(f"Date: {today}", align="center"),
        paragraph("Section: ____________________", align="center"),
        paragraph("Group No: ____________________", align="center"),
        paragraph("Group Members: ____________________", align="center"),
        paragraph(
            "Note: Fill section, group number, and member details exactly as required by your department before final submission.",
            align="center",
        ),
        paragraph("", page_break=True),
    ]


def build_co5() -> list[str]:
    parts = cover_page("CO5 - Project Management and Financial Viability Report")
    parts += [
        paragraph("Chapter 1 - Introduction", style="Heading1"),
        paragraph(
            "Bangla Voice CRM Management is a Bengali voice-enabled customer relationship management system built to reduce manual lead entry. A user speaks or uploads customer information in Bangla, the system converts it into Bangla text using an ASR backend, extracts CRM fields such as name, phone number, address, location, and product interest, and stores the result as a structured lead."
        ),
        paragraph("Project Objectives", style="Heading2"),
        bullet("Enable Bangla voice-to-CRM lead capture from a mobile device."),
        bullet("Reduce the typing burden for Bengali-speaking sales and support teams."),
        bullet("Automatically classify leads, compute confidence, and preserve the transcript."),
        bullet("Support dashboard review, CSV export, survey tracking, and location-aware follow-up."),
        paragraph("Problem Statement", style="Heading2"),
        paragraph(
            "Traditional CRM tools are form-heavy and mostly optimized for English typing workflows. In many Bangladeshi field or small-business contexts, customer information is gathered verbally. Manual re-entry is slow and error-prone. This project addresses that problem through localized speech input, automatic extraction, and lightweight mobile CRM management."
        ),
        paragraph("Project Scope", style="Heading2"),
        bullet("Flutter mobile application with voice input, text input, dashboard, lead detail, survey tab, and settings."),
        bullet("FastAPI transcription backend using BanglaASR with audio preprocessing."),
        bullet("Rule-based Bangla NLP extraction for CRM fields."),
        bullet("SQLite-based local lead database, CSV export, survey visit tracking, notifications, and Barikoi-assisted map flow."),
        paragraph("Chapter 2 - System Design", style="Heading1"),
        paragraph("High-Level Architecture", style="Heading2"),
        table(
            [
                ["Layer", "Implementation"],
                ["Mobile client", "Flutter app with voice input, text input, dashboard, lead details, command center, survey reports, and settings."],
                ["ASR backend", "FastAPI server receiving audio on /transcribe and returning Bangla transcript JSON."],
                ["Audio preprocessing", "Silence trimming, denoising, normalization, and 16kHz mono conversion before ASR."],
                ["Extraction layer", "Rule-based Bangla entity extraction for name, phone, address, location, product, lead type, and confidence."],
                ["Data layer", "SQLite storage for leads and survey status, plus shared preferences for settings."],
                ["Location layer", "Geolocator GPS tracking, local arrival detection, Barikoi geocoding/reverse-geocoding, and live map visualization through flutter_map."],
            ],
            widths=[2200, 6800],
        ),
        paragraph("Implemented Modules", style="Heading2"),
        table(
            [
                ["Module", "Role in the Project"],
                ["Voice Input", "Record audio, upload files, show transcript, and save extracted leads."],
                ["Text Input", "Allow manual Bangla text for testing and fallback workflows."],
                ["Dashboard", "Show lead statistics, filters, search, refresh, and export."],
                ["Lead Detail", "Display extracted CRM fields, transcript, AI insight, and survey state."],
                ["Survey Tracking", "Start visit tracking, show map, detect arrival, notify user, and mark survey completion."],
                ["Survey Report", "List pending and completed visits with export support."],
                ["Backend", "Receive audio, preprocess it, run BanglaASR, and return text."],
            ],
            widths=[2400, 6600],
        ),
        paragraph("Data Flow", style="Heading2"),
        bullet("User speaks in Bangla or enters Bangla text in the mobile app."),
        bullet("Audio is uploaded to the ASR backend and cleaned before transcription."),
        bullet("BanglaASR returns the transcript to the app."),
        bullet("The CRM extractor turns the transcript into structured fields."),
        bullet("Lead intelligence adds intent, sentiment, priority, lead score, and next action."),
        bullet("The lead is saved to SQLite and appears in dashboard and survey workflows."),
        paragraph("Survey and Barikoi Extension", style="Heading2"),
        paragraph(
            "The advanced implementation adds survey visit tracking. Each lead can store latitude, longitude, survey status, started time, arrived time, arrival distance, and survey notes. When a survey starts, the app resolves the destination address with Barikoi where possible, shows the destination and current position on a live map, tracks the field officer via GPS, and auto-completes the survey visit when the user reaches the destination radius."
        ),
        paragraph("Chapter 3 - Impacts and Constraints", style="Heading1"),
        paragraph("Project Impact", style="Heading2"),
        bullet("Improves accessibility for Bengali-speaking users by allowing speech-based CRM entry."),
        bullet("Preserves customer interaction context by storing transcripts with structured leads."),
        bullet("Supports faster field follow-up with survey tracking and arrival verification."),
        bullet("Creates a practical academic prototype that combines ASR, NLP, mobile CRM, and map-based workflow."),
        paragraph("Constraints", style="Heading2"),
        bullet("Transcription accuracy still depends on audio quality and Bangla ASR behavior."),
        bullet("Rule-based extraction is easier to debug but less flexible than a fully trained Bangla NER pipeline."),
        bullet("The prototype currently uses local SQLite instead of a centralized multi-user backend."),
        bullet("API keys embedded in mobile code are acceptable for prototype work but not ideal for production."),
        bullet("Location tracking depends on user permission, GPS availability, and map/geocoding response quality."),
        paragraph("Financial Viability", style="Heading2"),
        paragraph(
            "The project is financially viable as a prototype because most of the stack is open source and free to start with. Flutter, Dart, Python, FastAPI, SQLite, and much of the supporting tooling do not require license fees. The main future operating costs come from transcription hosting, API traffic, and cloud infrastructure if the project is scaled beyond an academic demo."
        ),
        table(
            [
                ["Cost Item", "Prototype Cost", "Production Direction"],
                ["Flutter / Dart / Android Studio / VS Code", "No license cost", "Remain free"],
                ["SQLite local storage", "No direct cost", "Can scale to PostgreSQL/Firebase later"],
                ["FastAPI + Python backend", "No license cost", "Needs paid hosting"],
                ["BanglaASR inference", "Academic/demo GPU use", "Managed GPU or inference service cost"],
                ["Barikoi and map-assisted workflow", "Low prototype cost", "Usage-based API planning required"],
                ["Testing devices and internet", "Existing team resources", "Operational device fleet in deployment"],
            ],
            widths=[3200, 2600, 3200],
        ),
        paragraph("Expected Economic Value", style="Heading2"),
        bullet("Reduces manual data-entry time for each lead."),
        bullet("Improves lead capture consistency and follow-up readiness."),
        bullet("Can be adapted for real estate, retail, service, microbusiness, and support teams."),
        bullet("Provides a path to ROI through labor savings and improved conversion tracking if deployed at scale."),
        paragraph("Chapter 4 - Methodologies", style="Heading1"),
        paragraph("Development Methodology", style="Heading2"),
        paragraph(
            "The project followed an iterative, milestone-based workflow similar to Agile. The team first validated the BanglaASR model in a notebook, then exposed the backend through FastAPI, built the Flutter app screens and database, refined extraction logic through repeated tests, added survey tracking, and finally extended the location layer with Barikoi integration and map visualization."
        ),
        table(
            [
                ["Phase", "Key Deliverables"],
                ["Planning", "Problem framing, user flow definition, CRM field list, and architecture outline."],
                ["Prototype", "Notebook-based BanglaASR validation and extraction logic experiments."],
                ["Core app", "Voice input, text input, dashboard, lead detail, SQLite storage, and CSV export."],
                ["Backend hardening", "FastAPI server, denoising pipeline, and audio validation."],
                ["Advanced features", "Survey tracking, notifications, survey report, Barikoi geocoding/reverse geocoding, and map UI."],
                ["Verification", "Build, test, and workflow validation across app and backend."],
            ],
            widths=[2200, 6800],
        ),
        paragraph("Extraction Methodology", style="Heading2"),
        bullet("Transcript normalization for Bangla phrases and spoken digits."),
        bullet("Rule-based name, phone, address, location, and product extraction."),
        bullet("Keyword-based lead-type classification and confidence scoring."),
        bullet("AI-style lead enrichment with intent, sentiment, priority, lead score, and next action."),
        paragraph("Project Management Approach", style="Heading2"),
        bullet("Scope was controlled by delivering a working prototype first, then adding advanced modules incrementally."),
        bullet("High-risk features such as ASR, location, and survey completion were validated in isolation before integration."),
        bullet("The system remained modular so backend, mobile UI, and survey flow could evolve independently."),
        paragraph("Risk Management", style="Heading2"),
        table(
            [
                ["Risk", "Impact", "Mitigation"],
                ["Poor ASR transcript quality", "Wrong extraction and low trust", "Audio preprocessing, validation, and manual correction path."],
                ["Phone number extraction failure", "Lead unusable for follow-up", "Spoken-digit parsing and stricter validation logic."],
                ["Location mismatch", "Wrong survey arrival detection", "Stored coordinates, Barikoi-assisted resolution, and user-visible map."],
                ["Backend outage", "Voice flow unavailable", "Text input fallback and configurable API URL."],
                ["Privacy exposure", "Sensitive customer data leakage", "Recommend consent, minimization, secure storage, and HTTPS for production."],
            ],
            widths=[2200, 2200, 5600],
        ),
        paragraph("Chapter 5 - Result", style="Heading1"),
        paragraph(
            "The final prototype successfully demonstrates the intended end-to-end pipeline. A user can speak in Bangla, receive a transcript from the backend, review extracted CRM fields, save the lead, manage lead status, export data, start a survey visit, and see a live map experience that supports destination resolution and arrival verification."
        ),
        bullet("Bangla voice input, audio upload, and manual Bangla text input are implemented."),
        bullet("Noise-reduction preprocessing is implemented before ASR."),
        bullet("CRM extraction works for name, phone, address, location, and product intent."),
        bullet("SQLite storage, dashboard search, lead detail, and CSV export are implemented."),
        bullet("Survey visit tracking, local notifications, and survey report export are implemented."),
        bullet("Barikoi geocoding and reverse-geocoding support the survey navigation flow."),
        paragraph("Verification Snapshot", style="Heading2"),
        table(
            [
                ["Verification Item", "Observed Status"],
                ["Flutter tests", "Passing"],
                ["Debug APK build", "Successful"],
                ["Survey workflow", "Lead coordinates, tracking, completion, and reporting implemented"],
                ["Backend pipeline", "FastAPI + audio preprocessing + BanglaASR implemented"],
            ],
            widths=[3500, 5500],
        ),
        paragraph("Chapter 6 - Conclusion", style="Heading1"),
        paragraph(
            "Bangla Voice CRM Management is a viable and technically meaningful final-year project. It addresses a real local-language usability problem through a layered solution that combines mobile development, speech recognition, Bangla extraction logic, CRM workflow, and advanced field-survey support."
        ),
        paragraph(
            "From a project management perspective, the work was completed incrementally, with high-risk components validated first and advanced modules layered on after the core workflow stabilized. From a financial perspective, the use of open-source tools keeps the entry cost low, while the architecture leaves a clear path for future commercialization or institutional deployment."
        ),
    ]
    return parts


def build_co6() -> list[str]:
    parts = cover_page("CO6 - Ethical and Professional Responsibility Report")
    parts += [
        paragraph("Ethical and Professional Responsibility in Project Development", style="Heading1"),
        paragraph("1. Introduction", style="Heading1"),
        paragraph(
            "Bangla Voice CRM Management is a Bengali voice-enabled CRM system that records or uploads Bangla audio, transcribes it through a backend ASR service, extracts structured customer fields, stores leads locally, and now supports survey visit tracking with location-aware verification. Ethics and professionalism matter in this project because the system handles personal information, voice data, address data, and location-sensitive follow-up workflows."
        ),
        paragraph(
            "This report covers ethical and professional responsibility across problem definition, system design, implementation, testing, deployment, maintenance, and advanced field-survey features such as notifications, GPS arrival detection, and Barikoi-assisted location intelligence."
        ),
        paragraph("2. Relevant Ethical Principles", style="Heading1"),
        bullet("Privacy: the system handles names, phone numbers, addresses, transcripts, coordinates, and survey timing data."),
        bullet("Safety: incorrect location handling or false survey completion could affect real-world visits."),
        bullet("Fairness and inclusivity: Bangla speech and extraction should not disadvantage users due to dialect, pronunciation, or device quality."),
        bullet("Transparency: users should know when they are being recorded, tracked, or auto-classified."),
        bullet("Accountability: the team must report limitations honestly and provide a correction path."),
        bullet("Sustainability and responsible resource use: backend computation and map/API use should be proportionate to project needs."),
        paragraph("Professional Standards", style="Heading2"),
        paragraph(
            "The report is aligned with the spirit of the IEEE Code of Ethics and the ACM Code of Ethics and Professional Conduct. Those frameworks emphasize public welfare, honesty, fairness, privacy, competence, accountability, and avoiding harm, all of which are directly relevant to a voice-based CRM and survey-tracking system."
        ),
        paragraph("3. Stakeholder Analysis", style="Heading1"),
        table(
            [
                ["Stakeholder", "Expectations and Ethical Concerns"],
                ["End users / agents", "Need a reliable app, clear permissions, and accurate lead extraction without hidden behavior."],
                ["Customers / data subjects", "Expect privacy, consent for recording, safe handling of phone/address data, and fair treatment."],
                ["Project team", "Must build responsibly, test honestly, avoid plagiarism, and report limits clearly."],
                ["Supervisor / institution", "Expect academically honest work, proper documentation, and professional conduct."],
                ["Future deployers / businesses", "Need operational viability, compliance awareness, and manageable risk."],
                ["Society and regulators", "Need technology that respects rights, avoids misuse, and does not normalize uncontrolled surveillance."],
            ],
            widths=[2400, 6600],
        ),
        paragraph("Potential Ethical Conflicts", style="Heading2"),
        bullet("A business may want maximum data collection, while customers need data minimization."),
        bullet("Agents may want automatic survey completion, while supervisors need reliable proof of actual arrival."),
        bullet("Project demonstration goals may encourage optimistic claims, while professional honesty requires candid disclosure of limitations."),
        paragraph("4. Ethical Considerations Across Development Phases", style="Heading1"),
        paragraph("4.1 Problem Definition and Requirement Analysis", style="Heading2"),
        paragraph(
            "The project solves a genuine usability problem for Bengali-speaking CRM users, but the team must avoid defining requirements in a way that excludes certain groups. For example, assumptions about accent, urban-only addresses, or smartphone quality can introduce unfairness. Requirements therefore need to account for manual correction, fallback text input, and explainable extraction behavior."
        ),
        paragraph("4.2 Design Phase", style="Heading2"),
        paragraph(
            "The design phase required privacy-by-design and secure-by-design thinking. Sensitive fields should be collected only when necessary, the app should clearly separate recording, transcription, and storage, and survey tracking should be tied to explicit user action rather than invisible background monitoring. The new survey feature raises additional ethical responsibility because coordinates and arrival times can become surveillance-like if not constrained."
        ),
        bullet("Safety consideration: wrong navigation or wrong geocoding should not be treated as unquestionable truth."),
        bullet("Privacy-by-design: support manual override and visible status instead of silent automation."),
        bullet("Societal impact: a local-language CRM can improve accessibility, but over-collection could undermine trust."),
        paragraph("4.3 Implementation Phase", style="Heading2"),
        paragraph(
            "During implementation, responsible use of libraries, APIs, and code reuse is essential. The project uses open-source tools such as Flutter, FastAPI, SQLite, and supporting packages. Professional responsibility requires respecting their licenses, avoiding copy-paste plagiarism, documenting external dependencies, and protecting secrets such as map/API keys."
        ),
        bullet("The Barikoi API key was wired for prototype integration, but production practice should move secrets out of client code."),
        bullet("Speech and location features should request permissions explicitly and only when needed."),
        bullet("Code changes should remain traceable and honest about what is implemented versus what is planned."),
        paragraph("4.4 Testing and Validation", style="Heading2"),
        paragraph(
            "Testing must avoid harm and misleading claims. A passing build does not justify claiming perfect transcription or perfect extraction. The team has a duty to test with realistic Bangla input, noisy conditions, location edge cases, and false-arrival scenarios, then communicate those results accurately."
        ),
        bullet("Data integrity matters when reporting extraction accuracy and survey completion behavior."),
        bullet("Users should be able to correct extracted data instead of being locked into the automated output."),
        bullet("Location testing should avoid unsafe driving or distracting mobile use during actual travel."),
        paragraph("4.5 Deployment and Maintenance", style="Heading2"),
        paragraph(
            "Once deployed, the system would need stronger accountability. That includes HTTPS-only APIs, access control, backup strategy, incident handling, log review, retention policy, and a clear process for responding to transcription mistakes, privacy complaints, or inaccurate location outcomes. Maintenance should also monitor whether changes in APIs, laws, or user behavior create new harms."
        ),
        paragraph("5. Legal and Regulatory Compliance", style="Heading1"),
        paragraph(
            "For Bangladesh, the project is most directly related to privacy, cyber-security, communications, and location-sensitive data handling. Article 43 of the Constitution of Bangladesh recognizes privacy of home and correspondence/communication. Bangladesh's digital-law landscape has been changing recently; the Cyber Security Act, 2023 was repealed and replaced by the Cyber Security Ordinance, 2025. A dedicated personal data protection regime is still evolving, with draft personal data protection measures discussed publicly during 2025. Because of this shifting legal environment, the safest professional approach is to design for consent, minimization, and secure handling even before a complete statutory framework is finalized."
        ),
        bullet("Record and store customer data only for a legitimate CRM purpose."),
        bullet("Obtain clear consent for voice recording and location-aware survey tracking."),
        bullet("Limit retention of audio, transcripts, addresses, and coordinates."),
        bullet("Use secure transmission and storage controls for production deployment."),
        paragraph("6. Risk Assessment and Mitigation", style="Heading1"),
        table(
            [
                ["Risk", "Severity / Likelihood", "Mitigation"],
                ["Unauthorized exposure of customer phone/address/location", "High / Medium", "Minimize stored data, add authentication, encrypt sensitive data, and avoid hardcoded production secrets."],
                ["False survey completion due to map/GPS mismatch", "Medium / Medium", "Use visible map confirmation, stored coordinates, arrival threshold tuning, and audit trail fields."],
                ["ASR or extraction bias against certain speech styles", "Medium / Medium", "Support manual correction, test with varied speakers, and avoid overclaiming automation accuracy."],
                ["Silent or unclear recording causing wrong lead data", "Medium / High", "Audio validation, denoising, confidence scoring, and user review before saving."],
                ["Misuse of survey tracking as covert monitoring", "High / Low to Medium", "Start tracking only from explicit user action, show visible survey status, and define access policy."],
            ],
            widths=[2500, 2200, 5300],
        ),
        paragraph("Contingency Planning", style="Heading2"),
        bullet("Allow fallback text input when voice flow fails."),
        bullet("Allow manual correction before saving or exporting leads."),
        bullet("Suspend survey auto-completion if GPS confidence or location quality is poor."),
        bullet("Rotate API keys and move them to a backend or secure config for production."),
        paragraph("7. Professional Responsibility", style="Heading1"),
        paragraph(
            "Professional responsibility in this project means more than writing working code. It includes honest reporting, respecting the supervisor's expectations, meeting deadlines, documenting architecture and risk clearly, and taking responsibility for whether the system can be safely used."
        ),
        bullet("Team accountability: define ownership for frontend, backend, extraction, testing, and documentation."),
        bullet("Communication: explain risks and limitations to stakeholders instead of presenting the system as infallible."),
        bullet("Integrity: do not fabricate results or hide failures in ASR, extraction, or location handling."),
        bullet("Quality commitment: verify builds, test workflows, and keep corrections scoped and traceable."),
        paragraph("8. Reflection and Lessons Learned", style="Heading1"),
        paragraph(
            "The project revealed that a useful local-language system can still create new ethical pressure points. Voice input improves accessibility, but it also amplifies privacy concerns because speech may contain more information than a typed form. Survey tracking improves field productivity, but it also increases responsibility around location consent, surveillance boundaries, and map accuracy."
        ),
        paragraph(
            "A major lesson is that technically successful automation should still remain reviewable by the user. Manual correction, visible status, explicit permissions, and candid documentation are not optional extras; they are part of ethical engineering. Another lesson is that prototype convenience, such as placing API keys directly in client code, should always be marked as temporary rather than normalized."
        ),
        paragraph("9. Conclusion", style="Heading1"),
        paragraph(
            "Bangla Voice CRM Management demonstrates meaningful ethical and professional responsibility when it is framed as a user-assistive system rather than an unquestioned decision-maker. The project can create positive impact by supporting Bengali-speaking users, reducing manual effort, and improving field follow-up, but only if privacy, transparency, consent, fairness, and accountability remain central to future development."
        ),
        paragraph(
            "The team has the responsibility to continue improving security, documentation, testing, and compliance as the legal and operational context matures. With that discipline, the project can evolve from a strong academic prototype into a socially responsible applied system."
        ),
        paragraph("10. References", style="Heading1"),
        bullet("IEEE, IEEE Code of Ethics."),
        bullet("ACM, ACM Code of Ethics and Professional Conduct (2018)."),
        bullet("Constitution of the People's Republic of Bangladesh, Article 43."),
        bullet("Cyber Security Ordinance, 2025 (Bangladesh), noting the repeal of the Cyber Security Act, 2023."),
        bullet("Publicly discussed draft personal data protection framework in Bangladesh during 2025."),
        bullet("Project implementation artifacts from Bangla Voice CRM Management: Flutter client, FastAPI ASR backend, survey tracking, and Barikoi-assisted map integration."),
    ]
    return parts


def main() -> None:
    save_docx(
        CO5_OUT,
        build_co5(),
        "CO5 - Project Management and Financial Viability Report",
    )
    save_docx(
        CO6_OUT,
        build_co6(),
        "CO6 - Ethical and Professional Responsibility Report",
    )
    print(CO5_OUT)
    print(CO6_OUT)


if __name__ == "__main__":
    main()
