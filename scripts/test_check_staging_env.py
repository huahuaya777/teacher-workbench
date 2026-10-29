"""Safety checks for the isolated staging configuration."""

import unittest

from check_staging_env import validate


class StagingEnvTests(unittest.TestCase):
    def setUp(self):
        self.values = {
            "DJANGO_DEBUG": "1",
            "DJANGO_SECRET_KEY": "s" * 64,
            "DJANGO_ALLOWED_HOSTS": "localhost,127.0.0.1",
            "DB_NAME": "teacher_workbench_staging",
            "DB_USER": "teacher_workbench_staging",
            "DB_PASSWORD": "p" * 48,
            "AI_ENABLED": "0",
            "AI_API_KEY": "",
            "AI_LOCAL_QUEUE": "0",
            "AI_STAGING_MANUAL_QUEUE": "1",
            "TW_STAGING": "1",
            "REDIS_URL": "redis://redis:6379/0",
            "DJANGO_SETTINGS_MODULE": "config.settings_staging",
        }

    def test_safe_values_pass(self):
        self.assertEqual(validate(self.values), [])

    def test_wrong_database_or_cache_fails(self):
        self.values["DB_NAME"] = "teacher_workbench"
        self.values["REDIS_URL"] = "redis://localhost:6379/0"
        self.assertTrue(validate(self.values))

    def test_ai_or_https_mode_fails(self):
        self.values["AI_ENABLED"] = "1"
        self.values["DJANGO_SECURE_SSL_REDIRECT"] = "1"
        self.assertTrue(validate(self.values))

    def test_automatic_queue_mode_fails(self):
        self.values["AI_STAGING_MANUAL_QUEUE"] = "0"
        self.assertTrue(validate(self.values))


if __name__ == "__main__":
    unittest.main()
