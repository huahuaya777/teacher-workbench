from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import Client, TransactionTestCase
from django.urls import reverse

from .models import GenerationTask, Material, Worksheet, WorksheetVersion
from .tasks import process_generation_task


class FinalVersionTests(TransactionTestCase):
    def setUp(self):
        self.owner = get_user_model().objects.create_user("fictional_final_owner")
        self.other = get_user_model().objects.create_user("fictional_final_other", is_staff=True,
                                                          is_superuser=True)
        material = Material.objects.create(owner=self.owner, file="fictional.docx",
                                           original_name="虚构资料.docx", size_bytes=1,
                                           extracted_text="虚构：计算 1+1。")
        self.worksheet = Worksheet.objects.create(owner=self.owner, material=material)
        self.versions = [WorksheetVersion.objects.create(
            worksheet=self.worksheet, number=number,
            content={"title": f"虚构第{number}版", "questions": [
                {"stem": f"计算 {number}+1", "answer": str(number + 1), "source": "虚构测试"},
            ]},
        ) for number in (1, 2)]
        self.client.force_login(self.owner)

    def url(self, action, number=1, worksheet=None):
        return reverse(action, args=[(worksheet or self.worksheet).pk, number])

    def test_mark_switch_and_unmark_keep_all_versions_and_do_not_start_ai(self):
        original = list(self.worksheet.versions.values("id", "number", "content", "change_request"))
        with patch("workbench.views.enqueue_task") as queue, patch("workbench.ai._open_provider_request") as provider:
            for number in (1, 1, 2):
                response = self.client.post(self.url("mark_final_version", number), follow=True)
                self.assertContains(response, f"正式成果预览 · 第 {number} 版")
                self.worksheet.refresh_from_db()
                self.assertEqual(self.worksheet.final_version_id, self.versions[number - 1].pk)
            self.client.post(self.url("unmark_final_version", 2))
            self.worksheet.refresh_from_db()
            self.assertIsNone(self.worksheet.final_version_id)
            queue.assert_not_called()
            provider.assert_not_called()
        self.assertEqual(GenerationTask.objects.count(), 0)
        self.assertEqual(list(self.worksheet.versions.values("id", "number", "content", "change_request")), original)

    def test_stale_unmark_cannot_remove_newer_final_selection(self):
        self.client.post(self.url("mark_final_version", 1))
        self.client.post(self.url("mark_final_version", 2))
        response = self.client.post(self.url("unmark_final_version", 1), follow=True)
        self.assertContains(response, "正式标记已变化")
        self.worksheet.refresh_from_db()
        self.assertEqual(self.worksheet.final_version_id, self.versions[1].pk)

    def test_new_revision_keeps_final_version_and_both_exports(self):
        self.client.post(self.url("mark_final_version", 1))
        task = GenerationTask.objects.create(owner=self.owner, worksheet=self.worksheet,
                                              kind=GenerationTask.Kind.REVISE, instruction="虚构修改")
        content = {"title": "虚构新草稿", "questions": [
            {"stem": "计算 3+1", "answer": "4", "source": "虚构测试"},
        ]}
        with patch("workbench.tasks.request_worksheet", return_value=content):
            process_generation_task(task.pk)
        self.worksheet.refresh_from_db()
        self.assertEqual(self.worksheet.final_version_id, self.versions[0].pk)
        self.assertEqual(self.worksheet.versions.count(), 3)
        response = self.client.get(reverse("worksheet_detail", args=[self.worksheet.pk]))
        self.assertContains(response, "草稿预览 · 第 3 版")
        self.assertContains(response, "第 1 版 · 虚构第1版")
        listing = self.client.get(reverse("worksheet_list"))
        self.assertContains(listing, "正式成果 · 第 1 版 · 虚构第1版")
        self.assertContains(listing, f'?version=1')
        for variant in ("student", "teacher"):
            exported = self.client.get(reverse("export_worksheet", args=[self.worksheet.pk, 1, variant]))
            try:
                self.assertEqual(exported.status_code, 200)
                self.assertGreater(len(b"".join(exported.streaming_content)), 0)
            finally:
                exported.close()

    def test_even_administrator_cannot_mark_or_read_another_owners_work(self):
        self.client.post(self.url("mark_final_version"))
        self.client.force_login(self.other)
        for action in ("mark_final_version", "unmark_final_version"):
            self.assertEqual(self.client.post(self.url(action)).status_code, 404)
        self.assertNotContains(self.client.get(reverse("worksheet_list")), "虚构第1版")
        self.assertEqual(self.client.get(reverse("worksheet_detail", args=[self.worksheet.pk])).status_code, 404)
        self.worksheet.refresh_from_db()
        self.assertEqual(self.worksheet.final_version_id, self.versions[0].pk)

    def test_version_must_belong_to_this_worksheet(self):
        another = Worksheet.objects.create(owner=self.owner, material=self.worksheet.material)
        WorksheetVersion.objects.create(worksheet=another, number=3, content={"title": "另一份虚构作业"})
        for action in ("mark_final_version", "unmark_final_version"):
            for number in (3, 999):
                self.assertEqual(self.client.post(self.url(action, number)).status_code, 404)
        self.worksheet.refresh_from_db()
        self.assertIsNone(self.worksheet.final_version_id)

    def test_changes_require_login_post_and_csrf(self):
        for action in ("mark_final_version", "unmark_final_version"):
            self.assertEqual(self.client.get(self.url(action)).status_code, 405)
            protected = Client(enforce_csrf_checks=True)
            protected.force_login(self.owner)
            self.assertEqual(protected.post(self.url(action)).status_code, 403)
            anonymous = Client()
            self.assertEqual(anonymous.post(self.url(action)).status_code, 302)
        self.worksheet.refresh_from_db()
        self.assertIsNone(self.worksheet.final_version_id)
