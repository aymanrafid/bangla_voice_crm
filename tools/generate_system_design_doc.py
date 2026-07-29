from __future__ import annotations

from html import escape
from pathlib import Path
from struct import unpack
from zipfile import ZIP_DEFLATED, ZipFile
import datetime


OUT = Path(r"E:\cse499\bangla_voice_crm\Bangla Voice CRM Management - System Design Diagrams.docx")
ARCH_IMAGE = Path(
    r"C:\Users\LENOVO\.codex\generated_images\019dc54b-2a0c-7e60-9431-25a1c9fde9dc\ig_0c36f0a31a5a16f70169f637ec5db08191bceb660f1050b3d8.png"
)


def esc(value: object) -> str:
    return escape(str(value), quote=False)


def paragraph(text: str = "", style: str | None = None, align: str | None = None,
              bold: bool = False, color: str | None = None, size: str | None = None,
              page_break: bool = False) -> str:
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


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        header = f.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Only PNG images are supported")
    width, height = unpack(">II", header[16:24])
    return width, height


def image_paragraph(rel_id: str, image_name: str, width_px: int, height_px: int, max_width_px: int = 900) -> str:
    scale = min(1.0, max_width_px / width_px)
    cx = int(width_px * scale * 9525)
    cy = int(height_px * scale * 9525)
    return f'''
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="{cx}" cy="{cy}"/>
        <wp:docPr id="1" name="{esc(image_name)}"/>
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1"/>
        </wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="{esc(image_name)}"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="{rel_id}"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>'''


content = []
content.append(paragraph("Bangla Voice CRM Management", style="Title", align="center", bold=True, color="1565C0", size="40"))
content.append(paragraph("System Design Diagrams", align="center", bold=True, size="28"))
content.append(paragraph("Architecture, data flow, module, ER, deployment, and pipeline visuals", align="center"))
content.append(paragraph(f'Date: {datetime.date.today().strftime("%d %B %Y")}', align="center"))
content.append(paragraph("", page_break=True))

content.append(paragraph("1. High-Level Architecture Diagram", style="Heading1"))
content.append(paragraph("This figure shows the full client-server architecture of the Bangla Voice CRM Management system, including mobile app modules, backend ASR pipeline, CRM extraction, intelligence, and local storage."))

width_px, height_px = png_size(ARCH_IMAGE)
content.append(image_paragraph("rId3", "System Architecture", width_px, height_px))
content.append(paragraph("Figure 1: High-level system architecture for Bangla Voice CRM Management.", align="center"))

content.append(paragraph("2. Data Flow Diagram (Level 1)", style="Heading1"))
content.append(paragraph("This diagram shows how user input flows through the system and becomes a structured CRM lead."))
content.append(table([
    ["User", "→", "Voice / Text Input"],
    ["Voice / Text Input", "→", "Speech-to-Text Processing"],
    ["Speech-to-Text Processing", "→", "CRM Field Extraction"],
    ["CRM Field Extraction", "→", "Lead Intelligence"],
    ["Lead Intelligence", "→", "SQLite Lead Database"],
    ["SQLite Lead Database", "→", "Dashboard / Lead Management"],
], widths=[3500, 900, 4600], header=False, diagram=True))
content.append(paragraph("Figure 2: Data flow diagram showing the main processing stages.", align="center"))

content.append(paragraph("3. Detailed Processing Pipeline", style="Heading1"))
content.append(paragraph("This pipeline focuses on the voice-input path from recorded audio to saved lead."))
content.append(table([
    ["Bangla Voice Input", "→", "Audio Recording"],
    ["Audio Recording", "→", "Audio Preprocessing"],
    ["Audio Preprocessing", "→", "Bangla ASR"],
    ["Bangla ASR", "→", "Bangla Transcript"],
    ["Bangla Transcript", "→", "CRM Extraction"],
    ["CRM Extraction", "→", "Validation + Confidence"],
    ["Validation + Confidence", "→", "Lead Intelligence"],
    ["Lead Intelligence", "→", "SQLite Storage"],
    ["SQLite Storage", "→", "Dashboard / Command Center"],
], widths=[3200, 900, 4900], header=False, diagram=True))
content.append(paragraph("Figure 3: End-to-end processing pipeline.", align="center"))

content.append(paragraph("4. Module Diagram", style="Heading1"))
content.append(paragraph("This diagram groups the system into functional modules for implementation and maintenance."))
content.append(table([
    ["Flutter App", "Input Module", "CRM Processing Module", "Lead Intelligence Module", "Database Module", "Presentation Module"],
    ["", "Voice Input\nText Input\nSettings", "Normalization\nField Extraction\nValidation\nLead Type Detection", "Intent\nSentiment\nPriority\nLead Score\nSummary", "Insert\nSearch\nUpdate\nExport", "Dashboard\nLead Detail\nCommand Center"],
], widths=[1300, 1700, 2200, 1800, 1400, 1600], header=False, diagram=True))
content.append(paragraph("Figure 4: Functional module design of the system.", align="center"))

content.append(paragraph("5. Entity Relationship (ER) Diagram", style="Heading1"))
content.append(paragraph("The current prototype stores one main business entity: the CRM lead."))
content.append(table([
    ["LEAD"],
    ["id (PK)\nleadId\ndateTime\nleadType\nname\nphone\naddress\nlocation\nproductInterest\ntranscript\nstatus\nconfidence\nintent\nsentiment\npriority\nleadScore\naiSummary\nnextAction"],
], widths=[9000], header=False, diagram=True))
content.append(paragraph("Figure 5: ER diagram for the lead entity.", align="center"))

content.append(paragraph("6. Deployment Diagram", style="Heading1"))
content.append(paragraph("This view shows where the system components run in the prototype deployment setup."))
content.append(table([
    ["Mobile User", "→", "Flutter Mobile App", "→", "ASR Backend Server"],
    ["ASR Backend Server", "→", "Audio Preprocessing", "→", "BanglaASR Model"],
    ["Flutter Mobile App", "→", "Local SQLite Database", "→", "Dashboard / Lead Detail / Command Center"],
], widths=[1800, 700, 2000, 700, 2000], header=False, diagram=True))
content.append(paragraph("Figure 6: Deployment layout for client, backend, and storage.", align="center"))

content.append(paragraph("7. Input Path Comparison", style="Heading1"))
content.append(paragraph("The system supports both voice-based and direct text-based workflows."))
content.append(table([
    ["Voice Path", "Text Path"],
    ["User speaks in Bangla\n→ Audio upload\n→ Preprocessing\n→ Bangla ASR\n→ Transcript\n→ CRM Extraction\n→ Intelligence\n→ Save Lead",
     "User pastes Bangla text\n→ CRM Extraction\n→ Intelligence\n→ Save Lead"],
], widths=[4600, 4400], header=True, diagram=True))
content.append(paragraph("Figure 7: Comparison between voice and manual text workflows.", align="center"))

content.append(paragraph("8. Design Summary", style="Heading1"))
content.append(paragraph("The system design follows a layered client-server architecture. The Flutter mobile app manages user interaction and CRM presentation, the backend handles audio preprocessing and speech recognition, the extraction engine converts transcripts into structured lead data, the intelligence layer enriches each lead, and SQLite stores the final result for dashboard and management views."))

styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Nirmala UI"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr><w:pPr><w:spacing w:after="140" w:line="276" w:lineRule="auto"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Nirmala UI"/><w:b/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr><w:pPr><w:spacing w:after="240"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light" w:cs="Nirmala UI"/><w:b/><w:color w:val="1565C0"/><w:sz w:val="32"/><w:szCs w:val="32"/></w:rPr><w:pPr><w:spacing w:before="300" w:after="160"/><w:outlineLvl w:val="0"/></w:pPr></w:style>
<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr></w:style>
</w:styles>'''

document = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
<w:body>{''.join(content)}<w:sectPr><w:pgSz w:w="15840" w:h="12240" w:orient="landscape"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>'''

content_types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>'''

rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>'''

doc_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/system_architecture.png"/>
</Relationships>'''

now = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
core = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:title>Bangla Voice CRM Management - System Design Diagrams</dc:title>
<dc:creator>Codex</dc:creator>
<cp:lastModifiedBy>Codex</cp:lastModifiedBy>
<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>'''

app = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
 xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Microsoft Word</Application>
</Properties>'''

with ZipFile(OUT, "w", ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("_rels/.rels", rels)
    z.writestr("word/document.xml", document)
    z.writestr("word/_rels/document.xml.rels", doc_rels)
    z.writestr("word/styles.xml", styles)
    z.writestr("docProps/core.xml", core)
    z.writestr("docProps/app.xml", app)
    z.write(ARCH_IMAGE, "word/media/system_architecture.png")

print(OUT)
print(OUT.stat().st_size)
