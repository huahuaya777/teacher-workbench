"""Verify the single fictional staging fixture without printing private data.

Run in the source or an independent restored app container. A restored copy
may be written by Django's test client, never the source database.
"""

import hashlib
import os
from io import BytesIO

if os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings_staging" or os.getenv("TW_STAGING") != "1":
    raise SystemExit("STAGING_SNAPSHOT_SETTINGS_GUARD")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, override_settings
from django.urls import reverse
from docx import Document

from workbench.models import GenerationTask, Material, Worksheet, WorksheetVersion


EXPECTED_SHA256 = "8eceaa539c91797cdb742ad4d0be9f207ecfc1ed9cb9895e7bd90470221d29d5"
EXPECTED_USERNAME = "staging_preview_20261017"
EXPECTED_NAME = "离线排版样例-学生卷.docx"


def require(condition, marker):
    if not condition:
        raise SystemExit(marker)


def verify():
    require(settings.DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql", "STAGING_SNAPSHOT_NOT_POSTGRES")
    require(settings.DATABASES["default"]["NAME"] == "teacher_workbench_staging", "STAGING_SNAPSHOT_WRONG_DB")
    require(not settings.AI_ENABLED and not settings.AI_API_KEY and not settings.AI_LOCAL_QUEUE, "STAGING_SNAPSHOT_AI_NOT_DISABLED")

    users = list(get_user_model().objects.all())
    require(len(users) == 1 and users[0].username == EXPECTED_USERNAME, "STAGING_SNAPSHOT_UNEXPECTED_USERS")
    owner = users[0]
    require(owner.is_active and not owner.is_staff and not owner.is_superuser and owner.has_usable_password(), "STAGING_SNAPSHOT_USER_FLAGS")
    require(not Worksheet.objects.exists() and not WorksheetVersion.objects.exists() and not GenerationTask.objects.exists(), "STAGING_SNAPSHOT_UNEXPECTED_WORK")
    materials = list(Material.objects.all())
    require(len(materials) == 1, "STAGING_SNAPSHOT_UNEXPECTED_MATERIAL_COUNT")
    material = materials[0]
    require(material.owner_id == owner.pk and material.original_name == EXPECTED_NAME, "STAGING_SNAPSHOT_MATERIAL_OWNER_OR_NAME")
    require(material.file.name.startswith(f"materials/{owner.pk}/"), "STAGING_SNAPSHOT_MATERIAL_PATH")
    require(bool(material.extracted_text.strip()), "STAGING_SNAPSHOT_TEXT_MISSING")
    with material.file.open("rb") as source:
        raw = source.read()
    require(len(raw) == material.size_bytes, "STAGING_SNAPSHOT_FILE_SIZE")
    require(hashlib.sha256(raw).hexdigest() == EXPECTED_SHA256, "STAGING_SNAPSHOT_NOT_FICTIONAL_SAMPLE")
    require(bool(Document(BytesIO(raw)).paragraphs), "STAGING_SNAPSHOT_BAD_DOCX")

    if os.getenv("STAGING_SNAPSHOT_VERIFY_RESTORED") == "1":
        # force_login creates a session in the restored database only.
        with override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"]):
            client = Client()
            client.force_login(owner)
            response = client.get(reverse("download_material", args=[material.pk]))
            require(response.status_code == 200, "STAGING_RESTORE_OWNER_DOWNLOAD_STATUS")
            content = b"".join(response.streaming_content) if response.streaming else response.content
            response.close()
            require(hashlib.sha256(content).hexdigest() == EXPECTED_SHA256, "STAGING_RESTORE_OWNER_DOWNLOAD_HASH")
            other = get_user_model().objects.create_user(username="restore_only_other_account", password=None)
            other.set_unusable_password()
            other.save(update_fields=["password"])
            client.force_login(other)
            require(client.get(reverse("download_material", args=[material.pk])).status_code == 404, "STAGING_RESTORE_CROSS_ACCOUNT_LEAK")
        print("STAGING_RESTORE_FIXTURE_AND_ACCESS_OK")
    else:
        print("STAGING_FICTIONAL_SOURCE_VERIFIED")


if __name__ == "__main__":
    verify()
