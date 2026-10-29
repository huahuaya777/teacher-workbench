"""Isolated PostgreSQL workflow checks using a disposable Django test database.

Run inside the Ubuntu test web container by piping this file to ``python -``.
No real teaching files, provider calls, persistent users, or application DB rows.
"""

from __future__ import annotations

import os
import sys
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from zipfile import ZipFile

sys.path.insert(0, str(Path.cwd()))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TransactionTestCase, override_settings
from django.test.runner import DiscoverRunner
from django.urls import reverse
from docx import Document

from workbench.models import GenerationTask, Material, Worksheet, WorksheetVersion


if settings.DATABASES["default"]["ENGINE"] != "django.db.backends.postgresql":
    if os.getenv("PG_SMOKE_ALLOW_SQLITE") != "1":
        raise SystemExit("POSTGRES_SMOKE_REQUIRES_POSTGRESQL")
if settings.AI_ENABLED or settings.AI_API_KEY or settings.AI_LOCAL_QUEUE:
    raise SystemExit("POSTGRES_SMOKE_REQUIRES_AI_DISABLED")


def fictional_docx() -> bytes:
    document = Document()
    document.add_paragraph("虚构九年级数学资料：计算 x² 与 2+3。")
    stream = BytesIO()
    document.save(stream)
    return stream.getvalue()


@override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"])
class PostgresSmoke(TransactionTestCase):
    def setUp(self):
        temp = TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        media = override_settings(MEDIA_ROOT=temp.name)
        media.enable()
        self.addCleanup(media.disable)
        user_model = get_user_model()
        self.alice = user_model.objects.create_user("pg_smoke_alice", password="fictional-test-only-123")
        self.bob = user_model.objects.create_user("pg_smoke_bob", password="fictional-test-only-456")
        self.client.force_login(self.alice)

    def test_upload_private_download_preview_and_word(self):
        raw = fictional_docx()
        upload = self.client.post(reverse("upload_material"), {
            "file": SimpleUploadedFile("fictional-algebra.docx", raw),
        })
        self.assertEqual(upload.status_code, 302)
        material = Material.objects.get(owner=self.alice)
        self.assertIn("虚构九年级数学资料", material.extracted_text)

        downloaded = self.client.get(reverse("download_material", args=[material.pk]))
        self.assertEqual(downloaded.status_code, 200)
        self.assertEqual(b"".join(downloaded.streaming_content), raw)
        downloaded.close()

        content = {
            "title": "虚构 PostgreSQL 验证作业",
            "questions": [{
                "stem": "计算 [[math:x^2+2]]。",
                "answer": "当 x=2 时，答案为 6。",
                "source": "虚构本地验证资料（非 AI 生成）",
                "ai_generated": False,
            }],
        }
        worksheet = Worksheet.objects.create(owner=self.alice, material=material, title=content["title"])
        WorksheetVersion.objects.create(worksheet=worksheet, number=1, content=content)
        preview = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        self.assertContains(preview, "虚构 PostgreSQL 验证作业")
        self.assertContains(preview, "答案为 6")

        for variant in ("student", "teacher"):
            response = self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, variant]))
            self.assertEqual(response.status_code, 200)
            with ZipFile(BytesIO(b"".join(response.streaming_content))) as archive:
                xml = archive.read("word/document.xml").decode("utf-8")
            response.close()
            self.assertIn("<m:sSup>", xml)
            self.assertIn("虚构本地验证资料", xml)
            if variant == "student":
                self.assertNotIn("答案为 6", xml)
            else:
                self.assertIn("答案为 6", xml)

        with patch("workbench.views.enqueue_task") as queue, patch("workbench.ai._open_provider_request") as provider:
            blocked = self.client.post(reverse("create_worksheet", args=[material.pk]))
        self.assertEqual(blocked.status_code, 302)
        self.assertEqual(GenerationTask.objects.count(), 0)
        queue.assert_not_called()
        provider.assert_not_called()

        self.client.force_login(self.bob)
        self.assertEqual(self.client.get(reverse("download_material", args=[material.pk])).status_code, 404)
        self.assertEqual(self.client.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code, 404)
        self.assertEqual(self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"])).status_code, 404)


if __name__ == "__main__":
    runner = DiscoverRunner(verbosity=1, interactive=False)
    failures = runner.run_tests(["__main__.PostgresSmoke"])
    if failures:
        raise SystemExit(1)
    print("POSTGRES_SMOKE_WORKFLOW_OK")
