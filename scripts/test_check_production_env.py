"""Regression checks for the offline production configuration gate."""

import unittest

from check_production_env import valid_hostname, validate


class ProductionHostGateTests(unittest.TestCase):
    def test_actual_hostname_is_allowed(self):
        self.assertTrue(valid_hostname("workbench.huahuaya.top"))

    def test_ip_literal_is_rejected(self):
        self.assertFalse(valid_hostname("10.0.30.5"))
        self.assertFalse(valid_hostname("127.0.0.1"))
        self.assertFalse(valid_hostname("2001:db8::1"))

    def test_easytier_ip_cannot_pass_production_configuration(self):
        values = {
            "DJANGO_DEBUG": "0",
            "DJANGO_SECRET_KEY": "a" * 64,
            "DB_PASSWORD": "b" * 32,
            "DB_NAME": "teacher_workbench",
            "DB_USER": "teacher_workbench",
            "DB_HOST": "db",
            "DJANGO_ALLOWED_HOSTS": "10.0.30.5",
            "DJANGO_CSRF_TRUSTED_ORIGINS": "https://10.0.30.5",
            "DJANGO_SECURE_SSL_REDIRECT": "1",
            "DJANGO_TRUST_PROXY_SSL_HEADER": "1",
            "DJANGO_HSTS_SECONDS": "3600",
            "TW_HTTPS_INGRESS_VERIFIED": "1",
            "AI_ENABLED": "0",
            "AI_API_KEY": "",
            "AI_LOCAL_QUEUE": "0",
        }
        self.assertTrue(any("DJANGO_ALLOWED_HOSTS" in error for error in validate(values)))


if __name__ == "__main__":
    unittest.main()
