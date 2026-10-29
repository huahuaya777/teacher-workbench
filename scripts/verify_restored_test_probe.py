"""Read-only content and access checks for an isolated restored test snapshot.

Run inside a temporary app container with its own restored PostgreSQL and
private-file volumes. Django test clients may create session rows in that
restored copy; no source-stack data is changed and no model is called.
"""

from __future__ import annotations

import os
from io import BytesIO
from zipfile import ZipFile

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, override_settings
from django.urls import reverse
from docx import Document

from workbench.models import Material, Worksheet


if settings.DATABASES["default"]["ENGINE"] != "django.db.backends.postgresql":
    if os.getenv("RESTORE_PROBE_ALLOW_SQLITE_SELFTEST") != "1":
        raise SystemExit("RESTORE_PROBE_REQUIRES_POSTGRESQL")
if settings.AI_ENABLED or settings.AI_API_KEY or settings.AI_LOCAL_QUEUE:
    raise SystemExit("RESTORE_PROBE_REQUIRES_AI_DISABLED")


def require(condition: bool, marker: str) -> None:
    if not condition:
        raise SystemExit(marker)


def response_bytes(response) -> bytes:
    raw = b"".join(response.streaming_content) if response.streaming else response.content
    response.close()
    return raw


def verify() -> None:
    user_model = get_user_model()
    alice = user_model.objects.get(username="backup_probe_alice_20261016")
    bob = user_model.objects.get(username="backup_probe_bob_20261016")
    require(not alice.has_usable_password() and not bob.has_usable_password(), "RESTORE_PROBE_ACCOUNT_MISMATCH")

    material = Material.objects.get(owner=alice, original_name="fictional-backup-probe.docx")
    require(material.file.name.startswith(f"materials/{alice.pk}/"), "RESTORE_PROBE_FILE_PATH_MISMATCH")
    require("虚构备份验证资料" in material.extracted_text, "RESTORE_PROBE_TEXT_MISMATCH")
    with material.file.open("rb") as source:
        raw = source.read()
    require(len(raw) == material.size_bytes, "RESTORE_PROBE_FILE_SIZE_MISMATCH")
    require("虚构备份验证资料" in "\n".join(p.text for p in Document(BytesIO(raw)).paragraphs), "RESTORE_PROBE_DOCX_MISMATCH")

    worksheet = Worksheet.objects.get(owner=alice, material=material, title="虚构备份恢复作业")
    versions = list(worksheet.versions.order_by("number"))
    require([version.number for version in versions] == [1, 2], "RESTORE_PROBE_VERSIONS_MISSING")
    require(versions[0].content["questions"][0]["answer"] == "当 x=2 时结果为 4。", "RESTORE_PROBE_VERSION1_MISMATCH")
    require(versions[1].content["questions"][0]["answer"] == "当 x=2 时结果为 5。", "RESTORE_PROBE_VERSION2_MISMATCH")
    require(versions[1].change_request == "虚构版本修改测试", "RESTORE_PROBE_CHANGE_REQUEST_MISSING")

    with override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"]):
        client = Client()
        require(client.get(reverse("login")).status_code == 200, "RESTORE_LOGIN_VIEW_FAILED")
        client.force_login(alice)
        download = client.get(reverse("download_material", args=[material.pk]))
        require(download.status_code == 200 and response_bytes(download) == raw, "RESTORE_OWNER_DOWNLOAD_FAILED")

        for version in versions:
            preview = client.get(reverse("worksheet_detail", args=[worksheet.pk]), {"version": version.number})
            require(preview.status_code == 200, "RESTORE_PREVIEW_FAILED")
            require(version.content["title"] in preview.content.decode("utf-8"), "RESTORE_PREVIEW_VERSION_MISMATCH")
            require(version.content["questions"][0]["answer"] in preview.content.decode("utf-8"), "RESTORE_PREVIEW_ANSWER_MISSING")
            for variant in ("student", "teacher"):
                response = client.get(reverse("export_worksheet", args=[worksheet.pk, version.number, variant]))
                require(response.status_code == 200, "RESTORE_WORD_EXPORT_FAILED")
                with ZipFile(BytesIO(response_bytes(response))) as archive:
                    xml = archive.read("word/document.xml").decode("utf-8")
                answer = version.content["questions"][0]["answer"]
                require("<m:sSup>" in xml, "RESTORE_WORD_FORMULA_MISSING")
                require((answer in xml) == (variant == "teacher"), "RESTORE_WORD_ANSWER_VARIANT_MISMATCH")

        client.force_login(bob)
        require(client.get(reverse("download_material", args=[material.pk])).status_code == 404, "RESTORE_CROSS_ACCOUNT_FILE_LEAK")
        require(client.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code == 404, "RESTORE_CROSS_ACCOUNT_PREVIEW_LEAK")
        require(client.get(reverse("export_worksheet", args=[worksheet.pk, 2, "teacher"])).status_code == 404, "RESTORE_CROSS_ACCOUNT_WORD_LEAK")

    print("RESTORE_FIXTURE_AND_ACCESS_OK")


if __name__ == "__main__":
    verify()
