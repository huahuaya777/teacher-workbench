import json
from io import BytesIO
from tempfile import TemporaryDirectory
from unittest.mock import patch
from zipfile import ZipFile

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TransactionTestCase, override_settings
from django.urls import reverse

from .models import GenerationTask, Material, Worksheet
from .tasks import process_generation_task


def fictional_slides():
    output = BytesIO()
    with ZipFile(output, "w") as archive:
        archive.writestr("ppt/presentation.xml", "<presentation/>")
        for number, text in [(10, "虚构练习"), (2, "二次函数知识点")]:
            archive.writestr(f"ppt/slides/slide{number}.xml", f"""
                <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:p><a:r><a:t>{text}</a:t></a:r></a:p>
                </p:sld>""")
    return output.getvalue()


@override_settings(AI_MEMBER_TASKS_ENABLED=False, AI_LOCAL_QUEUE=True, AI_STAGING_MANUAL_QUEUE=False)
class MaterialGenerationTests(TransactionTestCase):
    def setUp(self):
        self.owner = get_user_model().objects.create_user("fictional_material_owner")
        self.other = get_user_model().objects.create_user("fictional_material_other", is_superuser=True)
        self.client.force_login(self.owner)
        self.material = Material.objects.create(
            owner=self.owner, file="fictional.docx", original_name="二次函数教材.DOCX",
            category="九年级 / 数学", size_bytes=1, extracted_text="虚构：复习二次函数。",
        )
        self.foreign = Material.objects.create(
            owner=self.other, file="fictional_other.docx", original_name="二次函数私有资料.docx",
            category="九年级 / 私有分类", size_bytes=1, extracted_text="他人的虚构资料。",
        )

    def test_partial_terms_and_categories_only_search_own_materials(self):
        url = reverse("material_library")
        result = self.client.get(url, {"q": "函数 docx 九年级", "category": self.material.category})
        self.assertContains(result, self.material.original_name)
        self.assertNotContains(result, self.foreign.original_name)
        self.assertNotContains(result, self.foreign.category)
        self.assertContains(self.client.get(url, {"q": "几何"}), "没有匹配的资料")
        self.assertNotContains(result, "前往出试卷")
        self.assertNotContains(result, reverse("worksheet_start") + "#generation")
        self.assertFalse(GenerationTask.objects.exists())

    def test_upload_download_pptx_and_save_opaque_files(self):
        with TemporaryDirectory() as directory, override_settings(MEDIA_ROOT=directory):
            for filename, raw, expected_text in (
                ("教学课件.pptx", fictional_slides(), "二次函数知识点\n虚构练习"),
                ("课堂课件.enbx", b"fictional opaque courseware", ""),
            ):
                with self.subTest(filename=filename):
                    upload = self.client.post(reverse("upload_material"), {
                        "file": SimpleUploadedFile(filename, raw), "category": " 九年级课件 ",
                    })
                    self.assertRedirects(upload, reverse("material_library"), fetch_redirect_response=False)
                    material = Material.objects.get(original_name=filename)
                    self.assertEqual(material.category, "九年级课件")
                    self.assertEqual(material.extracted_text, expected_text)
                    response = self.client.get(reverse("download_material", args=[material.pk]))
                    try:
                        self.assertEqual(b"".join(response.streaming_content), raw)
                        self.assertTrue(response["Content-Disposition"].startswith("attachment;"))
                        self.assertEqual(response["Content-Type"], "application/octet-stream")
                    finally:
                        response.close()
            page = self.client.get(reverse("worksheet_list"))
            self.assertContains(page, "教学课件.pptx")
            self.assertNotContains(page, "课堂课件.enbx")

    def test_category_change_requires_owner_and_post(self):
        url = reverse("categorize_material", args=[self.material.pk])
        self.assertEqual(self.client.get(url).status_code, 405)
        self.client.force_login(self.other)
        self.assertEqual(self.client.post(url, {"category": "冒名分类"}).status_code, 404)
        self.client.force_login(self.owner)
        self.client.post(url, {"category": " "})
        self.material.refresh_from_db()
        self.assertEqual(self.material.category, "")
        self.assertContains(self.client.get(reverse("material_library"), {"category": " "}),
                            self.material.original_name)

    def test_generation_rejects_unreadable_and_foreign_materials_and_overlong_instruction(self):
        unreadable = Material.objects.create(
            owner=self.owner, file="fictional.jpg", original_name="照片.jpg", size_bytes=1,
        )
        for name in ("worksheet_list", "worksheet_start"):
            url = reverse(name)
            page = self.client.get(url)
            self.assertNotContains(page, reverse("upload_material"))
            self.assertNotContains(page, 'type="file"')
            self.assertNotContains(page, self.foreign.original_name)
            self.assertNotContains(page, unreadable.original_name)
            for data in (
                {"material": self.foreign.pk},
                {"material": unreadable.pk},
                {"material": self.material.pk, "instruction": "字" * 2001},
            ):
                response = self.client.post(url, data)
                self.assertTrue(response.context["form"].errors)
        self.assertFalse(Worksheet.objects.exists())
        self.assertFalse(GenerationTask.objects.exists())

    @override_settings(
        AI_ENABLED=True, AI_BASE_URL="https://fictional.example/v1",
        AI_MODEL="fictional-model", AI_API_KEY="fictional-test-key", AI_PROVIDER="openai-compatible",
    )
    def test_both_modes_reach_model_with_selected_text_and_keep_separate_history(self):
        instruction = "复习图像，安排一道基础题。"
        for route, mode, title, prompt in (
            ("worksheet_list", Worksheet.Mode.HOMEWORK, "虚构日常练习", "日常作业"),
            ("worksheet_start", Worksheet.Mode.EXAM, "虚构课堂小测", "评分要点"),
        ):
            with self.subTest(route=route):
                with patch("workbench.views.enqueue_task") as enqueue:
                    response = self.client.post(reverse(route), {
                        "material": self.material.pk, "instruction": instruction,
                    })
                    enqueue.assert_called_once()
                task = GenerationTask.objects.get(pk=enqueue.call_args.args[0])
                self.assertEqual(task.worksheet.mode, mode)
                self.assertEqual(task.status, GenerationTask.Status.QUEUED)
                self.assertRedirects(response, reverse("worksheet_detail", args=[task.worksheet_id]),
                                     fetch_redirect_response=False)
                content = {"title": title, "questions": [{"stem": "计算 1+1", "answer": "2"}]}
                data = {"choices": [{"message": {"content": json.dumps(content)}}]}
                with patch("workbench.ai._open_provider_request", return_value=BytesIO(json.dumps(data).encode())) as send:
                    process_generation_task(task.pk)
                payload = json.loads(send.call_args.args[0].data)
                self.assertIn(prompt, payload["messages"][0]["content"])
                self.assertIn(instruction, payload["messages"][1]["content"])
                self.assertIn(self.material.extracted_text, payload["messages"][1]["content"])
                self.assertNotIn(self.foreign.extracted_text, payload["messages"][1]["content"])
                self.assertContains(self.client.get(reverse(route)), title)
                other = "worksheet_start" if route == "worksheet_list" else "worksheet_list"
                self.assertNotContains(self.client.get(reverse(other)), title)
