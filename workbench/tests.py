from io import BytesIO, StringIO
import hashlib
import json
from tempfile import TemporaryDirectory
from unittest import skipUnless
from unittest.mock import patch
from urllib.error import HTTPError
from zipfile import ZipFile

from django.contrib.auth import get_user_model
from django.conf import settings
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase, TestCase, TransactionTestCase, override_settings
from django.urls import reverse
from docx import Document

from .models import GenerationTask, Material, TeacherProfile, Worksheet, WorksheetVersion
from .extract import extract_text
from .export import render_docx
from .ai import AIResponseError, _NoRedirect, _open_provider_request, configured, request_worksheet
from .forms import MAX_UPLOAD_BYTES
from .tasks import process_generation_task
from .queue import enqueue_task
from .auth_views import MAX_FAILURES, _counter_key
from .templatetags.worksheet_display import math_segments


local_sqlite_only = skipUnless(
    settings.DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3",
    "本机专用命令只允许 SQLite 测试环境",
)
postgres_only = skipUnless(
    settings.DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql",
    "仅检查 PostgreSQL 隔离测试环境的本机命令防护",
)


@override_settings(CACHES={"default": {
    "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    "LOCATION": "login-throttle-tests",
}})
class LoginThrottleTests(TestCase):
    def setUp(self):
        cache.clear()
        get_user_model().objects.create_user("teacher_a", password="Test-password-123")
        get_user_model().objects.create_user("teacher_b", password="Test-password-456")

    def test_repeated_failure_blocks_even_correct_password_until_counter_expires(self):
        url = reverse("login")
        for _ in range(MAX_FAILURES):
            response = self.client.post(url, {"username": "teacher_a", "password": "wrong"})
            self.assertEqual(response.status_code, 200)
        blocked = self.client.post(url, {"username": "teacher_a", "password": "Test-password-123"})
        self.assertEqual(blocked.status_code, 429)
        self.assertContains(blocked, "15 分钟后再试", status_code=429)
        self.assertNotIn("_auth_user_id", self.client.session)

        cache.delete(_counter_key("teacher_a"))  # Simulate the 15-minute expiry.
        allowed = self.client.post(url, {"username": "teacher_a", "password": "Test-password-123"})
        self.assertEqual(allowed.status_code, 302)
        self.assertIn("_auth_user_id", self.client.session)

    def test_other_account_still_logs_in_and_success_clears_failure_count(self):
        url = reverse("login")
        self.client.post(url, {"username": "teacher_a", "password": "wrong"})
        self.assertEqual(cache.get(_counter_key("teacher_a")), 1)
        other = self.client.post(url, {"username": "teacher_b", "password": "Test-password-456"})
        self.assertEqual(other.status_code, 302)
        self.client.post(reverse("logout"))
        correct = self.client.post(url, {"username": "teacher_a", "password": "Test-password-123"})
        self.assertEqual(correct.status_code, 302)
        self.assertIsNone(cache.get(_counter_key("teacher_a")))

    def test_counter_key_does_not_contain_username(self):
        self.assertEqual(_counter_key(" Teacher_A "), _counter_key("teacher_a"))
        self.assertNotIn("teacher_a", _counter_key("teacher_a"))

    def test_admin_login_uses_same_limit(self):
        get_user_model().objects.create_user("staff_a", password="Test-password-789", is_staff=True)
        url = reverse("admin:login")
        for _ in range(MAX_FAILURES):
            self.assertEqual(self.client.post(url, {"username": "staff_a", "password": "wrong"}).status_code, 200)
        blocked = self.client.post(url, {"username": "staff_a", "password": "Test-password-789"})
        self.assertEqual(blocked.status_code, 429)
        self.assertContains(blocked, "15 分钟后再试", status_code=429)
        self.assertNotIn("_auth_user_id", self.client.session)

    def test_switching_between_login_routes_does_not_reset_limit(self):
        get_user_model().objects.create_user("staff_b", password="Test-password-987", is_staff=True)
        for _ in range(MAX_FAILURES):
            self.client.post(reverse("login"), {"username": "staff_b", "password": "wrong"})
        blocked = self.client.post(reverse("admin:login"), {
            "username": "staff_b", "password": "Test-password-987",
        })
        self.assertEqual(blocked.status_code, 429)
        self.assertNotIn("_auth_user_id", self.client.session)


@postgres_only
@override_settings(DEBUG=True, AI_LOCAL_QUEUE=True)
class PostgresCommandGuardTests(SimpleTestCase):
    def test_paid_probe_rejects_postgres_before_model_call(self):
        with patch("workbench.management.commands.test_ai_provider.request_worksheet") as provider:
            with self.assertRaisesMessage(CommandError, "只允许在本机 DEBUG + SQLite"):
                call_command("test_ai_provider", "--confirm-paid-call", stdout=StringIO())
        provider.assert_not_called()

    def test_local_task_rejects_postgres_before_key_prompt(self):
        with patch("workbench.management.commands.run_local_task.prompt_qwen_provider") as prompt:
            with self.assertRaisesMessage(CommandError, "只允许本机 DEBUG + SQLite"):
                call_command("run_local_task", "1", "--prompt-qwen-key", "--confirm-paid-call",
                             "--confirm-material-id", "1", stdout=StringIO())
        prompt.assert_not_called()

    def test_offline_sample_rejects_postgres_before_creating_data(self):
        with self.assertRaisesMessage(CommandError, "只允许在本机 DEBUG + SQLite"):
            call_command("seed_preview_worksheet", "fictional-user", stdout=StringIO())


@override_settings(DEBUG=True, AI_ENABLED=True, AI_PROVIDER="openai-compatible", AI_BASE_URL="https://example.invalid/v1", AI_MODEL="fake", AI_API_KEY="fake")
class PaidProbeSafetyTests(TestCase):
    def test_provider_redirect_is_not_followed(self):
        with patch("workbench.ai.build_opener") as factory:
            _open_provider_request("fake-request", timeout=2)
        handler = factory.call_args.args[0]
        self.assertIsInstance(handler, _NoRedirect)
        self.assertIsNone(handler.redirect_request(None, None, 302, "Found", {}, "https://other.invalid"))
        factory.return_value.open.assert_called_once_with("fake-request", timeout=2)

    @local_sqlite_only
    def test_probe_without_confirmation_never_calls_provider(self):
        output = StringIO()
        with patch("workbench.management.commands.test_ai_provider.request_worksheet") as provider:
            call_command("test_ai_provider", stdout=output)
        provider.assert_not_called()
        self.assertIn("没有发送请求", output.getvalue())

    @local_sqlite_only
    def test_confirmed_probe_uses_only_fictional_material(self):
        output = StringIO()
        with patch("workbench.management.commands.test_ai_provider.request_worksheet", return_value={
            "title": "虚构测试", "questions": [{"stem": "题目", "answer": "答案"}],
        }) as provider:
            call_command("test_ai_provider", "--confirm-paid-call", stdout=output)
        provider.assert_called_once()
        source = provider.call_args.args[0]
        self.assertIn("虚构", source)
        self.assertIn("1 道题", output.getvalue())

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://example.invalid/compatible-mode/v1")
    def test_qwen_rejects_unrelated_endpoint(self):
        self.assertFalse(configured())

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1")
    def test_qwen_accepts_official_beijing_endpoint(self):
        self.assertTrue(configured())

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://dashscope.aliyuncs.com.evil.invalid/compatible-mode/v1")
    def test_qwen_rejects_lookalike_endpoint(self):
        self.assertFalse(configured())

    @local_sqlite_only
    def test_key_prompt_without_paid_confirmation_does_not_read_or_call(self):
        with patch("builtins.input") as host_prompt, patch("workbench.management.secure_input.prompt_secret") as prompt, patch(
            "workbench.management.commands.test_ai_provider.request_worksheet"
        ) as provider:
            with self.assertRaises(CommandError):
                call_command("test_ai_provider", "--prompt-qwen-key")
        host_prompt.assert_not_called()
        prompt.assert_not_called()
        provider.assert_not_called()

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="")
    @local_sqlite_only
    def test_key_prompt_uses_only_current_process(self):
        output = StringIO()
        with patch("builtins.input", return_value="") as host_prompt, patch(
            "workbench.management.secure_input.prompt_secret", return_value="fake-only"
        ) as prompt, patch(
            "workbench.management.commands.test_ai_provider.request_worksheet", return_value={
                "title": "虚构测试", "questions": [{"stem": "题目", "answer": "答案"}],
            }
        ) as provider:
            call_command("test_ai_provider", "--prompt-qwen-key", "--confirm-paid-call", stdout=output)
        host_prompt.assert_called_once()
        prompt.assert_called_once()
        provider.assert_called_once()
        self.assertNotIn("fake-only", output.getvalue())
        self.assertIn("虚构", provider.call_args.args[0])

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="")
    @local_sqlite_only
    def test_key_prompt_rejects_unapproved_host_before_reading_key(self):
        with patch("builtins.input", return_value="https://evil.invalid/v1") as host_prompt, patch(
            "workbench.management.secure_input.prompt_secret"
        ) as prompt, patch(
            "workbench.management.commands.test_ai_provider.request_worksheet"
        ) as provider:
            with self.assertRaisesMessage(CommandError, "Base URL 不符合北京地域"):
                call_command("test_ai_provider", "--prompt-qwen-key", "--confirm-paid-call")
        host_prompt.assert_called_once()
        prompt.assert_not_called()
        provider.assert_not_called()

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="")
    @local_sqlite_only
    def test_key_prompt_accepts_workspace_host(self):
        with patch("builtins.input", return_value="https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"), patch(
            "workbench.management.secure_input.prompt_secret", return_value="fake-only"
        ), patch("workbench.management.commands.test_ai_provider.request_worksheet", return_value={
            "title": "虚构测试", "questions": [{"stem": "题目", "answer": "答案"}],
        }) as provider:
            call_command("test_ai_provider", "--prompt-qwen-key", "--confirm-paid-call", stdout=StringIO())
        provider.assert_called_once()

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="")
    @local_sqlite_only
    def test_key_prompt_rejects_control_character_before_call(self):
        with patch("builtins.input", return_value="https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"), patch(
            "workbench.management.secure_input.prompt_secret", return_value="\x16"
        ), patch("workbench.management.commands.test_ai_provider.request_worksheet") as provider:
            with self.assertRaisesMessage(CommandError, "控制字符"):
                call_command("test_ai_provider", "--prompt-qwen-key", "--confirm-paid-call")
        provider.assert_not_called()

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1")
    def test_http_error_shows_only_status_and_safe_hint(self):
        error = HTTPError(
            "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", 401,
            "private-provider-message", {}, BytesIO(b'{"message":"private-secret-marker"}'),
        )
        with patch("workbench.ai._open_provider_request", side_effect=error):
            with self.assertRaises(AIResponseError) as result:
                request_worksheet("虚构数学资料")
        self.assertIn("HTTP 401", str(result.exception))
        self.assertNotIn("private-secret-marker", str(result.exception))
        self.assertNotIn("private-provider-message", str(result.exception))

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1")
    def test_invalid_provider_json_is_classified_without_echoing_it(self):
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def read(self, _size):
                return b"private-secret-marker"

        with patch("workbench.ai._open_provider_request", return_value=FakeResponse()):
            with self.assertRaises(AIResponseError) as result:
                request_worksheet("虚构数学资料")
        self.assertIn("不是有效 JSON", str(result.exception))
        self.assertNotIn("private-secret-marker", str(result.exception))

    @override_settings(AI_PROVIDER="qwen", AI_MODEL="qwen-flash", AI_BASE_URL="https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1")
    def test_qwen_uses_json_mode_without_thinking(self):
        response_body = json.dumps({"choices": [{"message": {"content": json.dumps(SAMPLE_CONTENT)}}]}).encode()

        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def read(self, _size):
                return response_body

        with patch("workbench.ai._open_provider_request", return_value=FakeResponse()) as remote_call:
            request_worksheet("虚构数学资料")
        sent = json.loads(remote_call.call_args.args[0].data)
        self.assertEqual(sent["model"], "qwen-flash")
        self.assertFalse(sent["enable_thinking"])
        self.assertEqual(sent["response_format"], {"type": "json_object"})
        self.assertEqual(remote_call.call_args.args[0].full_url,
                         "https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions")


@override_settings(
    DEBUG=True, AI_LOCAL_QUEUE=True, AI_ENABLED=True, AI_PROVIDER="qwen",
    AI_BASE_URL="https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
    AI_MODEL="qwen-flash", AI_API_KEY="fake",
)
@local_sqlite_only
class LocalQueueTests(TestCase):
    def test_local_queue_waits_for_explicit_single_task_run(self):
        user = get_user_model().objects.create_user("local_probe_user", password="test-password-only")
        material = Material.objects.create(
            owner=user, file="synthetic.docx", original_name="synthetic.docx",
            size_bytes=1, extracted_text="虚构数学资料",
        )
        worksheet = Worksheet.objects.create(owner=user, material=material)
        task = GenerationTask.objects.create(owner=user, worksheet=worksheet, kind=GenerationTask.Kind.CREATE)
        with patch("workbench.queue.Redis.from_url") as redis_connection:
            enqueue_task(task.pk)
        redis_connection.assert_not_called()
        with patch("workbench.tasks.request_worksheet") as provider:
            call_command("run_local_task", str(task.pk), stdout=StringIO())
        provider.assert_not_called()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.QUEUED)
        with patch("workbench.tasks.request_worksheet") as provider:
            with self.assertRaises(CommandError):
                call_command("run_local_task", str(task.pk), "--confirm-paid-call",
                             "--confirm-material-id", str(material.pk + 1), stdout=StringIO())
        provider.assert_not_called()
        with patch("workbench.tasks.request_worksheet", return_value=SAMPLE_CONTENT) as provider:
            call_command("run_local_task", str(task.pk), "--confirm-paid-call",
                         "--confirm-material-id", str(material.pk), stdout=StringIO())
        provider.assert_called_once()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.DONE)
        self.assertEqual(worksheet.versions.count(), 1)

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="", AI_MODEL="")
    def test_local_page_can_queue_without_storing_a_key(self):
        user = get_user_model().objects.create_user("queue_without_key", password="test-password-only")
        material = Material.objects.create(
            owner=user, file="fictional.docx", original_name="fictional.docx",
            size_bytes=1, extracted_text="虚构数学资料",
        )
        self.client.force_login(user)
        dashboard = self.client.get(reverse("dashboard"))
        self.assertContains(dashboard, "本机测试排队模式已启用")
        with patch("workbench.queue.Redis.from_url") as redis_connection, patch(
            "workbench.tasks.request_worksheet"
        ) as provider:
            response = self.client.post(reverse("create_worksheet", args=[material.pk]))
        self.assertEqual(response.status_code, 302)
        self.assertEqual(GenerationTask.objects.get(worksheet__material=material).status, GenerationTask.Status.QUEUED)
        redis_connection.assert_not_called()
        provider.assert_not_called()

    @override_settings(AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="", AI_MODEL="")
    def test_local_task_prompts_for_key_only_after_matching_material_confirmation(self):
        user = get_user_model().objects.create_user("task_without_key", password="test-password-only")
        material = Material.objects.create(
            owner=user, file="fictional.docx", original_name="fictional.docx",
            size_bytes=1, extracted_text="虚构数学资料",
        )
        worksheet = Worksheet.objects.create(owner=user, material=material)
        task = GenerationTask.objects.create(owner=user, worksheet=worksheet, kind=GenerationTask.Kind.CREATE)
        with patch("workbench.management.commands.run_local_task.prompt_qwen_provider") as prompt, patch(
            "workbench.tasks.request_worksheet"
        ) as provider:
            call_command("run_local_task", str(task.pk), "--prompt-qwen-key", stdout=StringIO())
            with self.assertRaisesMessage(CommandError, "资料编号未核对一致"):
                call_command("run_local_task", str(task.pk), "--prompt-qwen-key", "--confirm-paid-call",
                             "--confirm-material-id", str(material.pk + 1), stdout=StringIO())
        prompt.assert_not_called()
        provider.assert_not_called()
        with patch("builtins.input", return_value="https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"), patch(
            "workbench.management.secure_input.prompt_secret", return_value="fake-only"
        ), patch("workbench.tasks.request_worksheet", return_value=SAMPLE_CONTENT) as provider:
            call_command("run_local_task", str(task.pk), "--prompt-qwen-key", "--confirm-paid-call",
                         "--confirm-material-id", str(material.pk), stdout=StringIO())
        provider.assert_called_once()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.DONE)


@local_sqlite_only
@override_settings(DEBUG=True, AI_STAGING_MANUAL_QUEUE=True, AI_LOCAL_QUEUE=False,
                   AI_ENABLED=False, AI_API_KEY="", AI_BASE_URL="", AI_MODEL="")
class StagingManualQueueTests(TestCase):
    def test_revision_from_preview_only_queues_and_preserves_first_version(self):
        with TemporaryDirectory() as private_root, override_settings(MEDIA_ROOT=private_root):
            user = get_user_model().objects.create_user("staging_preview_20261017", password="test-password-only")
            raw = b"fictional-stage-test-bytes"
            material = Material.objects.create(
                owner=user, file=SimpleUploadedFile("fictional.docx", raw),
                original_name="离线排版样例-学生卷.docx", size_bytes=len(raw), extracted_text="虚构资料",
            )
            worksheet = Worksheet.objects.create(owner=user, material=material)
            WorksheetVersion.objects.create(worksheet=worksheet, number=1, content=SAMPLE_CONTENT)
            self.client.force_login(user)
            page = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
            self.assertContains(page, "提交修改要求")
            with patch("workbench.queue.Redis.from_url") as redis_connection, patch(
                "workbench.tasks.request_worksheet"
            ) as provider:
                response = self.client.post(reverse("revise_worksheet", args=[worksheet.pk]), {
                    "instruction": "请把第 1 题的讲解改为两步，保留原题",
                }, follow=True)
            self.assertContains(response, "修改任务已排队")
            self.assertContains(response, "修改：排队中")
            self.assertContains(response, "草稿预览 · 第 1 版")
            self.assertNotContains(response, "提交修改要求")
            self.assertEqual(worksheet.versions.count(), 1)
            self.assertEqual(worksheet.tasks.get(kind=GenerationTask.Kind.REVISE).status, GenerationTask.Status.QUEUED)
            redis_connection.assert_not_called()
            provider.assert_not_called()

    def test_browser_queue_and_command_need_separate_paid_confirmation(self):
        with TemporaryDirectory() as private_root, override_settings(MEDIA_ROOT=private_root):
            user = get_user_model().objects.create_user("staging_preview_20261017", password="test-password-only")
            raw = b"fictional-stage-test-bytes"
            material = Material.objects.create(
                owner=user, file=SimpleUploadedFile("fictional.docx", raw),
                original_name="离线排版样例-学生卷.docx", size_bytes=len(raw), extracted_text="虚构资料",
            )
            self.client.force_login(user)
            self.assertContains(self.client.get(reverse("worksheet_start")), "预发布手动排队模式已启用")
            with patch("workbench.queue.Redis.from_url") as redis_connection, patch(
                "workbench.tasks.request_worksheet"
            ) as provider:
                self.assertEqual(self.client.post(reverse("create_worksheet", args=[material.pk])).status_code, 302)
            redis_connection.assert_not_called()
            provider.assert_not_called()
            task = GenerationTask.objects.get(worksheet__material=material)
            self.assertEqual(task.status, GenerationTask.Status.QUEUED)

            with patch("workbench.management.commands.run_staging_task.staging_guard", return_value=True), patch(
                "workbench.management.commands.run_staging_task.EXPECTED_SHA256",
                hashlib.sha256(raw).hexdigest(),
            ), patch("workbench.management.commands.run_staging_task.prompt_qwen_provider") as prompt, patch(
                "workbench.management.commands.run_staging_task.process_generation_task"
            ) as process:
                call_command("run_staging_task", str(task.pk), stdout=StringIO())
                with self.assertRaisesMessage(CommandError, "资料编号未核对一致"):
                    call_command("run_staging_task", str(task.pk), "--confirm-paid-call",
                                 "--confirm-material-id", str(material.pk + 1), stdout=StringIO())
                prompt.assert_not_called()
                process.assert_not_called()
                task.refresh_from_db()
                self.assertEqual(task.status, GenerationTask.Status.QUEUED)
                process.side_effect = lambda task_id: GenerationTask.objects.filter(pk=task_id).update(
                    status=GenerationTask.Status.DONE
                )
                with patch("workbench.management.commands.run_staging_task.sys.stdin.isatty", return_value=True), patch(
                    "workbench.management.commands.run_staging_task.configured", return_value=True
                ):
                    call_command("run_staging_task", str(task.pk), "--confirm-paid-call", "--prompt-qwen-key",
                                 "--confirm-material-id", str(material.pk), stdout=StringIO())
                prompt.assert_called_once()
                process.assert_called_once_with(task.pk)

    def test_staging_command_rejects_local_runtime_before_database_or_key(self):
        with patch("workbench.management.commands.run_staging_task.prompt_qwen_provider") as prompt:
            with self.assertRaisesMessage(CommandError, "只允许独立预发布"):
                call_command("run_staging_task", "1", "--confirm-paid-call", "--prompt-qwen-key",
                             "--confirm-material-id", "1", stdout=StringIO())
        prompt.assert_not_called()


def sample_docx():
    doc = Document()
    doc.add_paragraph("一元二次方程的基础练习。")
    output = BytesIO()
    doc.save(output)
    return output.getvalue()


def sample_pdf():
    """Small text PDF built locally without an external fixture or package."""
    stream = b"BT /F1 14 Tf 50 700 Td (Grade 9 algebra x^2-5x+6=0) Tj ET"
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    output = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, body in enumerate(objects, 1):
        offsets.append(len(output))
        output.extend(f"{number} 0 obj\n".encode() + body + b"\nendobj\n")
    xref_start = len(output)
    output.extend(f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode())
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode())
    output.extend(f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref_start}\n%%EOF".encode())
    return bytes(output)


SAMPLE_CONTENT = {
    "title": "九年级数学测试作业",
    "questions": [{
        "stem": "解方程 [[math:x^2-5x+6=0]]。",
        "answer": "[[math:x=2]] 或 [[math:x=3]]。",
        "source": "AI生成（参考上传资料）",
        "ai_generated": True,
    }],
}


class MathFormattingTests(SimpleTestCase):
    def test_unmarked_nested_fraction_and_malformed_math_marker_match_preview_and_word(self):
        # Fictional syntax fixture: no teaching document or model response is copied here.
        answer = (r"由 y_0=\frac{h_0-H}{d^2}，且 [[math]H_{\text{min}} \leq y_1]]，"
                  r"所以 \sqrt{\frac{d^2}{4}}=1。")
        preview = str(math_segments(answer))
        self.assertIn("math-fraction", preview)
        self.assertIn("<sub>0</sub>", preview)
        self.assertIn("<sub>min</sub>", preview)
        self.assertIn("≤", preview)
        for raw in (r"\frac", r"\sqrt", r"\text", "[[math]"):
            self.assertNotIn(raw, preview)

        content = {"title": "虚构公式排版测试", "questions": [{
            "stem": r"求 [[math:(x-2)^2]]。", "answer": answer,
            "source": "虚构样例", "ai_generated": True,
        }]}
        teacher = render_docx(content, "fictional.docx", teacher=True).getvalue()
        with ZipFile(BytesIO(teacher)) as archive:
            xml = archive.read("word/document.xml").decode("utf-8")
        self.assertEqual(xml.count("<m:f>"), 2)
        self.assertIn("<m:sSub>", xml)
        self.assertIn("<m:sSup>", xml)
        self.assertIn("<m:rad>", xml)
        self.assertNotIn("[[math]", xml)
        for raw in (r"\frac", r"\sqrt", r"\text"):
            self.assertNotIn(raw, xml)


class WorkflowTests(TransactionTestCase):
    def setUp(self):
        self.temp_dir = TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        media_override = override_settings(MEDIA_ROOT=self.temp_dir.name)
        media_override.enable()
        self.addCleanup(media_override.disable)
        user_model = get_user_model()
        self.alice = user_model.objects.create_user("alice", password="test-pass-123")
        self.bob = user_model.objects.create_user("bob", password="test-pass-456")
        self.client.force_login(self.alice)

    def upload(self):
        return self.client.post(reverse("upload_material"), {
            "file": SimpleUploadedFile("lesson.docx", sample_docx(),
                                       content_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        })

    def test_profile_is_private_and_homepage_uses_saved_settings(self):
        response = self.client.get(reverse("dashboard"))
        self.assertContains(response, "课表尚未录入")
        self.assertContains(response, "用我的资料出作业")
        self.assertContains(response, "workbench/site.css")
        self.assertContains(response, "workbench/site.js")
        self.assertEqual(self.client.post(reverse("edit_profile"), {
            "workbench_name": "华华的教学工作台",
            "subject": "数学",
            "textbook_edition": "人教版",
            "grade": "九年级",
        }).status_code, 302)
        self.assertEqual(TeacherProfile.objects.get(owner=self.alice).grade, "九年级")
        response = self.client.get(reverse("dashboard"))
        self.assertContains(response, "华华的教学工作台")
        self.assertContains(response, "人教版 · 九年级")
        self.client.force_login(self.bob)
        response = self.client.get(reverse("dashboard"))
        self.assertNotContains(response, "华华的教学工作台")
        self.assertNotContains(response, "人教版 · 九年级")
        self.assertEqual(TeacherProfile.objects.filter(owner=self.bob).count(), 0)

    def test_navigation_opens_distinct_private_work_areas(self):
        self.upload()
        material = Material.objects.get(owner=self.alice)
        worksheet = Worksheet.objects.create(owner=self.alice, material=material, title="虚构导航测试作业")
        home = self.client.get(reverse("dashboard"))
        self.assertContains(home, reverse("worksheet_start"))
        self.assertContains(home, reverse("worksheet_list"))
        self.assertContains(home, reverse("material_library"))
        self.assertNotContains(home, material.original_name)
        self.assertNotContains(home, 'href="/#materials"')
        self.assertNotContains(home, 'href="/#worksheets"')
        self.assertContains(self.client.get(reverse("worksheet_start")), "AI 出试卷")
        self.assertContains(self.client.get(reverse("material_library")), material.original_name)
        self.assertContains(self.client.get(reverse("worksheet_list")), worksheet.title)
        self.client.force_login(self.bob)
        for name in ("worksheet_start", "material_library", "worksheet_list"):
            self.assertNotContains(self.client.get(reverse(name)), material.original_name)
            self.assertNotContains(self.client.get(reverse(name)), worksheet.title)

    @override_settings(DEBUG=True)
    @local_sqlite_only
    def test_offline_formatting_sample_is_private_and_not_marked_as_ai(self):
        with patch("workbench.ai._open_provider_request") as remote_call:
            call_command("seed_preview_worksheet", self.alice.username)
            call_command("seed_preview_worksheet", self.alice.username)
        remote_call.assert_not_called()
        self.assertEqual(Worksheet.objects.filter(owner=self.alice).count(), 1)
        worksheet = Worksheet.objects.get(owner=self.alice)
        version = worksheet.versions.get()
        self.assertTrue(all(not item["ai_generated"] for item in version.content["questions"]))
        self.assertContains(self.client.get(reverse("worksheet_detail", args=[worksheet.pk])), "虚构离线排版样例")
        response = self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"]))
        with ZipFile(BytesIO(b"".join(response.streaming_content))) as archive:
            xml = archive.read("word/document.xml").decode("utf-8")
        response.close()
        self.assertIn("虚构离线排版样例（非 AI 生成）", xml)
        self.assertNotIn("AI 生成题，请教师核对", xml)
        self.client.force_login(self.bob)
        self.assertEqual(self.client.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code, 404)

    def test_upload_private_download_and_login(self):
        response = self.upload()
        self.assertEqual(response.status_code, 302)
        material = Material.objects.get(owner=self.alice)
        self.assertIn("一元二次方程", material.extracted_text)
        download = self.client.get(reverse("download_material", args=[material.pk]))
        self.assertEqual(download.status_code, 200)
        download.close()
        self.client.force_login(self.bob)
        self.assertEqual(self.client.get(reverse("download_material", args=[material.pk])).status_code, 404)
        self.assertEqual(self.client.post(reverse("create_worksheet", args=[material.pk])).status_code, 404)
        self.client.logout()
        self.assertEqual(self.client.get(reverse("download_material", args=[material.pk])).status_code, 302)

    def test_rejects_invalid_upload_without_saving(self):
        bad = SimpleUploadedFile("broken.docx", b"not a document")
        response = self.client.post(reverse("upload_material"), {"file": bad})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Material.objects.count(), 0)
        unsupported = SimpleUploadedFile("script.html", b"abc")
        response = self.client.post(reverse("upload_material"), {"file": unsupported})
        self.assertEqual(response.status_code, 400)

    def test_text_pdf_upload_and_size_limit(self):
        response = self.client.post(reverse("upload_material"), {
            "file": SimpleUploadedFile("algebra.pdf", sample_pdf(), content_type="application/pdf")
        })
        self.assertEqual(response.status_code, 302)
        material = Material.objects.get(owner=self.alice)
        self.assertIn("x^2-5x+6=0", material.extracted_text)
        oversized = SimpleUploadedFile("large.pdf", b"%PDF" + b"x" * MAX_UPLOAD_BYTES)
        response = self.client.post(reverse("upload_material"), {"file": oversized})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Material.objects.count(), 1)

    def test_overlong_document_is_saved_for_download_but_not_ai(self):
        document = Document()
        document.add_paragraph("x" * 15001)
        output = BytesIO()
        document.save(output)
        response = self.client.post(reverse("upload_material"), {
            "file": SimpleUploadedFile("too-long.docx", output.getvalue())
        })
        self.assertRedirects(response, reverse("material_library"), fetch_redirect_response=False)
        material = Material.objects.get()
        self.assertEqual(material.extracted_text, "")
        self.assertContains(self.client.get(reverse("material_library")), "15000 字上限")
        self.assertContains(self.client.get(reverse("material_library")), "仅原件下载")
        self.assertNotContains(self.client.get(reverse("worksheet_start")), material.original_name)

    def test_word_equation_text_is_not_lost_during_extraction(self):
        raw = render_docx(SAMPLE_CONTENT, "synthetic.docx").getvalue()
        uploaded = SimpleUploadedFile("synthetic.docx", raw)
        self.assertIn("x^2-5x+6=0", extract_text(uploaded))

    def test_simple_powers_have_editable_word_structure_and_safe_preview(self):
        content = {
            "title": "虚构公式检查",
            "questions": [{
                "stem": "计算 [[math:(x-2)^2+x^{10}]]。",
                "answer": "结果待教师核对。",
                "source": "虚构排版样例",
                "ai_generated": False,
            }],
        }
        raw = render_docx(content, "synthetic.docx").getvalue()
        with ZipFile(BytesIO(raw)) as archive:
            xml = archive.read("word/document.xml").decode("utf-8")
        self.assertEqual(xml.count("<m:sSup>"), 2)
        self.assertIn("(x-2)^2+x^10", extract_text(SimpleUploadedFile("synthetic.docx", raw)))
        preview = str(math_segments("[[math:(x-2)^2+x^{10}+<script>]]"))
        self.assertIn("<sup>2</sup>", preview)
        self.assertIn("<sup>10</sup>", preview)
        self.assertNotIn("<script>", preview)

    def test_provider_dollar_math_is_editable_and_matches_preview(self):
        content = {
            "title": "虚构练习",
            "questions": [{
                "stem": "解方程 $x^2-5x+6=0$。",
                "answer": "代入 $2 \\times 3 + 1 = 7$。",
                "source": "AI生成（原题出处未核实）", "ai_generated": True,
            }],
        }
        preview = str(math_segments(content["questions"][0]["stem"]))
        self.assertIn("<sup>2</sup>", preview)
        self.assertNotIn("$", preview)
        answer_preview = str(math_segments(content["questions"][0]["answer"]))
        self.assertIn("×", answer_preview)
        student = render_docx(content, "fictional.docx").getvalue()
        teacher = render_docx(content, "fictional.docx", teacher=True).getvalue()
        with ZipFile(BytesIO(student)) as archive:
            student_xml = archive.read("word/document.xml")
        with ZipFile(BytesIO(teacher)) as archive:
            teacher_xml = archive.read("word/document.xml")
        self.assertIn(b"<m:sSup>", student_xml)
        self.assertNotIn(b"\\times", teacher_xml)
        self.assertIn("×".encode(), teacher_xml)
        self.assertNotIn("参考答案：".encode(), student_xml)
        self.assertIn("参考答案：".encode(), teacher_xml)

    def test_simple_square_roots_render_as_editable_word_math(self):
        content = {
            "title": "虚构根式练习",
            "questions": [{
                "stem": r"计算 [[math: \sqrt{16} + \sqrt{9}]]。",
                "answer": r"[[math: \sqrt{16} = 4]]，所以结果为 $4 + 3 = 7$。",
                "source": "虚构排版样例", "ai_generated": False,
            }],
        }
        preview = str(math_segments(content["questions"][0]["stem"]))
        self.assertIn('√<span class="math-radicand">16</span>', preview)
        self.assertNotIn(r"\sqrt", preview)
        student = render_docx(content, "fictional.docx").getvalue()
        teacher = render_docx(content, "fictional.docx", teacher=True).getvalue()
        with ZipFile(BytesIO(student)) as archive:
            student_xml = archive.read("word/document.xml").decode("utf-8")
        with ZipFile(BytesIO(teacher)) as archive:
            teacher_xml = archive.read("word/document.xml").decode("utf-8")
        self.assertEqual(student_xml.count("<m:rad>"), 2)
        self.assertEqual(teacher_xml.count("<m:rad>"), 3)
        self.assertNotIn(r"\sqrt", student_xml + teacher_xml)
        self.assertNotIn("参考答案：", student_xml)
        self.assertIn("参考答案：", teacher_xml)

    def test_literal_model_line_breaks_match_preview_and_teacher_word(self):
        content = {
            "title": "虚构分步解答",
            "questions": [{
                "stem": r"解方程 $x^2-5x+6=0$。",
                "answer": r"第一步：因式分解。\n第二步：分别求解 $x \neq 0$。<script>",
                "source": "AI生成（原题出处未核实）", "ai_generated": True,
            }],
        }
        preview = str(math_segments(content["questions"][0]["answer"]))
        self.assertIn("因式分解。<br>第二步", preview)
        self.assertNotIn(r"\n第二步", preview)
        self.assertIn("≠", preview)
        self.assertNotIn("<script>", preview)
        teacher = render_docx(content, "fictional.docx", teacher=True).getvalue()
        with ZipFile(BytesIO(teacher)) as archive:
            xml = archive.read("word/document.xml").decode("utf-8")
        self.assertIn("因式分解。", xml)
        self.assertIn("第二步：", xml)
        self.assertIn("<w:br", xml)
        self.assertNotIn(r"\n第二步", xml)
        self.assertIn("<m:sSup>", xml)

    def test_preview_and_both_word_variants_use_the_same_saved_questions(self):
        self.upload()
        worksheet = Worksheet.objects.create(owner=self.alice, material=Material.objects.get())
        content = {
            "title": "虚构一致性练习",
            "questions": [
                {"stem": "第一题：求和。", "answer": "第一题答案：5。", "source": "虚构来源甲", "ai_generated": False},
                {"stem": "第二题：解方程。", "answer": "第二题答案：2。", "source": "虚构来源乙", "ai_generated": False},
            ],
        }
        WorksheetVersion.objects.create(worksheet=worksheet, number=1, content=content)
        preview = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        student = self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, "student"]))
        teacher = self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"]))

        def word_xml(response):
            with ZipFile(BytesIO(b"".join(response.streaming_content))) as archive:
                xml = archive.read("word/document.xml").decode("utf-8")
            response.close()
            return xml

        student_xml, teacher_xml = word_xml(student), word_xml(teacher)
        for item in content["questions"]:
            for label in (item["stem"], item["source"]):
                self.assertContains(preview, label)
                self.assertIn(label, student_xml)
                self.assertIn(label, teacher_xml)
            self.assertContains(preview, item["answer"])
            self.assertNotIn(item["answer"], student_xml)
            self.assertIn(item["answer"], teacher_xml)

    def test_ai_disabled_does_not_queue_or_create_worksheet(self):
        self.upload()
        material = Material.objects.get()
        self.assertContains(self.client.get(reverse("dashboard")), "真实 AI 服务未配置或未启用")
        with patch("workbench.views.enqueue_task") as enqueue:
            response = self.client.post(reverse("create_worksheet", args=[material.pk]))
        self.assertEqual(response.status_code, 302)
        self.assertEqual(Worksheet.objects.count(), 0)
        enqueue.assert_not_called()

    @override_settings(AI_ENABLED=True, AI_PROVIDER="openai-compatible", AI_BASE_URL="https://example.invalid/v1", AI_MODEL="fake", AI_API_KEY="fake")
    def test_generation_revision_export_and_isolation(self):
        TeacherProfile.objects.create(owner=self.alice, subject="数学", grade="九年级", textbook_edition="人教版")
        self.upload()
        material = Material.objects.get()
        with patch("workbench.views.enqueue_task") as enqueue:
            response = self.client.post(reverse("create_worksheet", args=[material.pk]))
        self.assertEqual(response.status_code, 302)
        enqueue.assert_called_once()
        worksheet = Worksheet.objects.get()
        task = worksheet.tasks.get()
        self.assertEqual(task.status, GenerationTask.Status.QUEUED)
        with patch("workbench.tasks.request_worksheet", return_value=SAMPLE_CONTENT) as fake_ai:
            process_generation_task(task.pk)
        fake_ai.assert_called_once()
        self.assertEqual(fake_ai.call_args.args[3], {
            "subject": "数学", "grade": "九年级", "textbook_edition": "人教版",
        })
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.DONE)
        self.assertEqual(worksheet.versions.count(), 1)
        preview = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        self.assertContains(preview, "x<sup>2</sup>-5x+6=0", html=True)
        for variant in ("student", "teacher"):
            url = reverse("export_worksheet", args=[worksheet.pk, 1, variant])
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200)
            body = b"".join(response.streaming_content)
            with ZipFile(BytesIO(body)) as archive:
                xml = archive.read("word/document.xml").decode("utf-8")
            response.close()
            self.assertIn("m:oMath", xml)
            self.assertIn("m:sSup", xml)
            self.assertIn("-5x+6=0", xml)
            if variant == "student":
                self.assertNotIn("参考答案", xml)
                self.assertNotIn("x=2", xml)
            else:
                self.assertIn("参考答案", xml)
                self.assertIn("x=2", xml)
        with patch("workbench.views.enqueue_task"):
            response = self.client.post(reverse("revise_worksheet", args=[worksheet.pk]), {"instruction": "再加入一步解法"})
        self.assertEqual(response.status_code, 302)
        revision = worksheet.tasks.filter(kind=GenerationTask.Kind.REVISE).get()
        queued_page = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        self.assertContains(queued_page, "已有任务在排队或处理中")
        self.assertNotContains(queued_page, "提交修改要求")
        revised_content = {
            "title": "修改后的虚构作业",
            "questions": [{
                "stem": "计算 4+5。", "answer": "9。",
                "source": "AI生成（原题出处未核实）", "ai_generated": True,
            }],
        }
        with patch("workbench.tasks.request_worksheet", return_value=revised_content) as fake_revision:
            process_generation_task(revision.pk)
        self.assertEqual(fake_revision.call_args.args[1], SAMPLE_CONTENT)
        self.assertEqual(fake_revision.call_args.args[2], "再加入一步解法")
        self.assertEqual(worksheet.versions.count(), 2)
        self.assertEqual(worksheet.versions.first().change_request, "再加入一步解法")
        self.assertEqual(worksheet.versions.get(number=1).content, SAMPLE_CONTENT)
        self.assertEqual(worksheet.versions.get(number=2).content, revised_content)
        latest_page = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        old_page = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]) + "?version=1")
        self.assertContains(latest_page, "修改后的虚构作业")
        self.assertContains(latest_page, "计算 4+5")
        self.assertContains(latest_page, "查看本版修改要求")
        self.assertNotContains(latest_page, "x<sup>2</sup>-5x+6=0", html=True)
        self.assertContains(old_page, "九年级数学测试作业")
        self.assertContains(old_page, "x<sup>2</sup>-5x+6=0", html=True)
        self.assertNotContains(old_page, "计算 4+5")
        self.assertNotContains(old_page, "查看本版修改要求")
        for version_number, stem, answer in ((1, "-5x+6=0", "x=2"), (2, "计算 4+5", "9。")):
            for variant in ("student", "teacher"):
                response = self.client.get(reverse("export_worksheet", args=[worksheet.pk, version_number, variant]))
                self.assertEqual(response.status_code, 200)
                with ZipFile(BytesIO(b"".join(response.streaming_content))) as archive:
                    xml = archive.read("word/document.xml").decode("utf-8")
                response.close()
                self.assertIn(stem, xml)
                if variant == "student":
                    self.assertNotIn(answer, xml)
                else:
                    self.assertIn(answer, xml)
        self.client.force_login(self.bob)
        self.assertEqual(self.client.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code, 404)
        self.assertEqual(self.client.get(reverse("export_worksheet", args=[worksheet.pk, 1, "teacher"])).status_code, 404)
        self.assertEqual(self.client.get(reverse("export_worksheet", args=[worksheet.pk, 2, "teacher"])).status_code, 404)
        self.assertEqual(self.client.post(reverse("revise_worksheet", args=[worksheet.pk]), {"instruction": "偷看"}).status_code, 404)

    @override_settings(AI_ENABLED=True, AI_PROVIDER="openai-compatible", AI_BASE_URL="https://example.invalid/v1", AI_MODEL="fake", AI_API_KEY="fake")
    def test_ai_prompt_uses_teacher_scope_without_forcing_math(self):
        response_body = json.dumps({"choices": [{"message": {"content": json.dumps(SAMPLE_CONTENT)}}]}).encode()

        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def read(self, _size):
                return response_body

        with patch("workbench.ai._open_provider_request", return_value=FakeResponse()) as remote_call:
            result = request_worksheet("虚构历史资料", teaching_context={
                "subject": "历史", "grade": "七年级", "textbook_edition": "统编版",
            })
        self.assertEqual(result["questions"][0]["source"], "AI生成（原题出处未核实）")
        sent = json.loads(remote_call.call_args.args[0].data)
        system = sent["messages"][0]["content"]
        self.assertIn("任教学科：历史", system)
        self.assertIn("年级：七年级", system)
        self.assertIn("教材版本：统编版", system)
        self.assertNotIn("九年级数学教师", system)
        long_source = "S" * 12000 + "ENDMARKER"
        with patch("workbench.ai._open_provider_request", return_value=FakeResponse()) as remote_call:
            request_worksheet(long_source, previous=SAMPLE_CONTENT, instruction="调整顺序", teaching_context={"subject": "历史"})
        revised_input = json.loads(remote_call.call_args.args[0].data)["messages"][1]["content"]
        self.assertIn("ENDMARKER", revised_input)

    def test_cancelled_queue_task_never_calls_ai(self):
        self.upload()
        material = Material.objects.get()
        worksheet = Worksheet.objects.create(owner=self.alice, material=material)
        task = GenerationTask.objects.create(owner=self.alice, worksheet=worksheet, kind=GenerationTask.Kind.CREATE)
        response = self.client.post(reverse("cancel_task", args=[task.pk]))
        self.assertEqual(response.status_code, 302)
        with patch("workbench.tasks.request_worksheet") as fake_ai:
            process_generation_task(task.pk)
        fake_ai.assert_not_called()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.CANCELLED)

    def test_owner_mismatch_never_calls_ai(self):
        self.upload()
        material = Material.objects.get()
        worksheet = Worksheet.objects.create(owner=self.bob, material=material)
        task = GenerationTask.objects.create(owner=self.bob, worksheet=worksheet, kind=GenerationTask.Kind.CREATE)
        with patch("workbench.tasks.request_worksheet") as fake_ai:
            process_generation_task(task.pk)
        fake_ai.assert_not_called()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.FAILED)

    def test_worker_error_becomes_failed_task_without_leaking_details(self):
        self.upload()
        material = Material.objects.get()
        worksheet = Worksheet.objects.create(owner=self.alice, material=material)
        task = GenerationTask.objects.create(owner=self.alice, worksheet=worksheet, kind=GenerationTask.Kind.CREATE)
        with patch("workbench.tasks.request_worksheet", side_effect=RuntimeError("secret-value")):
            process_generation_task(task.pk)
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.FAILED)
        self.assertNotIn("secret-value", task.error_message)
