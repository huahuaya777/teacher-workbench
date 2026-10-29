"""Seed only fictional records in the existing Ubuntu isolation stack.

The script is piped to the test web container and never runs a model call.
Both synthetic accounts have unusable passwords. A repeat call validates the
existing probe instead of overwriting it.
"""

from __future__ import annotations

import os
from io import BytesIO

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.db import transaction
from docx import Document

from workbench.models import Material, Worksheet, WorksheetVersion


if settings.DATABASES["default"]["ENGINE"] != "django.db.backends.postgresql":
    if os.getenv("BACKUP_PROBE_ALLOW_SQLITE_SELFTEST") != "1":
        raise SystemExit("BACKUP_PROBE_REQUIRES_POSTGRESQL")
if settings.AI_ENABLED or settings.AI_API_KEY or settings.AI_LOCAL_QUEUE:
    raise SystemExit("BACKUP_PROBE_REQUIRES_AI_DISABLED")

username = "backup_probe_alice_20261016"
other_name = "backup_probe_bob_20261016"
user_model = get_user_model()
existing = user_model.objects.filter(username=username).first()
if existing is not None:
    material = Material.objects.filter(owner=existing, original_name="fictional-backup-probe.docx").first()
    worksheet = Worksheet.objects.filter(owner=existing, material=material).first() if material else None
    if not material or not worksheet or list(worksheet.versions.values_list("number", flat=True)) != [2, 1]:
        raise SystemExit("BACKUP_PROBE_INCOMPLETE; refusing to overwrite")
    with material.file.open("rb") as source:
        if "虚构备份验证资料" not in "\n".join(p.text for p in Document(source).paragraphs):
            raise SystemExit("BACKUP_PROBE_FILE_MISMATCH")
    print("TEST_BACKUP_PROBE_READY (existing fictional records)")
    raise SystemExit(0)

if user_model.objects.filter(username=other_name).exists():
    raise SystemExit("BACKUP_PROBE_OTHER_ACCOUNT_EXISTS; refusing to overwrite")

document = Document()
document.add_paragraph("虚构备份验证资料：九年级数学 x² 与 2+3。")
stream = BytesIO()
document.save(stream)
raw = stream.getvalue()

with transaction.atomic():
    alice = user_model(username=username)
    alice.set_unusable_password()
    alice.save()
    bob = user_model(username=other_name)
    bob.set_unusable_password()
    bob.save()
    material = Material(
        owner=alice, original_name="fictional-backup-probe.docx",
        size_bytes=len(raw), extracted_text="虚构备份验证资料：九年级数学 x² 与 2+3。",
    )
    material.file.save("fictional-backup-probe.docx", ContentFile(raw), save=False)
    material.save()
    worksheet = Worksheet.objects.create(owner=alice, material=material, title="虚构备份恢复作业")
    WorksheetVersion.objects.create(worksheet=worksheet, number=1, content={
        "title": "虚构备份恢复作业",
        "questions": [{"stem": "计算 [[math:x^2]]。", "answer": "当 x=2 时结果为 4。",
                       "source": "虚构备份资料（非 AI 生成）", "ai_generated": False}],
    })
    WorksheetVersion.objects.create(worksheet=worksheet, number=2, change_request="虚构版本修改测试", content={
        "title": "虚构备份恢复作业（第二版）",
        "questions": [{"stem": "计算 [[math:x^2+1]]。", "answer": "当 x=2 时结果为 5。",
                       "source": "虚构备份资料（非 AI 生成）", "ai_generated": False}],
    })

print("TEST_BACKUP_PROBE_READY (fictional records created)")
