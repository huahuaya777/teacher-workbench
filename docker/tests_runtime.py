import os
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from . import runtime


class RuntimeSecretTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.data, self.keys = root / "data", root / "keys"
        self.data.mkdir(mode=0o700)
        self.keys.mkdir(mode=0o700)
        for name, value in (("DATA", self.data), ("KEYRING", self.keys)):
            setting = patch.object(runtime, name, value)
            setting.start()
            self.addCleanup(setting.stop)

    def test_new_install_has_private_stable_secrets(self):
        runtime.initialize_secrets()
        first = {path.name: path.read_bytes() for path in self.keys.iterdir()}
        runtime.initialize_secrets()
        self.assertEqual(first, {path.name: path.read_bytes() for path in self.keys.iterdir()})
        self.assertEqual(set(first), {"django-secret", "database-password", "v1.key"})
        self.assertTrue(all(path.stat().st_mode & 0o777 == 0o600 for path in self.keys.iterdir()))

    def test_existing_database_cannot_silently_replace_missing_keys(self):
        (self.data / "postgres").mkdir()
        (self.data / "postgres/PG_VERSION").write_text("17")
        with self.assertRaisesRegex(RuntimeError, "missing keyring"):
            runtime.initialize_secrets()
        self.assertFalse(list(self.keys.iterdir()))

    def test_unsafe_permissions_symlinks_and_malformed_keys_are_rejected(self):
        runtime.initialize_secrets()
        key = self.keys / "v1.key"
        key.chmod(0o644)
        with self.assertRaises(RuntimeError):
            runtime.read_secret("v1.key")
        key.chmod(0o600)
        key.write_text("a" * 40)
        with self.assertRaises(RuntimeError):
            runtime.read_secret("v1.key")
        link = self.keys / "linked-secret"
        link.symlink_to(self.keys / "django-secret")
        with self.assertRaises(RuntimeError):
            runtime.read_secret("linked-secret")
        self.keys.chmod(0o755)
        with self.assertRaises(RuntimeError):
            runtime.read_secret("django-secret")

    def test_ai_requires_explicit_member_opt_in_and_never_reuses_process_key(self):
        runtime.initialize_secrets()
        with patch.dict(os.environ, {"AI_ENABLED": "1", "AI_API_KEY": "fictional-process-key",
                                     "TW_ENABLE_MEMBER_AI": "0"}):
            runtime.configure_environment()
            self.assertEqual(os.environ["AI_ENABLED"], "0")
            self.assertEqual(os.environ["AI_API_KEY"], "")
            self.assertEqual(os.environ["DB_PASSWORD"], runtime.read_secret("database-password"))
            os.environ["TW_ENABLE_MEMBER_AI"] = "1"
            runtime.configure_environment()
            self.assertEqual(os.environ["AI_MEMBER_TASKS_ENABLED"], "1")
