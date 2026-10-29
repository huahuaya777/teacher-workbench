"""PostgreSQL-only concurrent reservation check, using fictional rows."""

from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from unittest import skipUnless

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import connections
from django.test import TransactionTestCase
from django.utils import timezone

from .call_gate import CallGateDenied, reserve_task_call
from .models import CallAllowance, CallAttempt, GenerationTask, Material, ModelCredential, Worksheet


@skipUnless(settings.DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql",
            "只在 PostgreSQL 隔离测试库检查并发预留")
class ConcurrentCallGateTests(TransactionTestCase):
    def test_two_tasks_compete_for_one_call(self):
        owner = get_user_model().objects.create_user("pg_quota_teacher", password="Fictional-test-123")
        allowance = CallAllowance.objects.create(
            owner=owner, max_calls=1, valid_until=timezone.now() + timedelta(days=1),
        )
        credential = ModelCredential.objects.create(
            owner=owner, label="虚构模型", provider=ModelCredential.Provider.QWEN,
            api_base_url="https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            model_name="qwen-flash", key_ciphertext=b"fictional-ciphertext-only",
            key_nonce=b"fictional-12", key_version=1,
        )
        material = Material.objects.create(
            owner=owner, file="materials/fictional.docx", original_name="虚构资料.docx",
            size_bytes=10, extracted_text="虚构资料",
        )
        worksheet = Worksheet.objects.create(owner=owner, material=material)
        task_ids = [GenerationTask.objects.create(
            owner=owner, worksheet=worksheet, kind=GenerationTask.Kind.CREATE,
            member_mode=True, member_credential=credential,
        ).pk for _ in range(2)]
        barrier = Barrier(2)

        def attempt(task_id):
            try:
                barrier.wait(timeout=15)
                reserve_task_call(task_id, credential.pk)
                return "reserved"
            except CallGateDenied:
                return "denied"
            finally:
                connections["default"].close()

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(attempt, task_ids))
        self.assertCountEqual(results, ["reserved", "denied"])
        allowance.refresh_from_db()
        self.assertEqual((allowance.reserved_calls, allowance.used_calls), (1, 0))
        self.assertEqual(CallAttempt.objects.count(), 1)
