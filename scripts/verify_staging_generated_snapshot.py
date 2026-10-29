"""Check the one completed fictional staging worksheet without printing its text.

Source checks are read-only. Django test-client access checks run only against
an independent restored database selected by STAGING_GENERATED_VERIFY_RESTORED.
"""

import hashlib
import os
from io import BytesIO

if os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings_staging" or os.getenv("TW_STAGING") != "1":
    raise SystemExit("STAGING_GENERATED_SETTINGS_GUARD")

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


def response_bytes(response):
    try:
        return b"".join(response.streaming_content) if response.streaming else response.content
    finally:
        response.close()


def verify():
    db = settings.DATABASES["default"]
    require(db["ENGINE"] == "django.db.backends.postgresql" and db["NAME"] == "teacher_workbench_staging", "STAGING_GENERATED_WRONG_DB")
    require(settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY and not settings.AI_LOCAL_QUEUE, "STAGING_GENERATED_AI_GUARD")
    require(str(settings.MEDIA_ROOT) == "/app/data/private", "STAGING_GENERATED_PRIVATE_ROOT")

    users = list(get_user_model().objects.all())
    require(len(users) == 1 and users[0].username == EXPECTED_USERNAME, "STAGING_GENERATED_UNEXPECTED_USERS")
    owner = users[0]
    require(owner.is_active and not owner.is_staff and not owner.is_superuser and owner.has_usable_password(), "STAGING_GENERATED_USER_FLAGS")

    materials = list(Material.objects.all())
    require(len(materials) == 1, "STAGING_GENERATED_MATERIAL_COUNT")
    material = materials[0]
    require(material.pk == 1 and material.owner_id == owner.pk and material.original_name == EXPECTED_NAME, "STAGING_GENERATED_MATERIAL_IDENTITY")
    require(material.file.name.startswith(f"materials/{owner.pk}/") and len(material.extracted_text) == 153, "STAGING_GENERATED_MATERIAL_TEXT_OR_PATH")
    with material.file.open("rb") as source:
        raw = source.read()
    require(len(raw) == material.size_bytes and hashlib.sha256(raw).hexdigest() == EXPECTED_SHA256, "STAGING_GENERATED_MATERIAL_HASH")
    require(bool(Document(BytesIO(raw)).paragraphs), "STAGING_GENERATED_BAD_SOURCE_DOCX")

    worksheets = list(Worksheet.objects.all())
    require(len(worksheets) == 1, "STAGING_GENERATED_WORKSHEET_COUNT")
    worksheet = worksheets[0]
    require(worksheet.owner_id == owner.pk and worksheet.material_id == material.pk, "STAGING_GENERATED_WORKSHEET_OWNER")
    tasks = list(GenerationTask.objects.all())
    require(len(tasks) == 1 and tasks[0].pk == 1, "STAGING_GENERATED_TASK_COUNT")
    task = tasks[0]
    require(task.owner_id == owner.pk and task.worksheet_id == worksheet.pk and task.kind == GenerationTask.Kind.CREATE and task.status == GenerationTask.Status.DONE, "STAGING_GENERATED_TASK_STATE")
    require(not task.instruction and not task.error_message, "STAGING_GENERATED_TASK_UNEXPECTED_FIELDS")

    versions = list(WorksheetVersion.objects.all())
    require(len(versions) == 1, "STAGING_GENERATED_VERSION_COUNT")
    version = versions[0]
    require(version.worksheet_id == worksheet.pk and version.number == 1 and not version.change_request, "STAGING_GENERATED_VERSION_IDENTITY")
    content = version.content
    require(isinstance(content, dict) and isinstance(content.get("title"), str) and bool(content["title"].strip()), "STAGING_GENERATED_TITLE")
    require(worksheet.title == content["title"], "STAGING_GENERATED_TITLE_MISMATCH")
    questions = content.get("questions")
    require(isinstance(questions, list) and 1 <= len(questions) <= 20, "STAGING_GENERATED_QUESTIONS")
    for item in questions:
        require(isinstance(item, dict), "STAGING_GENERATED_QUESTION_TYPE")
        require(isinstance(item.get("stem"), str) and bool(item["stem"].strip()), "STAGING_GENERATED_STEM")
        require(isinstance(item.get("answer"), str) and bool(item["answer"].strip()), "STAGING_GENERATED_ANSWER")
        require(item.get("ai_generated") is True and item.get("source") == "AI生成（原题出处未核实）", "STAGING_GENERATED_SOURCE_MARKER")

    if os.getenv("STAGING_GENERATED_VERIFY_RESTORED") == "1":
        # force_login and the second user write only to the new restored DB.
        with override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"]):
            client = Client()
            client.force_login(owner)
            download = client.get(reverse("download_material", args=[material.pk]))
            require(download.status_code == 200 and hashlib.sha256(response_bytes(download)).hexdigest() == EXPECTED_SHA256, "STAGING_GENERATED_RESTORE_DOWNLOAD")
            require(client.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code == 200, "STAGING_GENERATED_RESTORE_PREVIEW")
            documents = []
            for variant in ("student", "teacher"):
                response = client.get(reverse("export_worksheet", args=[worksheet.pk, 1, variant]))
                require(response.status_code == 200, "STAGING_GENERATED_RESTORE_EXPORT_STATUS")
                data = response_bytes(response)
                require(len(data) > 1000, "STAGING_GENERATED_RESTORE_EXPORT_EMPTY")
                Document(BytesIO(data))
                documents.append(data)
            require(documents[0] != documents[1], "STAGING_GENERATED_RESTORE_EXPORTS_IDENTICAL")
            other = get_user_model().objects.create_user(username="generated_restore_other", password=None)
            other.set_unusable_password()
            other.save(update_fields=["password"])
            client.force_login(other)
            for url in (
                reverse("download_material", args=[material.pk]),
                reverse("worksheet_detail", args=[worksheet.pk]),
                reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"]),
            ):
                require(client.get(url).status_code == 404, "STAGING_GENERATED_RESTORE_CROSS_ACCOUNT_LEAK")
        print("STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK")
    else:
        print("STAGING_GENERATED_SOURCE_VERIFIED")


if __name__ == "__main__":
    verify()
