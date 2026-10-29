"""Read-only formatting audit of the owner's saved drafts; print no content."""

import os
import re
from io import BytesIO
from zipfile import ZipFile

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.contrib.auth import get_user_model

from workbench.export import render_docx
from workbench.models import WorksheetVersion
from workbench.templatetags.worksheet_display import math_segments


owner = get_user_model().objects.get(username="huahua")
versions = list(WorksheetVersion.objects.filter(worksheet__owner=owner))
assert versions
fraction_count = 0
bad = re.compile(r"\\(?:frac|sqrt|text|leq|geq|in|left|right)\b|\[\[math")
for version in versions:
    content = version.content
    for item in content["questions"]:
        assert not bad.search(str(math_segments(item["stem"])))
        assert not bad.search(str(math_segments(item["answer"])))
    with ZipFile(BytesIO(render_docx(content, "source.docx", teacher=True).getvalue())) as archive:
        xml = archive.read("word/document.xml").decode("utf-8")
    assert not bad.search(xml)
    fraction_count += xml.count("<m:f>")
assert fraction_count > 0
print("PILOT_SAVED_DRAFTS_MATH_PREVIEW_AND_WORD_CLEAN")
print(f"PILOT_SAVED_DRAFT_VERSION_COUNT={len(versions)}")
print(f"PILOT_SAVED_DRAFT_WORD_FRACTION_COUNT={fraction_count}")
