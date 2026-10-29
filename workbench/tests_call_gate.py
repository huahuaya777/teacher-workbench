"""Fictional call-count checks. No provider request or plaintext key is used."""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from .call_gate import (CallGateDenied, cancel_queued_task, finish_attempt,
                        credential_fingerprint, mark_task_sent, reclaim_stale_reservation,
                        reconcile_stale_post_send_task,
                        reserve_task_call)
from .models import (CallAllowance, CallAttempt, GenerationTask, Material,
                     MemberAccess, ModelCredential, Worksheet)


class CallGateTests(TestCase):
    def setUp(self):
        users = get_user_model().objects
        self.alice = users.create_user("quota_alice", password="Fictional-test-123")
        self.bob = users.create_user("quota_bob", password="Fictional-test-123")
        self.allowance = CallAllowance.objects.create(
            owner=self.alice, max_calls=1, valid_until=timezone.now() + timedelta(days=1),
        )
        self.credential = ModelCredential.objects.create(
            owner=self.alice, label="虚构百炼", provider=ModelCredential.Provider.QWEN,
            api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            model_name="qwen-flash", key_ciphertext=b"fictional-ciphertext-only",
            key_nonce=b"fictional-12", key_version=1,
        )
        self.material = Material.objects.create(
            owner=self.alice, file="materials/fictional.docx", original_name="虚构资料.docx",
            size_bytes=10, extracted_text="虚构资料",
        )
        self.worksheet = Worksheet.objects.create(owner=self.alice, material=self.material)
        self.task = GenerationTask.objects.create(
            owner=self.alice, worksheet=self.worksheet, kind=GenerationTask.Kind.CREATE,
            member_mode=True, member_credential=self.credential,
        )

    def test_reserve_is_single_use_and_does_not_read_a_key(self):
        attempt = reserve_task_call(self.task.pk, self.credential.pk)
        self.assertEqual(attempt.status, CallAttempt.Status.RESERVED)
        self.assertEqual(attempt.allowance_limit_at_reserve, 1)
        self.assertEqual(attempt.allowance_valid_until_at_reserve, self.allowance.valid_until)
        self.allowance.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (1, 0))
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        next_task = GenerationTask.objects.create(
            owner=self.alice, worksheet=self.worksheet, kind=GenerationTask.Kind.REVISE,
            member_mode=True, member_credential=self.credential,
        )
        with self.assertRaises(CallGateDenied):
            reserve_task_call(next_task.pk, self.credential.pk)
        self.assertEqual(CallAttempt.objects.count(), 1)

    def test_cancel_before_send_releases_but_task_cannot_be_reauthorized(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        self.assertTrue(cancel_queued_task(self.task.pk, self.alice.pk))
        self.assertFalse(cancel_queued_task(self.task.pk, self.alice.pk))
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        attempt = CallAttempt.objects.get(task=self.task)
        self.assertEqual(self.task.status, GenerationTask.Status.CANCELLED)
        self.assertEqual(attempt.status, CallAttempt.Status.RELEASED)
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))
        with self.assertRaises(CallGateDenied):
            mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))

    def test_sent_call_stays_counted_and_unknown_usage_stays_unknown(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        self.assertTrue(mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential)))
        self.assertFalse(cancel_queued_task(self.task.pk, self.alice.pk))
        attempt = finish_attempt(self.task.pk, succeeded=True)
        self.allowance.refresh_from_db()
        self.task.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 1))
        self.assertEqual(self.task.status, GenerationTask.Status.RUNNING)
        self.assertEqual(attempt.status, CallAttempt.Status.COMPLETED)
        self.assertIsNone(attempt.input_tokens)
        self.assertIsNone(attempt.output_tokens)
        with self.assertRaises(CallGateDenied):
            finish_attempt(self.task.pk, succeeded=True)

    def test_sent_failure_keeps_call_counted_and_records_only_reliable_usage(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))
        with self.assertRaises(ValueError):
            finish_attempt(self.task.pk, succeeded=False, input_tokens=10)
        attempt = finish_attempt(self.task.pk, succeeded=False, input_tokens=10, output_tokens=4)
        self.assertEqual(attempt.status, CallAttempt.Status.UNKNOWN)
        self.assertEqual((attempt.input_tokens, attempt.output_tokens), (10, 4))
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.used_calls, 1)

    def test_cancelled_after_reservation_does_not_start(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        GenerationTask.objects.filter(pk=self.task.pk).update(status=GenerationTask.Status.CANCELLED)
        self.assertFalse(mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential)))
        self.assertEqual(CallAttempt.objects.get(task=self.task).status, CallAttempt.Status.RELEASED)
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.reserved_calls, 0)

    def test_expiration_rechecked_before_send(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        self.allowance.valid_until = timezone.now() - timedelta(seconds=1)
        self.allowance.save(update_fields=["valid_until"])
        self.assertFalse(mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential)))
        self.allowance.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))

    def test_inactive_or_forced_password_change_rejected_before_reservation(self):
        self.alice.is_active = False
        self.alice.save(update_fields=["is_active"])
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        self.alice.is_active = True
        self.alice.save(update_fields=["is_active"])
        MemberAccess.objects.create(user=self.alice, must_change_password=True)
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        self.assertFalse(CallAttempt.objects.exists())

    def test_wrong_owner_and_invalid_configuration_rejected(self):
        other_credential = ModelCredential.objects.create(
            owner=self.bob, label="他人的虚构配置", provider=ModelCredential.Provider.QWEN,
            api_base_url=self.credential.api_base_url, model_name="qwen-flash",
            key_ciphertext=b"fictional-ciphertext-only", key_nonce=b"fictional-12", key_version=1,
        )
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, other_credential.pk)
        self.credential.api_base_url = "https://example.invalid/v1"
        self.credential.save(update_fields=["api_base_url"])
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        self.assertFalse(CallAttempt.objects.exists())

    def test_missing_and_expired_allowance_rejected(self):
        self.allowance.delete()
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        self.allowance = CallAllowance.objects.create(
            owner=self.alice, max_calls=1, valid_until=timezone.now() - timedelta(seconds=1),
        )
        with self.assertRaises(CallGateDenied):
            reserve_task_call(self.task.pk, self.credential.pk)
        self.assertFalse(CallAttempt.objects.exists())

    def test_deleted_configuration_after_reservation_releases(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        self.credential.delete()
        self.assertFalse(mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential)))
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.reserved_calls, 0)

    def test_changed_configuration_after_reservation_cancels_without_charge(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        self.credential.api_base_url = "https://example.invalid/v1"
        self.credential.save(update_fields=["api_base_url"])
        self.assertFalse(mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential)))
        self.task.refresh_from_db()
        self.allowance.refresh_from_db()
        self.assertEqual(self.task.status, GenerationTask.Status.CANCELLED)
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))

    def test_manager_can_set_allowance_without_private_data_or_key(self):
        manager = get_user_model().objects.create_superuser("quota_manager", password="Fictional-test-123")
        self.client.force_login(manager)
        url = reverse("member_allowance", args=[self.alice.pk])
        self.assertEqual(self.client.get(url).status_code, 200)
        deadline = (timezone.now() + timedelta(days=3)).strftime("%Y-%m-%dT%H:%M")
        response = self.client.post(url, {"max_calls": "3", "valid_until": deadline})
        self.assertEqual(response.status_code, 302)
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.max_calls, 3)
        page = self.client.get(url)
        self.assertContains(page, "已使用")
        self.assertNotContains(page, "fictional-ciphertext-only")
        self.assertNotContains(page, "虚构资料.docx")

    def test_owner_sees_counted_call_and_reliable_usage_without_secret(self):
        self.client.force_login(self.alice)
        url = reverse("worksheet_detail", args=[self.worksheet.pk])
        page = self.client.get(url)
        self.assertContains(page, "尚无调用记录")
        reserve_task_call(self.task.pk, self.credential.pk)
        page = self.client.get(url)
        self.assertContains(page, "已预留 1 次")
        mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))
        finish_attempt(self.task.pk, succeeded=True, input_tokens=0, output_tokens=7)
        page = self.client.get(url)
        self.assertContains(page, "已计入 1 次")
        self.assertContains(page, "输入 0、输出 7 token")
        self.assertNotContains(page, "fictional-ciphertext-only")
        self.client.force_login(self.bob)
        self.assertEqual(self.client.get(url).status_code, 404)

    def test_unknown_post_send_result_does_not_claim_token_usage(self):
        reserve_task_call(self.task.pk, self.credential.pk)
        mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))
        finish_attempt(self.task.pk, succeeded=False)
        self.client.force_login(self.alice)
        page = self.client.get(reverse("worksheet_detail", args=[self.worksheet.pk]))
        self.assertContains(page, "已计入 1 次；结果未知")
        self.assertContains(page, "厂商 token 用量未知")
        self.assertNotContains(page, "输入 0、输出 0 token")

    def test_allowance_cannot_drop_below_used_or_reserved(self):
        manager = get_user_model().objects.create_superuser("quota_manager", password="Fictional-test-123")
        self.client.force_login(manager)
        reserve_task_call(self.task.pk, self.credential.pk)
        deadline = (timezone.now() + timedelta(days=3)).strftime("%Y-%m-%dT%H:%M")
        response = self.client.post(reverse("member_allowance", args=[self.alice.pk]),
                                    {"max_calls": "0", "valid_until": deadline})
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "至少要保留")
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.max_calls, 1)

    def test_ordinary_teacher_cannot_view_or_change_allowance(self):
        self.client.force_login(self.bob)
        url = reverse("member_allowance", args=[self.alice.pk])
        self.assertEqual(self.client.get(url).status_code, 403)
        self.assertEqual(self.client.post(url, {"max_calls": 100}).status_code, 403)

    def test_stale_unsent_reservation_releases_and_blocks_late_worker(self):
        attempt = reserve_task_call(self.task.pk, self.credential.pk)
        later = attempt.reserved_at + timedelta(minutes=11)
        self.assertFalse(reclaim_stale_reservation(self.task.pk, at=attempt.reserved_at + timedelta(minutes=9)))
        self.assertTrue(reclaim_stale_reservation(self.task.pk, at=later))
        self.assertFalse(reclaim_stale_reservation(self.task.pk, at=later))
        self.allowance.refresh_from_db()
        self.task.refresh_from_db()
        self.assertEqual((self.allowance.reserved_calls, self.allowance.used_calls), (0, 0))
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        with self.assertRaises(CallGateDenied):
            mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))

    def test_sent_attempt_is_never_reclaimed(self):
        attempt = reserve_task_call(self.task.pk, self.credential.pk)
        mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))
        self.assertFalse(reclaim_stale_reservation(self.task.pk,
                                                  at=attempt.reserved_at + timedelta(days=1)))
        self.allowance.refresh_from_db()
        self.assertEqual(self.allowance.used_calls, 1)

    def test_stranded_sent_task_becomes_unknown_without_refund(self):
        attempt = reserve_task_call(self.task.pk, self.credential.pk)
        mark_task_sent(self.task.pk, expected_fingerprint=credential_fingerprint(self.credential))
        attempt.refresh_from_db()
        self.assertFalse(reconcile_stale_post_send_task(
            self.task.pk, at=attempt.sent_at + timedelta(minutes=9)))
        self.assertTrue(reconcile_stale_post_send_task(
            self.task.pk, at=attempt.sent_at + timedelta(minutes=11)))
        attempt.refresh_from_db()
        self.allowance.refresh_from_db()
        self.task.refresh_from_db()
        self.assertEqual(attempt.status, CallAttempt.Status.UNKNOWN)
        self.assertEqual(self.allowance.used_calls, 1)
        self.assertEqual(self.task.status, GenerationTask.Status.FAILED)
        self.assertFalse(reconcile_stale_post_send_task(
            self.task.pk, at=attempt.sent_at + timedelta(days=1)))
