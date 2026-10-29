"""Member configuration selection and provider adapter, with local fake I/O only."""

from datetime import timedelta
from io import BytesIO
import json
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from .ai import AIResponseError, AIUnavailable, request_member_worksheet
from .models import (CallAllowance, CallAttempt, GenerationTask, Material,
                     ModelCredential, Worksheet, WorksheetVersion)
from .queue import enqueue_task
from .tasks import process_generation_task, process_member_generation_task


@override_settings(DEBUG=True, AI_LOCAL_QUEUE=True, AI_MEMBER_TASKS_ENABLED=True)
class MemberPageFlowTests(TestCase):
    def setUp(self):
        users = get_user_model().objects
        self.alice = users.create_user("flow_alice", password="Fictional-test-123")
        self.bob = users.create_user("flow_bob", password="Fictional-test-123")
        self.client.force_login(self.alice)
        self.allowance = CallAllowance.objects.create(
            owner=self.alice, max_calls=2, valid_until=timezone.now() + timedelta(days=1),
        )
        self.credential = ModelCredential.objects.create(
            owner=self.alice, label="本人虚构配置", provider="qwen",
            api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            model_name="qwen-flash", key_ciphertext=b"fictional-encrypted-only",
            key_nonce=b"fictional-12", key_version=1,
        )
        self.other_credential = ModelCredential.objects.create(
            owner=self.bob, label="他人私有配置", provider="qwen",
            api_base_url=self.credential.api_base_url, model_name="qwen-flash",
            key_ciphertext=b"fictional-encrypted-only", key_nonce=b"fictional-12", key_version=1,
        )
        self.material = Material.objects.create(
            owner=self.alice, file="materials/fictional-flow.docx", original_name="虚构资料.docx",
            size_bytes=20, extracted_text="虚构资料文字",
        )

    def test_create_requires_own_selected_configuration_and_only_queues(self):
        page = self.client.get(reverse("worksheet_start"))
        self.assertContains(page, "本人虚构配置")
        self.assertNotContains(page, "他人私有配置")
        url = reverse("create_worksheet", args=[self.material.pk])
        denied = self.client.post(url, {"credential": str(self.other_credential.pk)})
        self.assertEqual(denied.status_code, 302)
        self.assertFalse(GenerationTask.objects.exists())
        with patch("workbench.queue.Queue") as queue:
            accepted = self.client.post(url, {"credential": str(self.credential.pk)})
        self.assertEqual(accepted.status_code, 302)
        task = GenerationTask.objects.get()
        self.assertTrue(task.member_mode)
        self.assertEqual(task.member_credential_id, self.credential.pk)
        self.assertEqual(task.status, GenerationTask.Status.QUEUED)
        self.assertFalse(CallAttempt.objects.exists())
        if settings.DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3":
            queue.assert_not_called()
        else:
            queue.return_value.enqueue.assert_called_once()
            self.assertEqual(queue.return_value.enqueue.call_args.args[0],
                             "workbench.tasks.process_member_generation_task")

    def test_revision_requires_own_config_and_keeps_old_version(self):
        worksheet = Worksheet.objects.create(owner=self.alice, material=self.material)
        WorksheetVersion.objects.create(worksheet=worksheet, number=1, content={
            "title": "旧版", "questions": [{"stem": "旧题", "answer": "旧答"}],
        })
        page = self.client.get(reverse("worksheet_detail", args=[worksheet.pk]))
        self.assertContains(page, "本人虚构配置")
        url = reverse("revise_worksheet", args=[worksheet.pk])
        denied = self.client.post(url, {"instruction": "改简单", "credential": str(self.other_credential.pk)})
        self.assertEqual(denied.status_code, 302)
        self.assertFalse(GenerationTask.objects.exists())
        with patch("workbench.queue.Queue") as queue:
            accepted = self.client.post(url, {"instruction": "改简单", "credential": str(self.credential.pk)})
        self.assertEqual(accepted.status_code, 302)
        task = GenerationTask.objects.get()
        self.assertTrue(task.member_mode)
        self.assertEqual(task.member_credential_id, self.credential.pk)
        self.assertEqual(task.status, GenerationTask.Status.QUEUED)
        if settings.DATABASES["default"]["ENGINE"] == "django.db.backends.sqlite3":
            queue.assert_not_called()
        else:
            queue.return_value.enqueue.assert_called_once()
            self.assertEqual(queue.return_value.enqueue.call_args.args[0],
                             "workbench.tasks.process_member_generation_task")
        self.assertEqual(worksheet.versions.count(), 1)

    def test_expired_allowance_disables_submission_without_creating_task(self):
        self.allowance.valid_until = timezone.now() - timedelta(seconds=1)
        self.allowance.save(update_fields=["valid_until"])
        page = self.client.get(reverse("worksheet_start"))
        self.assertNotContains(page, "name=\"credential\"")
        response = self.client.post(reverse("create_worksheet", args=[self.material.pk]),
                                    {"credential": str(self.credential.pk)})
        self.assertEqual(response.status_code, 302)
        self.assertFalse(GenerationTask.objects.exists())

    def test_zero_allowance_disables_selection_and_forged_submission(self):
        self.allowance.max_calls = 0
        self.allowance.save(update_fields=["max_calls"])
        page = self.client.get(reverse("worksheet_start"))
        self.assertNotContains(page, 'name="credential"')
        response = self.client.post(reverse("create_worksheet", args=[self.material.pk]),
                                    {"credential": str(self.credential.pk)})
        self.assertEqual(response.status_code, 302)
        self.assertFalse(GenerationTask.objects.exists())
        self.assertFalse(CallAttempt.objects.exists())

    @override_settings(AI_LOCAL_QUEUE=False, AI_STAGING_MANUAL_QUEUE=False)
    def test_queue_routes_member_mode_to_guarded_worker(self):
        worksheet = Worksheet.objects.create(owner=self.alice, material=self.material)
        task = GenerationTask.objects.create(
            owner=self.alice, worksheet=worksheet, kind=GenerationTask.Kind.CREATE,
            member_mode=True, member_credential=self.credential,
        )
        with patch("workbench.queue.Redis.from_url"), patch("workbench.queue.Queue") as queue:
            enqueue_task(task.pk)
        self.assertEqual(queue.return_value.enqueue.call_args.args[0],
                         "workbench.tasks.process_member_generation_task")

    def test_global_worker_rejects_legacy_task_when_member_mode_on(self):
        worksheet = Worksheet.objects.create(owner=self.alice, material=self.material)
        task = GenerationTask.objects.create(owner=self.alice, worksheet=worksheet,
                                             kind=GenerationTask.Kind.CREATE)
        with patch("workbench.tasks.request_worksheet") as sender:
            process_generation_task(task.pk)
        sender.assert_not_called()
        task.refresh_from_db()
        self.assertEqual(task.status, GenerationTask.Status.FAILED)

    @override_settings(AI_MEMBER_TASKS_ENABLED=False)
    def test_member_worker_default_off(self):
        with patch("workbench.tasks.request_member_worksheet") as sender:
            self.assertFalse(process_member_generation_task(12345))
        sender.assert_not_called()


@override_settings(AI_MEMBER_TASKS_ENABLED=True)
class MemberProviderAdapterTests(TestCase):
    def test_qwen_response_records_only_complete_usage(self):
        credential = ModelCredential(provider="qwen", model_name="qwen-flash",
                                     api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1")
        body = {"choices": [{"message": {"content": json.dumps({
            "title": "虚构作业", "questions": [{"stem": "题目", "answer": "答案"}],
        })}}], "usage": {"prompt_tokens": 11, "completion_tokens": 7, "total_tokens": 18}}
        with patch("workbench.ai._open_provider_request", return_value=BytesIO(json.dumps(body).encode())) as opener:
            content, usage = request_member_worksheet("虚构参考资料", None, "", None,
                                                      credential, "sk-fictional-member-only")
        self.assertEqual(content["title"], "虚构作业")
        self.assertEqual(usage, (11, 7))
        request = opener.call_args.args[0]
        self.assertEqual(request.full_url,
                         credential.api_base_url + "/chat/completions")
        payload = json.loads(request.data)
        self.assertEqual(payload["model"], "qwen-flash")
        self.assertFalse(payload["enable_thinking"])
        self.assertEqual(payload["response_format"], {"type": "json_object"})
        self.assertEqual(payload["max_tokens"], 3000)

    def test_qwen_length_finish_reason_reports_incomplete_without_exposing_content(self):
        credential = ModelCredential(provider="qwen", model_name="qwen-flash",
                                     api_base_url="https://dashscope.aliyuncs.com/compatible-mode/v1")
        body = {"choices": [{"finish_reason": "length", "message": {"content": "private content"}}]}
        with patch("workbench.ai._open_provider_request", return_value=BytesIO(json.dumps(body).encode())):
            with self.assertRaisesMessage(AIResponseError, "模型输出达到长度上限，草稿未保存。"):
                request_member_worksheet("虚构", None, "", None, credential, "sk-fictional-member-only")

    def test_missing_or_mismatched_usage_stays_unknown(self):
        credential = ModelCredential(provider="qwen", model_name="qwen-flash",
                                     api_base_url="https://dashscope.aliyuncs.com/compatible-mode/v1")
        body = {"choices": [{"message": {"content": json.dumps({
            "title": "虚构", "questions": [{"stem": "题", "answer": "答"}],
        })}}], "usage": {"prompt_tokens": 11, "completion_tokens": 7, "total_tokens": 100}}
        with patch("workbench.ai._open_provider_request", return_value=BytesIO(json.dumps(body).encode())):
            _, usage = request_member_worksheet("虚构", None, "", None, credential,
                                                "sk-fictional-member-only")
        self.assertIsNone(usage)

    def test_invalid_endpoint_rejected_before_any_network(self):
        credential = ModelCredential(provider="qwen", model_name="qwen-flash",
                                     api_base_url="https://example.invalid/compatible-mode/v1")
        with patch("workbench.ai._open_provider_request") as opener:
            with self.assertRaises(AIUnavailable):
                request_member_worksheet("虚构", None, "", None, credential,
                                         "sk-fictional-member-only")
        opener.assert_not_called()

    @override_settings(AI_MEMBER_TASKS_ENABLED=False)
    def test_adapter_default_off_even_with_a_secret(self):
        credential = ModelCredential(provider="qwen", model_name="qwen-flash",
                                     api_base_url="https://dashscope.aliyuncs.com/compatible-mode/v1")
        with patch("workbench.ai._open_provider_request") as opener:
            with self.assertRaises(AIUnavailable):
                request_member_worksheet("虚构", None, "", None, credential,
                                         "sk-fictional-member-only")
        opener.assert_not_called()
