"""Fictional credentials only; every request and crypto check stays local."""

import base64
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import Client, TestCase, override_settings
from django.urls import reverse

from .credential_vault import (VaultIntegrityError, VaultUnavailable, reseal_with_active_key,
                               unseal_key_for_owner)
from .models import ModelCredential


BASE_URL = "https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
FAKE_KEY_A = "sk-fictional-alice-key-123456"
FAKE_KEY_B = "sk-fictional-alice-replaced-789"


class ModelCredentialSecurityTests(TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="workbench-fictional-keyring-")
        self.addCleanup(self.directory.cleanup)
        self.keyring = Path(self.directory.name)
        self._write_key(1, os.urandom(32))
        key_settings = override_settings(MODEL_KEYRING_DIR=self.directory.name, MODEL_ACTIVE_KEY_VERSION=1)
        key_settings.enable()
        self.addCleanup(key_settings.disable)
        user_model = get_user_model()
        self.alice = user_model.objects.create_user("alice", password="Alice-test-123")
        self.bob = user_model.objects.create_user("bob", password="Bob-test-123")
        self.manager = user_model.objects.create_superuser("manager", password="Manager-test-123")
        self.client.force_login(self.alice)

    def _write_key(self, version, value):
        path = self.keyring / f"v{version}.key"
        path.write_bytes(base64.b64encode(value) + b"\n")
        if os.name == "posix":
            path.chmod(0o600)
        return path

    def _create(self):
        return self.client.post(reverse("credential_list"), {
            "label": "我的虚构百炼", "api_base_url": BASE_URL,
            "model_name": "qwen-flash", "api_key": FAKE_KEY_A,
        })

    def test_owner_can_save_replace_delete_without_any_key_reflection(self):
        created = self._create()
        self.assertEqual(created.status_code, 302)
        credential = ModelCredential.objects.get(owner=self.alice)
        self.assertNotIn(FAKE_KEY_A.encode(), bytes(credential.key_ciphertext))
        self.assertEqual(len(credential.key_nonce), 12)
        self.assertEqual(unseal_key_for_owner(credential, self.alice.pk), FAKE_KEY_A)
        listing = self.client.get(reverse("credential_list"))
        self.assertContains(listing, "我的虚构百炼")
        self.assertContains(listing, "已保存 Key")
        self.assertNotContains(listing, FAKE_KEY_A)
        self.assertNotContains(listing, bytes(credential.key_ciphertext).hex())
        self.assertIn("no-store", listing["Cache-Control"])

        old_nonce = bytes(credential.key_nonce)
        replaced = self.client.post(reverse("credential_replace", args=[credential.pk]), {"api_key": FAKE_KEY_B})
        self.assertEqual(replaced.status_code, 302)
        credential.refresh_from_db()
        self.assertNotEqual(bytes(credential.key_nonce), old_nonce)
        self.assertEqual(unseal_key_for_owner(credential, self.alice.pk), FAKE_KEY_B)
        self.assertNotContains(self.client.get(reverse("credential_list")), FAKE_KEY_B)
        self.assertEqual(self.client.post(reverse("credential_delete", args=[credential.pk])).status_code, 302)
        self.assertFalse(ModelCredential.objects.filter(pk=credential.pk).exists())

    def test_other_member_and_manager_cannot_read_or_modify_owner_secret(self):
        self._create()
        credential = ModelCredential.objects.get(owner=self.alice)
        for user in (self.bob, self.manager):
            browser = Client()
            browser.force_login(user)
            self.assertNotContains(browser.get(reverse("credential_list")), "我的虚构百炼")
            self.assertEqual(browser.post(reverse("credential_replace", args=[credential.pk]),
                                          {"api_key": FAKE_KEY_B}).status_code, 404)
            self.assertEqual(browser.post(reverse("credential_delete", args=[credential.pk])).status_code, 404)
        with self.assertRaises(VaultIntegrityError):
            unseal_key_for_owner(credential, self.bob.pk)
        credential.refresh_from_db()
        self.assertEqual(unseal_key_for_owner(credential, self.alice.pk), FAKE_KEY_A)

    def test_wrong_key_and_changed_owner_or_metadata_fail_closed(self):
        self._create()
        credential = ModelCredential.objects.get(owner=self.alice)
        original_key = (self.keyring / "v1.key").read_bytes()
        self._write_key(1, os.urandom(32))
        with self.assertRaises(VaultIntegrityError):
            unseal_key_for_owner(credential, self.alice.pk)
        (self.keyring / "v1.key").write_bytes(original_key)
        credential.owner = self.bob
        with self.assertRaises(VaultIntegrityError):
            unseal_key_for_owner(credential, self.bob.pk)
        credential.owner = self.alice
        credential.model_name = "another-model"
        with self.assertRaises(VaultIntegrityError):
            unseal_key_for_owner(credential, self.alice.pk)

    def test_absent_keyring_blocks_save_and_existing_ciphertext_can_be_resealed(self):
        self._create()
        credential = ModelCredential.objects.get(owner=self.alice)
        old_nonce = bytes(credential.key_nonce)
        old_path = self.keyring / "v1.key"
        old_path.rename(self.keyring / "v1.key.offline")
        with self.assertRaises(VaultUnavailable):
            unseal_key_for_owner(credential, self.alice.pk)
        with override_settings(MODEL_KEYRING_DIR=""):
            response = self.client.post(reverse("credential_list"), {
                "label": "不能保存", "api_base_url": BASE_URL,
                "model_name": "qwen-flash", "api_key": FAKE_KEY_B,
            })
            self.assertEqual(response.status_code, 200)
            self.assertNotContains(response, FAKE_KEY_B)
            self.assertEqual(ModelCredential.objects.count(), 1)
        (self.keyring / "v1.key.offline").rename(old_path)
        self._write_key(2, os.urandom(32))
        with override_settings(MODEL_ACTIVE_KEY_VERSION=2):
            self.assertTrue(reseal_with_active_key(credential))
            credential.save(update_fields=["key_ciphertext", "key_nonce", "key_version", "updated_at"])
            credential.refresh_from_db()
            self.assertEqual(credential.key_version, 2)
            self.assertNotEqual(bytes(credential.key_nonce), old_nonce)
            old_path.rename(self.keyring / "v1.key.retired")
            self.assertEqual(unseal_key_for_owner(credential, self.alice.pk), FAKE_KEY_A)

    def test_unapproved_endpoint_does_not_store_secret(self):
        response = self.client.post(reverse("credential_list"), {
            "label": "错误地址", "api_base_url": "http://127.0.0.1:8000/compatible-mode/v1",
            "model_name": "qwen-flash", "api_key": FAKE_KEY_A,
        })
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "仅保存百炼北京地域")
        self.assertNotContains(response, FAKE_KEY_A)
        self.assertFalse(ModelCredential.objects.exists())

    def test_key_with_control_character_is_rejected_without_reflection(self):
        bad_key = FAKE_KEY_A + "\n"
        response = self.client.post(reverse("credential_list"), {
            "label": "错误 Key", "api_base_url": BASE_URL,
            "model_name": "qwen-flash", "api_key": bad_key,
        })
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, FAKE_KEY_A)
        self.assertFalse(ModelCredential.objects.exists())

    def test_staging_rejects_nonfictional_key_without_reflection(self):
        with patch.dict(os.environ, {"TW_STAGING": "1"}):
            response = self.client.post(reverse("credential_list"), {
                "label": "不保存", "api_base_url": BASE_URL,
                "model_name": "qwen-flash", "api_key": "sk-not-a-fictional-test-key",
            })
        self.assertEqual(response.status_code, 200)
        self.assertNotContains(response, "sk-not-a-fictional-test-key")
        self.assertFalse(ModelCredential.objects.exists())

    def test_manager_can_preconfigure_but_cannot_read_saved_key(self):
        manager_browser = Client()
        manager_browser.force_login(self.manager)
        url = reverse("credential_preconfigure", args=[self.bob.pk])
        created = manager_browser.post(url, {
            "label": "管理员预配虚构配置", "api_base_url": BASE_URL,
            "model_name": "qwen-flash", "api_key": FAKE_KEY_A,
        })
        self.assertEqual(created.status_code, 302)
        credential = ModelCredential.objects.get(owner=self.bob)
        self.assertEqual(unseal_key_for_owner(credential, self.bob.pk), FAKE_KEY_A)
        manager_list = manager_browser.get(reverse("member_list"))
        self.assertNotContains(manager_list, FAKE_KEY_A)
        self.assertNotContains(manager_browser.get(reverse("credential_list")), "管理员预配虚构配置")
        self.assertNotContains(manager_browser.get(url), FAKE_KEY_A)
        alice_browser = Client()
        alice_browser.force_login(self.alice)
        self.assertEqual(alice_browser.get(url).status_code, 403)
        self.assertEqual(alice_browser.post(url, {
            "label": "越权", "api_base_url": BASE_URL,
            "model_name": "qwen-flash", "api_key": FAKE_KEY_B,
        }).status_code, 403)
        bob_browser = Client()
        bob_browser.force_login(self.bob)
        self.assertContains(bob_browser.get(reverse("credential_list")), "管理员预配虚构配置")
        self.assertNotContains(bob_browser.get(reverse("credential_list")), FAKE_KEY_A)

    def test_rotation_is_atomic_and_includes_inactive_member(self):
        self._create()
        first = ModelCredential.objects.get(owner=self.alice)
        manager_browser = Client()
        manager_browser.force_login(self.manager)
        manager_browser.post(reverse("credential_preconfigure", args=[self.bob.pk]), {
            "label": "B 的虚构配置", "api_base_url": BASE_URL,
            "model_name": "qwen-flash", "api_key": FAKE_KEY_B,
        })
        self.bob.is_active = False
        self.bob.save(update_fields=["is_active"])
        self._write_key(2, os.urandom(32))
        with override_settings(MODEL_ACTIVE_KEY_VERSION=2):
            with self.assertRaises(CommandError):
                call_command("rotate_model_credentials")
            first.refresh_from_db()
            self.assertEqual(first.key_version, 1)
            old_key = (self.keyring / "v1.key").read_bytes()
            self._write_key(1, os.urandom(32))
            with self.assertRaises(CommandError):
                call_command("rotate_model_credentials", confirm=True)
            self.assertEqual(set(ModelCredential.objects.values_list("key_version", flat=True)), {1})
            (self.keyring / "v1.key").write_bytes(old_key)
            call_command("rotate_model_credentials", confirm=True)
            self.assertEqual(set(ModelCredential.objects.values_list("key_version", flat=True)), {2})
            (self.keyring / "v1.key").rename(self.keyring / "v1.key.retired")
            first.refresh_from_db()
            self.assertEqual(unseal_key_for_owner(first, self.alice.pk), FAKE_KEY_A)
            with self.assertRaises(VaultIntegrityError):
                unseal_key_for_owner(ModelCredential.objects.get(owner=self.bob), self.bob.pk)
