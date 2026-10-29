"""Stage-2A account lifecycle checks using only fictional users and passwords."""

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.test import Client, TestCase
from django.urls import reverse

from .models import Material, MemberAccess, MemberAudit, Worksheet


class MemberLifecycleTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.manager = user_model.objects.create_superuser("manager_a", password="Manager-test-123")
        self.alice = user_model.objects.create_user("alice", password="Alice-test-123")
        self.bob = user_model.objects.create_user("bob", password="Bob-test-123")
        self.client.force_login(self.manager)

    def test_create_requires_first_password_change_and_shows_secret_once(self):
        response = self.client.post(reverse("member_list"), {"username": "new_teacher"})
        self.assertEqual(response.status_code, 200)
        self.assertIn("private", response["Cache-Control"])
        self.assertIn("no-store", response["Cache-Control"])
        password = response.context["temporary_password"]
        member = get_user_model().objects.get(username="new_teacher")
        self.assertTrue(member.check_password(password))
        self.assertFalse(member.is_staff)
        self.assertTrue(member.member_access.must_change_password)
        self.assertEqual(MemberAudit.objects.filter(target=member, action=MemberAudit.Action.CREATE).count(), 1)
        member_list = self.client.get(reverse("member_list"))
        self.assertNotContains(member_list, password)
        self.assertContains(member_list, "待修改密码")

        browser = Client()
        self.assertEqual(browser.post(reverse("login"), {
            "username": member.username, "password": password,
        }).status_code, 302)
        self.assertRedirects(browser.get(reverse("dashboard")), reverse("member_change_password"))
        change_page = browser.get(reverse("member_change_password"))
        self.assertEqual(change_page.status_code, 200)
        self.assertNotContains(change_page, "出试卷")
        self.assertContains(change_page, "退出")
        bad = browser.post(reverse("member_change_password"), {
            "old_password": "wrong", "new_password1": "New-teacher-test-123",
            "new_password2": "New-teacher-test-123",
        })
        self.assertEqual(bad.status_code, 200)
        self.assertTrue(MemberAccess.objects.get(user=member).must_change_password)
        changed = browser.post(reverse("member_change_password"), {
            "old_password": password, "new_password1": "New-teacher-test-123",
            "new_password2": "New-teacher-test-123",
        })
        self.assertRedirects(changed, reverse("dashboard"), fetch_redirect_response=False)
        self.assertFalse(MemberAccess.objects.get(user=member).must_change_password)
        self.assertEqual(browser.get(reverse("dashboard")).status_code, 200)
        member.refresh_from_db()
        self.assertFalse(member.check_password(password))
        self.assertTrue(member.check_password("New-teacher-test-123"))

    def test_non_manager_cannot_manage_or_see_other_member_data(self):
        secret_name = "alice-private-material.docx"
        material = Material.objects.create(owner=self.alice, file="materials/alice/a.docx",
                                           original_name=secret_name, size_bytes=10,
                                           extracted_text="fictional")
        worksheet = Worksheet.objects.create(owner=self.alice, material=material)
        browser = Client()
        browser.force_login(self.bob)
        self.assertEqual(browser.get(reverse("member_list")).status_code, 403)
        self.assertEqual(browser.post(reverse("member_list"), {"username": "intruder"}).status_code, 403)
        self.assertEqual(browser.post(reverse("member_reset_password", args=[self.alice.pk])).status_code, 403)
        self.assertEqual(browser.get(reverse("download_material", args=[material.pk])).status_code, 404)
        self.assertEqual(browser.get(reverse("worksheet_detail", args=[worksheet.pk])).status_code, 404)
        self.assertNotIn(secret_name, self.client.get(reverse("member_list")).content.decode())

    def test_reset_and_deactivate_revoke_existing_sessions_without_deleting_work(self):
        material = Material.objects.create(owner=self.alice, file="materials/alice/a.docx",
                                           original_name="fictional.docx", size_bytes=10,
                                           extracted_text="fictional")
        browser = Client()
        browser.force_login(self.alice)
        reset = self.client.post(reverse("member_reset_password", args=[self.alice.pk]))
        self.assertEqual(reset.status_code, 200)
        new_password = reset.context["temporary_password"]
        self.assertRedirects(browser.get(reverse("dashboard")), reverse("login") + "?next=/",
                             fetch_redirect_response=False)
        self.assertEqual(Material.objects.filter(pk=material.pk, owner=self.alice).count(), 1)
        self.assertTrue(MemberAccess.objects.get(user=self.alice).must_change_password)

        self.assertEqual(browser.post(reverse("login"), {
            "username": "alice", "password": new_password,
        }).status_code, 302)
        self.assertRedirects(browser.get(reverse("dashboard")), reverse("member_change_password"))
        self.client.post(reverse("member_deactivate", args=[self.alice.pk]))
        self.alice.refresh_from_db()
        self.assertFalse(self.alice.is_active)
        self.assertRedirects(browser.get(reverse("dashboard")), reverse("login") + "?next=/",
                             fetch_redirect_response=False)
        self.assertEqual(Material.objects.filter(pk=material.pk).count(), 1)

        activated = self.client.post(reverse("member_reactivate", args=[self.alice.pk]))
        self.assertEqual(activated.status_code, 200)
        activated_password = activated.context["temporary_password"]
        self.alice.refresh_from_db()
        self.assertTrue(self.alice.is_active)
        self.assertFalse(self.alice.check_password(new_password))
        self.assertTrue(self.alice.check_password(activated_password))
        self.assertTrue(MemberAccess.objects.get(user=self.alice).must_change_password)

    def test_manager_cannot_reset_staff_or_create_case_variant(self):
        staff = get_user_model().objects.create_user("staff_a", password="Staff-test-123", is_staff=True)
        self.assertEqual(self.client.post(reverse("member_reset_password", args=[staff.pk])).status_code, 404)
        duplicate = self.client.post(reverse("member_list"), {"username": "ALICE"})
        self.assertEqual(duplicate.status_code, 200)
        self.assertContains(duplicate, "小写字母")
        self.assertEqual(get_user_model().objects.filter(username__iexact="alice").count(), 1)

    def test_existing_account_without_member_access_remains_usable(self):
        browser = Client()
        browser.force_login(self.bob)
        self.assertEqual(browser.get(reverse("dashboard")).status_code, 200)
        self.assertFalse(MemberAccess.objects.filter(user=self.bob).exists())

    def test_explicit_manager_permission_controls_access_not_staff_flag(self):
        staff = get_user_model().objects.create_user("staff_b", password="Staff-test-123", is_staff=True)
        browser = Client()
        browser.force_login(staff)
        self.assertEqual(browser.get(reverse("member_list")).status_code, 403)

        manager = get_user_model().objects.create_user("manager_b", password="Manager-test-123")
        manager.user_permissions.add(Permission.objects.get(codename="manage_members"))
        browser.force_login(manager)
        manager_list = browser.get(reverse("member_list"))
        self.assertEqual(manager_list.status_code, 200)
        self.assertNotIn(manager.pk, [member.pk for member in manager_list.context["members"]])
        self.assertEqual(browser.post(reverse("member_deactivate", args=[manager.pk])).status_code, 404)
        manager.refresh_from_db()
        self.assertTrue(manager.is_active)
        created = browser.post(reverse("member_list"), {"username": "teacher_c"})
        self.assertEqual(created.status_code, 200)
        self.assertTrue(get_user_model().objects.filter(username="teacher_c").exists())
