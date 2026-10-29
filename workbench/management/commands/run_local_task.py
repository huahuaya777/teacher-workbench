"""Run one queued local validation task after explicit paid-call confirmation."""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from workbench.ai import configured
from workbench.management.secure_input import prompt_qwen_provider
from workbench.models import GenerationTask
from workbench.tasks import process_generation_task


class Command(BaseCommand):
    help = "本机测试：显式确认后处理一个已排队作业任务，可能产生一次 API 费用。"

    def add_arguments(self, parser):
        parser.add_argument("task_id", type=int, help="页面显示的待处理任务编号")
        parser.add_argument("--confirm-paid-call", action="store_true", help="确认执行这一个任务的真实模型请求")
        parser.add_argument("--confirm-material-id", type=int, help="核对待发送资料编号后填写，防止误发其他资料")
        parser.add_argument("--prompt-qwen-key", action="store_true", help="确认资料编号后临时输入百炼 Base URL 和 Key，不写入文件")

    def handle(self, *args, **options):
        if (
            not settings.DEBUG
            or not settings.AI_LOCAL_QUEUE
            or settings.DATABASES["default"]["ENGINE"] != "django.db.backends.sqlite3"
        ):
            raise CommandError("此命令只允许本机 DEBUG + SQLite 且 AI_LOCAL_QUEUE=1 的测试环境使用。")
        task = GenerationTask.objects.select_related("worksheet__material").filter(pk=options["task_id"]).first()
        if task is None or task.status != GenerationTask.Status.QUEUED:
            raise CommandError("未找到这个待处理任务；没有发送模型请求。")
        material = task.worksheet.material
        self.stdout.write(f"待发送资料 {material.pk}：{material.original_name}（提取文字 {len(material.extracted_text)} 字）")
        if not options["confirm_paid_call"]:
            self.stdout.write("待处理任务存在。未提供 --confirm-paid-call，没有发送模型请求。")
            return
        if options["confirm_material_id"] != material.pk:
            raise CommandError("资料编号未核对一致；没有发送模型请求。")
        if options["prompt_qwen_key"]:
            prompt_qwen_provider()
        if not configured():
            raise CommandError("真实 AI 尚未配置并启用；没有发送模型请求。")
        process_generation_task(task.pk)
        task.refresh_from_db()
        if task.status == GenerationTask.Status.DONE:
            self.stdout.write(self.style.SUCCESS("该任务已完成；请在页面核对内容及厂商账单。"))
        elif task.status == GenerationTask.Status.FAILED:
            raise CommandError("该任务失败；请在页面查看不含凭据的错误提示。可能已产生 API 费用。")
        else:
            raise CommandError("任务未完成；请在页面检查状态。可能已产生 API 费用。")
