"""Manually process one fictional staging task after explicit paid-call consent."""

import hashlib
import os
import sys

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from workbench.ai import configured
from workbench.management.secure_input import prompt_qwen_provider
from workbench.models import GenerationTask
from workbench.tasks import process_generation_task


EXPECTED_USERNAME = "staging_preview_20261017"
EXPECTED_NAME = "离线排版样例-学生卷.docx"
EXPECTED_SHA256 = "8eceaa539c91797cdb742ad4d0be9f207ecfc1ed9cb9895e7bd90470221d29d5"


def staging_guard():
    db = settings.DATABASES["default"]
    return (
        os.getenv("TW_STAGING") == "1"
        and os.getenv("DJANGO_SETTINGS_MODULE") == "config.settings_staging"
        and settings.AI_STAGING_MANUAL_QUEUE
        and not settings.AI_LOCAL_QUEUE
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and db["ENGINE"] == "django.db.backends.postgresql"
        and db["NAME"] == "teacher_workbench_staging"
        and db["HOST"] == "db"
        and str(settings.MEDIA_ROOT) == "/app/data/private"
        and set(settings.ALLOWED_HOSTS) == {"localhost", "127.0.0.1"}
    )


class Command(BaseCommand):
    help = "预发布虚构资料：核对并显式确认后处理单个排队任务；可能产生 API 费用。"

    def add_arguments(self, parser):
        parser.add_argument("task_id", type=int)
        parser.add_argument("--confirm-paid-call", action="store_true")
        parser.add_argument("--confirm-material-id", type=int)
        parser.add_argument("--prompt-qwen-key", action="store_true")

    def handle(self, *args, **options):
        if not staging_guard():
            raise CommandError("只允许独立预发布的虚构资料手动排队环境；没有读取 Key 或发送请求。")
        task = GenerationTask.objects.select_related("owner", "worksheet__material").filter(pk=options["task_id"]).first()
        if task is None or task.status != GenerationTask.Status.QUEUED:
            raise CommandError("未找到这个待处理任务；没有发送模型请求。")
        material = task.worksheet.material
        if (
            task.owner_id != task.worksheet.owner_id
            or task.owner_id != material.owner_id
            or task.owner.username != EXPECTED_USERNAME
            or material.original_name != EXPECTED_NAME
        ):
            raise CommandError("账号、作业或资料不符合虚构预发布样例；没有发送模型请求。")
        with material.file.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        if digest != EXPECTED_SHA256:
            raise CommandError("资料文件不符合已核对的虚构样例；没有发送模型请求。")
        self.stdout.write(f"待发送资料 {material.pk}：{material.original_name}（提取文字 {len(material.extracted_text)} 字）")
        if not options["confirm_paid_call"]:
            self.stdout.write("任务仍在排队。未提供 --confirm-paid-call，没有读取 Key 或发送模型请求。")
            return
        if options["confirm_material_id"] != material.pk:
            raise CommandError("资料编号未核对一致；没有读取 Key 或发送模型请求。")
        if not options["prompt_qwen_key"] or not sys.stdin.isatty():
            raise CommandError("需要交互式终端和 --prompt-qwen-key；没有读取 Key 或发送模型请求。")
        prompt_qwen_provider()
        if not configured():
            raise CommandError("百炼接口配置未通过检查；没有发送模型请求。")
        process_generation_task(task.pk)
        task.refresh_from_db()
        if task.status == GenerationTask.Status.DONE:
            self.stdout.write(self.style.SUCCESS("该预发布任务已完成；请在页面核对内容及厂商账单。"))
        elif task.status == GenerationTask.Status.FAILED:
            raise CommandError("任务失败；请在页面查看不含凭据的错误提示。可能已产生 API 费用。")
        else:
            raise CommandError("任务未完成；请在页面检查状态。可能已产生 API 费用。")
