"""Fictional recovery checks; no API key or provider request is involved."""

from datetime import timedelta
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase
from django.utils import timezone

from .call_gate import credential_fingerprint, mark_task_sent, reserve_task_call
from .models import CallAllowance, CallAttempt, GenerationTask, Material, ModelCredential, Worksheet


class ReconcileMemberCallsTests(TestCase):
    def setUp(self):
        self.owner = get_user_model().objects.create_user("fictional_reconcile")
        self.allowance = CallAllowance.objects.create(
            owner=self.owner, max_calls=2, valid_until=timezone.now() + timedelta(days=1),
        )
        self.credential = ModelCredential.objects.create(
            owner=self.owner, label="虚构配置", provider=ModelCredential.Provider.QWEN,
            api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            model_name="qwen-flash", key_ciphertext=b"fictional-ciphertext-only",
            key_nonce=b"fictional-12", key_version=1,
        )
        material = Material.objects.create(
            owner=self.owner, file="materials/fictional.docx", original_name="虚构资料.docx",
            size_bytes=10, extracted_text="虚构资料",
        )
        self.worksheet = Worksheet.objects.create(owner=self.owner, material=material)

    def make_task(self):
        return GenerationTask.objects.create(
            owner=self.owner, worksheet=self.worksheet, kind=GenerationTask.Kind.CREATE,
            member_mode=True, member_credential=self.credential,
        )

    def test_preview_is_read_only_and_apply_never_refunds_sent_call(self):
        unsent = self.make_task()
        sent = self.make_task()
        reserve_task_call(unsent.pk, self.credential.pk)
        reserve_task_call(sent.pk, self.credential.pk)
        mark_task_sent(sent.pk, expected_fingerprint=credential_fingerprint(self.credential))
        old = timezone.now() - timedelta(minutes=11)
        CallAttempt.objects.filter(task=unsent).update(reserved_at=old)
        CallAttempt.objects.filter(task=sent).update(sent_at=old)

        output = StringIO()
        call_command("reconcile_member_calls", "--min-age-minutes=10", stdout=output)
        self.assertIn("PREVIEW unsent=1 sent=1", output.getvalue())
        self.allowance.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (1, 1))

        output = StringIO()
        call_command("reconcile_member_calls", "--apply", "--min-age-minutes=10", stdout=output)
        self.assertIn("APPLIED released_unsent=1 closed_sent=1 skipped=0", output.getvalue())
        self.allowance.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 1))
        self.assertEqual(CallAttempt.objects.get(task=unsent).status, CallAttempt.Status.RELEASED)
        self.assertEqual(CallAttempt.objects.get(task=sent).status, CallAttempt.Status.UNKNOWN)
        self.assertEqual(GenerationTask.objects.get(pk=unsent.pk).status, GenerationTask.Status.FAILED)
        self.assertEqual(GenerationTask.objects.get(pk=sent.pk).status, GenerationTask.Status.FAILED)
        output = StringIO()
        call_command("reconcile_member_calls", "--apply", "--min-age-minutes=10", stdout=output)
        self.assertIn("released_unsent=0 closed_sent=0", output.getvalue())

    def test_young_attempt_and_short_threshold_are_not_processed(self):
        task = self.make_task()
        reserve_task_call(task.pk, self.credential.pk)
        with self.assertRaises(CommandError):
            call_command("reconcile_member_calls", "--apply", "--min-age-minutes=9")
        output = StringIO()
        call_command("reconcile_member_calls", "--apply", stdout=output)
        self.assertIn("released_unsent=0 closed_sent=0", output.getvalue())
        self.assertEqual(CallAttempt.objects.get(task=task).status, CallAttempt.Status.RESERVED)
