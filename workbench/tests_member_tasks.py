"""Offline stage-2C lifecycle: no network sender is registered or invoked."""

import base64
from datetime import timedelta
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone

from .credential_vault import seal_key
from .member_tasks import process_member_task_offline
from .models import (CallAllowance, CallAttempt, GenerationTask, Material,
                     ModelCredential, Worksheet, WorksheetVersion)
from .tasks import process_generation_task
from .ai import AIResponseError, _http_error_message


class OfflineMemberTaskTests(TestCase):
    def setUp(self):
        temporary = TemporaryDirectory(prefix="workbench-fictional-member-keyring-")
        self.addCleanup(temporary.cleanup)
        keyfile = Path(temporary.name) / "v1.key"
        keyfile.write_bytes(base64.b64encode(os.urandom(32)) + b"\n")
        if os.name == "posix":
            Path(temporary.name).chmod(0o700)
            keyfile.chmod(0o600)
        settings_override = override_settings(MODEL_KEYRING_DIR=temporary.name,
                                              MODEL_ACTIVE_KEY_VERSION=1)
        settings_override.enable()
        self.addCleanup(settings_override.disable)
        self.alice = get_user_model().objects.create_user("member_task_alice", password="Fictional-test-123")
        self.allowance = CallAllowance.objects.create(
            owner=self.alice, max_calls=1, valid_until=timezone.now() + timedelta(days=1),
        )
        self.credential = ModelCredential(
            owner=self.alice, label="虚构", provider=ModelCredential.Provider.QWEN,
            api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            model_name="qwen-flash",
        )
        seal_key(self.credential, "sk-fictional-member-task-only")
        self.credential.save()
        material = Material.objects.create(
            owner=self.alice, file="materials/member-fictional.docx",
            original_name="虚构资料.docx", size_bytes=10, extracted_text="虚构教学文字",
        )
        self.worksheet = Worksheet.objects.create(owner=self.alice, material=material)
        self.task = GenerationTask.objects.create(
            owner=self.alice, worksheet=self.worksheet, kind=GenerationTask.Kind.CREATE,
            member_mode=True, member_credential=self.credential,
        )

    def test_success_is_single_call_and_saves_only_reliable_usage(self):
        sender = Mock(return_value=(
            {"title": "虚构作业", "questions": [{"stem": "一加一？", "answer": "二"}]},
            (12, 8),
        ))
        self.assertTrue(process_member_task_offline(self.task.pk, provider_call=sender))
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        sender.assert_called_once()
        self.assertEqual(sender.call_args.args[0], "虚构教学文字")
        self.assertEqual(sender.call_args.args[-1], "sk-fictional-member-task-only")
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        attempt = CallAttempt.objects.get(task=self.task)
        self.assertEqual(self.task.status, GenerationTask.Status.DONE)
        self.assertEqual(self.worksheet.versions.count(), 1)
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 1))
        self.assertEqual((attempt.input_tokens, attempt.output_tokens), (12, 8))

    def test_sender_failure_counts_once_and_does_not_leak_secret(self):
        sender = Mock(side_effect=RuntimeError("sk-fictional-member-task-only leaked by provider"))
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        attempt = CallAttempt.objects.get(task=self.task)
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertNotIn("sk-fictional", self.task.error_message)
        self.assertEqual(attempt.status, CallAttempt.Status.UNKNOWN)
        self.assertEqual(self.allowance.used_calls, 1)
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        sender.assert_called_once()

    def test_sanitized_provider_error_identifies_http_status_without_refund(self):
        sender = Mock(side_effect=AIResponseError(_http_error_message(401)))
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        self.assertIn("HTTP 401", self.task.error_message)
        self.assertEqual(self.allowance.used_calls, 1)
        self.assertEqual(CallAttempt.objects.get(task=self.task).status, CallAttempt.Status.UNKNOWN)

    def test_untrusted_provider_error_text_never_reaches_task(self):
        sender = Mock(side_effect=AIResponseError("sk-fictional-member-task-only"))
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        self.task.refresh_from_db()
        self.assertNotIn("sk-fictional", self.task.error_message)

    def test_bad_key_releases_before_sender(self):
        self.credential.key_ciphertext = b"broken"
        self.credential.save(update_fields=["key_ciphertext"])
        sender = Mock()
        self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        sender.assert_not_called()
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertEqual(self.allowance.reserved_calls, 0)
        self.assertEqual(self.allowance.used_calls, 0)
        self.assertEqual(CallAttempt.objects.get(task=self.task).status, CallAttempt.Status.RELEASED)

    def test_key_replaced_after_decryption_cancels_before_sender(self):
        sender = Mock()
        from .credential_vault import unseal_key_for_owner
        def replace_then_return(credential, owner_id):
            old_secret = unseal_key_for_owner(credential, owner_id)
            current = ModelCredential.objects.get(pk=credential.pk)
            seal_key(current, "sk-fictional-replacement-only")
            current.save(update_fields=["key_ciphertext", "key_nonce", "key_version"])
            return old_secret
        with patch("workbench.member_tasks.unseal_key_for_owner", side_effect=replace_then_return):
            self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        sender.assert_not_called()
        self.allowance.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))

    def test_old_global_worker_rejects_member_task_without_network(self):
        with patch("workbench.tasks.request_worksheet") as old_sender:
            process_generation_task(self.task.pk)
        old_sender.assert_not_called()
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertIn("额度闸门", self.task.error_message)

    def test_member_runner_requires_explicit_sender(self):
        with self.assertRaises(TypeError):
            process_member_task_offline(self.task.pk)
        self.assertFalse(CallAttempt.objects.exists())

    def test_missing_allowance_fails_before_secret_or_sender(self):
        self.allowance.delete()
        sender = Mock()
        with patch("workbench.member_tasks.unseal_key_for_owner") as key_loader:
            self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        key_loader.assert_not_called()
        sender.assert_not_called()
        self.task.refresh_from_db()
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertFalse(CallAttempt.objects.exists())

    def test_zero_allowance_fails_before_secret_or_sender(self):
        self.allowance.max_calls = 0
        self.allowance.save(update_fields=["max_calls"])
        sender = Mock()
        with patch("workbench.member_tasks.unseal_key_for_owner") as key_loader:
            self.assertFalse(process_member_task_offline(self.task.pk, provider_call=sender))
        key_loader.assert_not_called()
        sender.assert_not_called()
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))
        self.assertFalse(CallAttempt.objects.exists())

    def test_revision_passes_previous_version_and_keeps_it(self):
        old_content = {"title": "旧版", "questions": [{"stem": "旧题", "answer": "旧答"}]}
        WorksheetVersion.objects.create(worksheet=self.worksheet, number=1, content=old_content)
        self.task.kind = GenerationTask.Kind.REVISE
        self.task.instruction = "把题目改简单"
        self.task.save(update_fields=["kind", "instruction"])
        sender = Mock(return_value=(
            {"title": "新版", "questions": [{"stem": "新题", "answer": "新答"}]}, None,
        ))
        self.assertTrue(process_member_task_offline(self.task.pk, provider_call=sender))
        self.assertEqual(sender.call_args.args[1], old_content)
        self.assertEqual(sender.call_args.args[2], "把题目改简单")
        self.assertEqual(list(self.worksheet.versions.values_list("number", flat=True)), [2, 1])
        attempt = CallAttempt.objects.get(task=self.task)
        self.assertIsNone(attempt.input_tokens)
        self.assertIsNone(attempt.output_tokens)
