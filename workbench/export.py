"""Build student and teacher DOCX from one saved worksheet version.

The OMML element check is automated. WPS editability must be checked by a user.
"""

import re
from io import BytesIO

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt

MATH_PATTERN = re.compile(r"\[\[math(?::|\])(.*?)\]\]|(?<!\\)\$([^$\n]+)\$", re.DOTALL)
SCRIPT_BASE_PATTERN = re.compile(r"(?:[A-Za-z][A-Za-z0-9]*|\([^()\n]+\))(?=[_^])")
LATEX_COMMAND_PATTERN = re.compile(r"\\([A-Za-z]+)")
MATH_SYMBOLS = {
    "times": "×", "cdot": "·", "div": "÷", "pm": "±", "leq": "≤", "geq": "≥",
    "neq": "≠", "in": "∈", "approx": "≈", "pi": "π", "infty": "∞",
}
AUTO_COMMANDS = set(MATH_SYMBOLS) | {"frac", "sqrt", "text", "left", "right"}
ESCAPED_LINE_BREAK = re.compile(r"(?<!\\)\\n(?![A-Za-z])")


def _prose_line_breaks(value):
    r"""Display model-written literal \n as a break without changing LaTeX commands."""
    return ESCAPED_LINE_BREAK.sub("\n", value.replace("\r\n", "\n").replace("\r", "\n"))


def _group(value, start):
    """Read one balanced TeX group, including groups nested inside fractions."""
    if start >= len(value) or value[start] != "{":
        return None
    depth = 0
    for index in range(start, len(value)):
        if value[index] == "{":
            depth += 1
        elif value[index] == "}":
            depth -= 1
            if depth == 0:
                return value[start + 1:index], index + 1
    return None


def _script(value, start):
    base = SCRIPT_BASE_PATTERN.match(value, start)
    if not base:
        return None
    index = base.end()
    scripts = {}
    while index < len(value) and value[index] in "_^" and value[index] not in scripts:
        kind = value[index]
        index += 1
        if index < len(value) and value[index] == "{":
            parsed = _group(value, index)
            if parsed is None:
                return None
            scripts[kind], index = parsed
        else:
            atom = re.match(r"[A-Za-z0-9]+", value[index:])
            if atom is None:
                return None
            scripts[kind] = atom.group()
            index += len(atom.group())
    return base.group(), scripts, index


def _command(value, start):
    match = LATEX_COMMAND_PATTERN.match(value, start)
    if match is None or match.group(1) not in AUTO_COMMANDS:
        return None
    name, index = match.group(1), match.end()
    groups = []
    for _ in range(2 if name == "frac" else 1 if name in {"sqrt", "text"} else 0):
        parsed = _group(value, index)
        if parsed is None:
            return None
        group, index = parsed
        groups.append(group)
    return name, groups, index


def _implicit_segments(value):
    """Recognize math syntax left unmarked by a provider in saved prose."""
    result = []
    cursor = index = 0
    while index < len(value):
        parsed = _command(value, index) if value[index] == "\\" else _script(value, index)
        if parsed is None:
            index += 1
            continue
        end = parsed[2]
        if index > cursor:
            result.append(("text", _prose_line_breaks(value[cursor:index])))
        result.append(("math", value[index:end]))
        index = cursor = end
    if cursor < len(value):
        result.append(("text", _prose_line_breaks(value[cursor:])))
    return result


def segments(value):
    result = []
    cursor = 0
    for match in MATH_PATTERN.finditer(value):
        if match.start() > cursor:
            result.extend(_implicit_segments(value[cursor:match.start()]))
        result.append(("math", (match.group(1) if match.group(1) is not None else match.group(2)).strip()))
        cursor = match.end()
    if cursor < len(value):
        result.extend(_implicit_segments(value[cursor:]))
    return result


def math_tokens(value):
    """Parse the supported TeX subset shared by preview and editable Word math."""
    index = 0
    plain = []
    while index < len(value):
        command = _command(value, index) if value[index] == "\\" else None
        script = _script(value, index) if command is None else None
        if command is None and script is None:
            plain.append(value[index])
            index += 1
            continue
        if plain:
            yield "text", "".join(plain)
            plain.clear()
        if command is not None:
            name, groups, index = command
            if name == "frac":
                yield "frac", groups[0], groups[1]
            elif name == "sqrt":
                yield "sqrt", groups[0]
            elif name == "text":
                yield "text", groups[0]
            elif name in MATH_SYMBOLS:
                yield "text", MATH_SYMBOLS[name]
            # \left and \right are TeX sizing hints, not visible characters.
        else:
            base, scripts, index = script
            if "_" in scripts and "^" in scripts:
                yield "subsup", base, scripts["_"], scripts["^"]
            elif "_" in scripts:
                yield "sub", base, scripts["_"]
            else:
                yield "sup", base, scripts["^"]
    if plain:
        yield "text", "".join(plain)


def _math_run(value):
    run = OxmlElement("m:r")
    text = OxmlElement("m:t")
    text.set(qn("xml:space"), "preserve")
    text.text = value
    run.append(text)
    return run


def _append_math_tokens(parent, value):
    for token in math_tokens(value):
        if token[0] == "text":
            parent.append(_math_run(token[1]))
        elif token[0] == "sqrt":
            radical = OxmlElement("m:rad")
            properties = OxmlElement("m:radPr")
            degree_hidden = OxmlElement("m:degHide")
            degree_hidden.set(qn("m:val"), "1")
            properties.append(degree_hidden)
            radical.append(properties)
            radical.append(OxmlElement("m:deg"))
            radicand = OxmlElement("m:e")
            _append_math_tokens(radicand, token[1])
            radical.append(radicand)
            parent.append(radical)
        elif token[0] == "frac":
            fraction = OxmlElement("m:f")
            numerator = OxmlElement("m:num")
            denominator = OxmlElement("m:den")
            _append_math_tokens(numerator, token[1])
            _append_math_tokens(denominator, token[2])
            fraction.extend((numerator, denominator))
            parent.append(fraction)
        else:
            base = token[1]
            power = OxmlElement({"sup": "m:sSup", "sub": "m:sSub", "subsup": "m:sSubSup"}[token[0]])
            base_element = OxmlElement("m:e")
            _append_math_tokens(base_element, base)
            power.append(base_element)
            for kind, script_value in (("sub", token[2]), ("sup", token[-1])) if token[0] == "subsup" else ((token[0], token[2]),):
                script_element = OxmlElement("m:" + kind)
                _append_math_tokens(script_element, script_value)
                power.append(script_element)
            parent.append(power)


def _append_math(paragraph, value):
    equation = OxmlElement("m:oMath")
    _append_math_tokens(equation, value)
    paragraph._p.append(equation)


def _append_content(paragraph, value):
    for kind, chunk in segments(value):
        if kind == "math":
            _append_math(paragraph, chunk)
        else:
            paragraph.add_run(chunk)


def render_docx(content, source_name, teacher=False):
    doc = Document()
    normal = doc.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal.font.size = Pt(11)
    doc.add_heading(content["title"] + ("（教师答案版）" if teacher else "（学生卷）"), 0)
    doc.add_paragraph("参考资料：" + source_name + "。题目来源见各题标记，请教师核对。")
    for index, item in enumerate(content["questions"], 1):
        paragraph = doc.add_paragraph()
        paragraph.add_run(f"{index}. ")
        _append_content(paragraph, item["stem"])
        doc.add_paragraph(item["source"])
        if teacher:
            answer = doc.add_paragraph()
            answer.add_run("参考答案：")
            _append_content(answer, item["answer"])
        else:
            doc.add_paragraph("\n\n")
    output = BytesIO()
    doc.save(output)
    output.seek(0)
    return output
