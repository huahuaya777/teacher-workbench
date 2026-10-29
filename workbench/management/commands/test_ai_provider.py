"""One explicitly authorized paid-call probe with fictional teaching material."""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from workbench.ai import AIResponseError, AIUnavailable, configured, request_worksheet
from workbench.management.secure_input import prompt_qwen_provider


FICTIONAL_SOURCE = (
    "虚构的九年级数学练习：一元二次方程 x^2-5x+6=0。"
    "只需围绕因式分解与代入检验编写简短练习。"
)


class Command(BaseCommand):
    help = "用虚构资料检查一次真实模型接口；必须显式确认，可能产生 API 费用。"

    def add_arguments(self, parser):
        parser.add_argument(
            "--confirm-paid-call", action="store_true",
            help="确认只发送这一次虚构资料请求，可能产生 API 费用",
        )
        parser.add_argument(
            "--prompt-qwen-key", action="store_true",
            help="本进程可见输入北京地域 Base URL，再隐藏输入百炼 Key，不写入文件或命令历史",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG or settings.DATABASES["default"]["ENGINE"] != "django.db.backends.sqlite3":
            raise CommandError("此命令只允许在本机 DEBUG + SQLite 测试环境使用。")
        if options["prompt_qwen_key"]:
            if not options["confirm_paid_call"]:
                raise CommandError("安全输入模式还需 --confirm-paid-call；没有读取 Key 或发送请求。")
            prompt_qwen_provider()
        if not configured():
            raise CommandError("真实 AI 尚未配置并启用；没有发送请求。")
        if not options["confirm_paid_call"]:
            self.stdout.write("配置已就绪。未提供 --confirm-paid-call，没有发送请求或产生本命令的模型费用。")
            return
        self.stdout.write("将发送一次虚构数学资料请求；不会读取或发送私人教学文件。")
        try:
            content = request_worksheet(
                FICTIONAL_SOURCE,
                teaching_context={"subject": "数学", "grade": "九年级", "textbook_edition": "人教版"},
            )
        except (AIUnavailable, AIResponseError) as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(
            f"接口返回结构有效：{len(content['questions'])} 道题。数学正确性与实际账单仍需人工核对。"
        ))
