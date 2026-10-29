"""Check two fictional versions in the independent NAS-source restore."""

import hashlib
import os
from io import BytesIO

if os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings_staging" or os.getenv("TW_STAGING") != "1":
    raise SystemExit("STAGING_REVISED_SETTINGS_GUARD")

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
    restored = os.getenv("STAGING_REVISED_VERIFY_RESTORED") == "1"
    expected_host = "teacher-workbench-staging-revised-nas-restore-20261017-db" if restored else "db"
    require(
        db["ENGINE"] == "django.db.backends.postgresql"
        and db["NAME"] == "teacher_workbench_staging"
        and db["HOST"] == expected_host,
        "STAGING_REVISED_WRONG_DB",
    )
    require(
        settings.AI_STAGING_MANUAL_QUEUE
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and not settings.AI_LOCAL_QUEUE,
        "STAGING_REVISED_AI_GUARD",
    )
    require(str(settings.MEDIA_ROOT) == "/app/data/private", "STAGING_REVISED_PRIVATE_ROOT")

    users = list(get_user_model().objects.all())
    require(len(users) == 1 and users[0].username == EXPECTED_USERNAME, "STAGING_REVISED_USERS")
    owner = users[0]
    require(owner.is_active and not owner.is_staff and not owner.is_superuser and owner.has_usable_password(), "STAGING_REVISED_USER_FLAGS")

    materials = list(Material.objects.all())
    require(len(materials) == 1, "STAGING_REVISED_MATERIAL_COUNT")
    material = materials[0]
    require(
        material.pk == 1 and material.owner_id == owner.pk
        and material.original_name == EXPECTED_NAME and len(material.extracted_text) == 153,
        "STAGING_REVISED_MATERIAL_IDENTITY",
    )
    with material.file.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    require(digest == EXPECTED_SHA256, "STAGING_REVISED_MATERIAL_HASH")

    worksheets = list(Worksheet.objects.all())
    require(len(worksheets) == 1, "STAGING_REVISED_WORKSHEET_COUNT")
    worksheet = worksheets[0]
    require(worksheet.pk == 1 and worksheet.owner_id == owner.pk and worksheet.material_id == 1, "STAGING_REVISED_WORKSHEET_IDENTITY")
    tasks = {task.pk: task for task in GenerationTask.objects.all()}
    require(set(tasks) == {1, 2}, "STAGING_REVISED_TASK_COUNT")
    for number, kind in ((1, GenerationTask.Kind.CREATE), (2, GenerationTask.Kind.REVISE)):
        task = tasks[number]
        require(
            task.owner_id == owner.pk and task.worksheet_id == worksheet.pk
            and task.kind == kind and task.status == GenerationTask.Status.DONE
            and not task.error_message,
            f"STAGING_REVISED_TASK_{number}_STATE",
        )
    require(not tasks[1].instruction and bool(tasks[2].instruction.strip()), "STAGING_REVISED_INSTRUCTION")

    versions = {version.number: version for version in WorksheetVersion.objects.all()}
    require(set(versions) == {1, 2}, "STAGING_REVISED_VERSION_COUNT")
    require(
        all(version.worksheet_id == worksheet.pk for version in versions.values())
        and not versions[1].change_request
        and versions[2].change_request == tasks[2].instruction,
        "STAGING_REVISED_VERSION_IDENTITY",
    )
    for number, version in versions.items():
        content = version.content
        require(
            isinstance(content, dict)
            and isinstance(content.get("title"), str) and bool(content["title"].strip())
            and isinstance(content.get("questions"), list)
            and 1 <= len(content["questions"]) <= 20,
            f"STAGING_REVISED_VERSION_{number}_CONTENT",
        )
        for item in content["questions"]:
            require(
                isinstance(item, dict)
                and isinstance(item.get("stem"), str) and bool(item["stem"].strip())
                and isinstance(item.get("answer"), str) and bool(item["answer"].strip())
                and item.get("ai_generated") is True
                and item.get("source") == "AI生成（原题出处未核实）",
                f"STAGING_REVISED_VERSION_{number}_QUESTION",
            )
    require(worksheet.title == versions[2].content["title"], "STAGING_REVISED_TITLE")
    if restored:
        # This branch is restricted to the independent restored database.
        with override_settings(ALLOWED_HOSTS=["testserver", "localhost", "127.0.0.1"]):
            client = Client()
            client.force_login(owner)
            download = client.get(reverse("download_material", args=[material.pk]))
            require(
                download.status_code == 200
                and hashlib.sha256(response_bytes(download)).hexdigest() == EXPECTED_SHA256,
                "STAGING_REVISED_RESTORE_DOWNLOAD",
            )
            for number in (1, 2):
                preview = client.get(reverse("worksheet_detail", args=[worksheet.pk]) + f"?version={number}")
                require(preview.status_code == 200, "STAGING_REVISED_RESTORE_PREVIEW")
                documents = []
                for variant in ("student", "teacher"):
                    response = client.get(reverse("export_worksheet", args=[worksheet.pk, number, variant]))
                    require(response.status_code == 200, "STAGING_REVISED_RESTORE_EXPORT_STATUS")
                    data = response_bytes(response)
                    require(len(data) > 1000, "STAGING_REVISED_RESTORE_EXPORT_EMPTY")
                    Document(BytesIO(data))
                    documents.append(data)
                require(documents[0] != documents[1], "STAGING_REVISED_RESTORE_EXPORTS_IDENTICAL")
            other = get_user_model().objects.create_user(username="revised_restore_other", password=None)
            other.set_unusable_password()
            other.save(update_fields=["password"])
            client.force_login(other)
            for url in (
                reverse("download_material", args=[material.pk]),
                reverse("worksheet_detail", args=[worksheet.pk]),
                reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"]),
                reverse("export_worksheet", args=[worksheet.pk, 2, "teacher"]),
            ):
                require(client.get(url).status_code == 404, "STAGING_REVISED_RESTORE_CROSS_ACCOUNT_LEAK")
        print("STAGING_REVISED_NAS_RESTORE_CONTENT_AND_ACCESS_OK")
    else:
        print("STAGING_REVISED_SOURCE_VERIFIED")


if __name__ == "__main__":
    verify()
