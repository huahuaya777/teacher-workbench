from io import BytesIO
from pathlib import Path
from zipfile import BadZipFile, ZipFile

from docx import Document
from docx.oxml.ns import qn
from pypdf import PdfReader

MAX_EXTRACTED_CHARS = 15000


class MaterialExtractionError(ValueError):
    pass


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


def extract_text(uploaded_file):
    """Extract a bounded amount of text; never execute uploaded content."""
    name = uploaded_file.name.replace("\\", "/")
    suffix = Path(name).suffix.lower()
    uploaded_file.seek(0)
    raw = uploaded_file.read()
    uploaded_file.seek(0)
    try:
        if suffix == ".docx":
            if not raw.startswith(b"PK"):
                raise MaterialExtractionError("Word 文件格式不正确。")
            try:
                with ZipFile(BytesIO(raw)) as archive:
                    if sum(info.file_size for info in archive.infolist()) > 40 * 1024 * 1024:
                        raise MaterialExtractionError("Word 文件解压后过大。")
            except BadZipFile as exc:
                raise MaterialExtractionError("Word 文件格式不正确。") from exc
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
                raise MaterialExtractionError("PDF 页数超过 100 页限制。")
            text = "\n".join(page.extract_text() or "" for page in reader.pages)
        else:
            raise MaterialExtractionError("当前只支持 Word 和 PDF 文本资料。")
    except MaterialExtractionError:
        raise
    except Exception as exc:
        raise MaterialExtractionError("文件无法读取，请检查文件是否损坏或受密码保护。") from exc
    text = text.strip()
    if not text:
        raise MaterialExtractionError("未提取到文字。扫描版 PDF 和图片尚待支持。")
    if len(text) > MAX_EXTRACTED_CHARS:
        raise MaterialExtractionError("资料文字超过当前 15000 字上限，请拆分后上传；本次未保存。")
    return text
