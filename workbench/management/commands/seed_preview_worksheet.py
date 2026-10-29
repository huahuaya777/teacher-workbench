"""Create a clearly labelled, fictional formatting sample for local review only."""

from io import BytesIO

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandError
from docx import Document

from workbench.models import Material, Worksheet, WorksheetVersion


SAMPLE_TITLE = "离线排版样例：九年级数学练习"
SAMPLE_CONTENT = {
    "title": SAMPLE_TITLE,
    "questions": [
        {
            "stem": "解方程 [[math:x^2-5x+6=0]]。",
            "answer": "分解为 [[math:(x-2)(x-3)=0]]，所以 [[math:x=2]] 或 [[math:x=3]]。",
            "source": "虚构离线排版样例（非 AI 生成）",
            "ai_generated": False,
        },
        {
            "stem": "已知 [[math:y=2x+1]]，当 [[math:x=3]] 时，求 [[math:y]]。",
            "answer": "代入得 [[math:y=2×3+1=7]]。",
            "source": "虚构离线排版样例（非 AI 生成）",
            "ai_generated": False,
        },
    ],
}


class Command(BaseCommand):
    help = "在本机测试账号下创建虚构的离线 Word 排版样例，不调用 AI。"

    def add_arguments(self, parser):
        parser.add_argument("username", help="已有的本机测试账号")

    def handle(self, *args, **options):
        if not settings.DEBUG or settings.DATABASES["default"]["ENGINE"] != "django.db.backends.sqlite3":
            raise CommandError("此命令只允许在本机 DEBUG + SQLite 测试环境使用。")
        user = get_user_model().objects.filter(username=options["username"]).first()
        if user is None:
            raise CommandError("测试账号不存在。")
        if Worksheet.objects.filter(owner=user, title=SAMPLE_TITLE).exists():
            self.stdout.write("该账号已有离线排版样例，未重复创建。")
            return

        document = Document()
        document.add_heading("虚构离线排版资料", 0)
        document.add_paragraph("仅供测试 Word 公式和页面排版；不是教学原始资料，也不是模型结果。")
        output = BytesIO()
        document.save(output)
        raw = output.getvalue()
        material = Material(
            owner=user,
            original_name="offline-formatting-sample.docx",
            size_bytes=len(raw),
            extracted_text="虚构离线排版资料，仅供本地测试。",
        )
        material.file.save("offline-formatting-sample.docx", ContentFile(raw), save=False)
        material.save()
        worksheet = Worksheet.objects.create(owner=user, material=material, title=SAMPLE_TITLE)
        WorksheetVersion.objects.create(worksheet=worksheet, number=1, content=SAMPLE_CONTENT)
        self.stdout.write(self.style.SUCCESS(f"已创建离线排版样例，作业编号 {worksheet.pk}。"))
