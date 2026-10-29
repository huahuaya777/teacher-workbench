"""Exercise encrypted pilot escrow round-trip and rejected credentials."""

import hashlib
import unittest

import offline_pilot_escrow_package as package


class PilotEscrowPackageTests(unittest.TestCase):
    def setUp(self):
        self.files = {
            "env.pilot": b"DJANGO_SECRET_KEY=fictional\n",
            "v1.key": b"ZmljdGlvbmFsLWtleQ==\n",
            "caddy_data.tar.gz": b"fictional-caddy-ca",
            "caddy_config.tar.gz": b"fictional-caddy-config",
            "STATE": b"PILOT_ESCROW_COMPLETE\n",
        }
        self.files["SHA256SUMS"] = "".join(
            f"{hashlib.sha256(self.files[name]).hexdigest()}  {name}\n"
            for name in package.SECRET_NAMES
        ).encode("ascii")

    def test_round_trip_and_wrong_passphrase(self):
        encrypted = package.seal(self.files, "fictional-long-offline-passphrase-2026")
        self.assertNotIn(b"DJANGO_SECRET_KEY", encrypted)
        self.assertEqual(package.unseal(encrypted, "fictional-long-offline-passphrase-2026"), self.files)
        with self.assertRaisesRegex(ValueError, "PASSPHRASE_OR_PACKAGE_INVALID"):
            package.unseal(encrypted, "incorrect-long-offline-passphrase")

    def test_invalid_manifest_and_short_passphrase_rejected(self):
        altered = dict(self.files)
        altered["env.pilot"] = b"changed"
        with self.assertRaisesRegex(ValueError, "ESCROW_MANIFEST_HASH_INVALID"):
            package.seal(altered, "fictional-long-offline-passphrase-2026")
        with self.assertRaisesRegex(ValueError, "PASSPHRASE_TOO_SHORT"):
            package.seal(self.files, "short")


if __name__ == "__main__":
    unittest.main()
