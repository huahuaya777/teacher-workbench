from io import BytesIO
from pathlib import Path
import re
from zipfile import BadZipFile, ZipFile

from docx import Document
from docx.oxml.ns import qn
from lxml import etree
from pypdf import PdfReader

MAX_EXTRACTED_CHARS = 15000
AI_TEXT_EXTENSIONS = {".docx", ".pdf", ".pptx"}


class MaterialExtractionError(ValueError):
    pass


class MaterialTextUnavailable(MaterialExtractionError):
    """The original may be stored, but its text is unsuitable for AI."""


TEXT_TAGS = {qn("w:t"), qn("m:t")}
MATH_SUPERSCRIPT_TAG = qn("m:sSup")
MATH_BASE_TAG = qn("m:e")
MATH_EXPONENT_TAG = qn("m:sup")


def _node_text(node):
    if node.tag in TEXT_TAGS:
        return node.text or ""
    if node.tag == MATH_SUPERSCRIPT_TAG:
        base = node.find(MATH_BASE_TAG)
        exponent = node.find(MATH_EXPONENT_TAG)
        if base is not None and exponent is not None:
            return _node_text(base) + "^" + _node_text(exponent)
    return "".join(_node_text(child) for child in node)


def _paragraph_text(paragraph):
    # python-docx Paragraph.text omits Word equation (OMML) text.
    return _node_text(paragraph._p)


def _presentation_text(archive):
    if "ppt/presentation.xml" not in archive.namelist():
        raise MaterialExtractionError("PPTX 文件格式不正确。")
    slides = []
    for name in archive.namelist():
        match = re.fullmatch(r"ppt/slides/slide([0-9]+)\.xml", name)
        if match:
            slides.append((int(match[1]), name))
    parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
    paragraphs = []
    total_chars = 0
    for _, name in sorted(slides):
        root = etree.fromstring(archive.read(name), parser=parser)
        for paragraph in root.iter(qn("a:p")):
            text = "".join(node.text or "" for node in paragraph.iter(qn("a:t"))).strip()
            if text:
                total_chars += len(text) + bool(paragraphs)
                if total_chars > MAX_EXTRACTED_CHARS:
                    raise MaterialTextUnavailable("资料文字超过 15000 字上限。")
                paragraphs.append(text)
    return "\n".join(paragraphs)


def extract_text(uploaded_file):
    """Extract a bounded amount of text; never execute uploaded content."""
    name = uploaded_file.name.replace("\\", "/")
    suffix = Path(name).suffix.lower()
    uploaded_file.seek(0)
    raw = uploaded_file.read()
    uploaded_file.seek(0)
    try:
        if suffix in {".docx", ".pptx"}:
            try:
                with ZipFile(BytesIO(raw)) as archive:
                    if sum(info.file_size for info in archive.infolist()) > 40 * 1024 * 1024:
                        raise MaterialTextUnavailable("文件解压后过大。")
                    if suffix == ".pptx":
                        text = _presentation_text(archive)
            except BadZipFile as exc:
                raise MaterialExtractionError("Office 文件格式不正确。") from exc
            if suffix == ".docx":
                doc = Document(BytesIO(raw))
                parts = [text for p in doc.paragraphs if (text := _paragraph_text(p)).strip()]
                for table in doc.tables:
                    for row in table.rows:
                        parts.append(" | ".join("\n".join(_paragraph_text(p) for p in cell.paragraphs) for cell in row.cells))
                text = "\n".join(parts)
        elif suffix == ".pdf":
            if not raw.startswith(b"%PDF"):
                raise MaterialExtractionError("PDF 文件格式不正确。")
            reader = PdfReader(BytesIO(raw))
            if len(reader.pages) > 100:
                raise MaterialTextUnavailable("PDF 页数超过 100 页限制。")
            text = "\n".join(page.extract_text() or "" for page in reader.pages)
        else:
            raise MaterialTextUnavailable("此文件格式仅支持保存原件。")
    except MaterialExtractionError:
        raise
    except Exception as exc:
        raise MaterialExtractionError("文件无法读取，请检查文件是否损坏或受密码保护。") from exc
    text = text.strip()
    if not text:
        raise MaterialTextUnavailable("未提取到可用文字。")
    if len(text) > MAX_EXTRACTED_CHARS:
        raise MaterialTextUnavailable("资料文字超过 15000 字上限。")
    return text
