"""Focused safety checks for the private pilot configuration gate."""

import unittest

from check_pilot_env import validate


def safe_values():
    return {
        "TW_PILOT": "1",
        "DJANGO_SETTINGS_MODULE": "config.settings",
        "DJANGO_DEBUG": "0",
        "DJANGO_SECRET_KEY": "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-!",
        "DB_PASSWORD": "0123456789abcdefghijklmnopQRSTUV",
        "DB_NAME": "teacher_workbench_pilot",
        "DB_USER": "teacher_workbench_pilot",
        "DB_HOST": "db",
        "REDIS_URL": "redis://redis:6379/0",
        "DJANGO_ALLOWED_HOSTS": "10.0.30.5",
        "DJANGO_CSRF_TRUSTED_ORIGINS": "https://10.0.30.5:18443",
        "DJANGO_SECURE_SSL_REDIRECT": "1",
        "DJANGO_TRUST_PROXY_SSL_HEADER": "1",
        "DJANGO_HSTS_SECONDS": "3600",
        "MODEL_KEYRING_DIR": "/run/model-keyring",
        "MODEL_ACTIVE_KEY_VERSION": "1",
        "PILOT_KEYRING_DIR": "/home/huahua/teacher-workbench-pilot-keyring-Ab12Cd34",
        "PILOT_APP_IMAGE": "sha256:" + "a" * 64,
        "PILOT_DB_IMAGE": "sha256:" + "b" * 64,
        "PILOT_REDIS_IMAGE": "sha256:" + "c" * 64,
        "PILOT_CADDY_IMAGE": "sha256:" + "d" * 64,
        "AI_ENABLED": "0",
        "AI_API_KEY": "",
        "AI_LOCAL_QUEUE": "0",
        "AI_STAGING_MANUAL_QUEUE": "0",
        "AI_MEMBER_TASKS_ENABLED": "0",
    }


class PilotEnvironmentGateTests(unittest.TestCase):
    def test_valid_isolated_ai_off_ip_https(self):
        self.assertEqual(validate(safe_values()), [])

    def test_http_or_other_origin_is_rejected(self):
        for origin in ("http://10.0.30.5:18443", "https://10.0.30.5", "https://evil.example"):
            with self.subTest(origin=origin):
                values = safe_values()
                values["DJANGO_CSRF_TRUSTED_ORIGINS"] = origin
                self.assertTrue(validate(values))

    def test_paid_or_staging_modes_are_rejected(self):
        for name, value in (("AI_ENABLED", "1"), ("AI_API_KEY", "sk-fictional-test"),
                            ("AI_MEMBER_TASKS_ENABLED", "1"), ("TW_STAGING", "1"),
                            ("DJANGO_DEBUG", "1")):
            with self.subTest(name=name):
                values = safe_values()
                values[name] = value
                self.assertTrue(validate(values))

    def test_unpinned_image_and_shared_keyring_rejected(self):
        values = safe_values()
        values["PILOT_APP_IMAGE"] = "latest"
        values["PILOT_KEYRING_DIR"] = "/home/huahua/teacher-workbench-staging-key-escrow/keyring-1234"
        self.assertGreaterEqual(len(validate(values)), 2)


if __name__ == "__main__":
    unittest.main()
