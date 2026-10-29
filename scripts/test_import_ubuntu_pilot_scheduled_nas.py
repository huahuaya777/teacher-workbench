"""Offline safety checks for the future read-only NAS import."""

import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import import_ubuntu_pilot_scheduled_nas as importer


class ScheduledNasImportTests(unittest.TestCase):
    def test_imports_whitelisted_data_and_rejects_duplicate(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mount_point = root / "nas"
            mount_point.mkdir()
            name = "pilot-scheduled-data-ABCDEFGH-012345abcdef"
            source = mount_point / name
            source.mkdir()
            payload = {}
            for item in importer.transfer.PAYLOAD:
                content = ("fictional:" + item).encode("ascii")
                (source / item).write_bytes(content)
                payload[item] = hashlib.sha256(content).hexdigest()
            (source / "NAS_SHA256SUMS").write_text("".join(
                f"{payload[item]}  {item}\n" for item in importer.transfer.PAYLOAD), encoding="ascii")
            (source / "NAS_TRANSFER_STATE").write_text("NAS_TRANSFER_COMPLETE\n", encoding="ascii")
            with (
                patch.object(importer.transfer, "SCHEDULED_ROOT", root),
                patch.object(importer.transfer, "mount"),
                patch.object(importer.transfer, "require_mount"),
                patch.object(importer.transfer, "safe_directory"),
                patch.object(importer.transfer, "safe_file"),
                patch.object(importer.transfer, "verify_original", return_value=payload),
                patch.object(importer.transfer.os, "O_NOFOLLOW", 0, create=True),
            ):
                destination = importer.import_copy(mount_point, name, payload)
                self.assertEqual({item.name for item in destination.iterdir()}, set(importer.transfer.NAS_FILES))
                self.assertEqual((destination / "db.dump").read_bytes(), b"fictional:db.dump")
                with self.assertRaisesRegex(RuntimeError, "LOCAL_IMPORT_ALREADY_EXISTS"):
                    importer.import_copy(mount_point, name, payload)

    def test_tampered_nas_data_fails_before_local_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mount_point = root / "nas"
            mount_point.mkdir()
            name = "pilot-scheduled-data-ABCDEFGH-012345abcdef"
            source = mount_point / name
            source.mkdir()
            hashes = {}
            for item in importer.transfer.PAYLOAD:
                content = ("fictional:" + item).encode("ascii")
                (source / item).write_bytes(content)
                hashes[item] = hashlib.sha256(content).hexdigest()
            (source / "NAS_SHA256SUMS").write_text("".join(
                f"{hashes[item]}  {item}\n" for item in importer.transfer.PAYLOAD), encoding="ascii")
            (source / "NAS_TRANSFER_STATE").write_text("NAS_TRANSFER_COMPLETE\n", encoding="ascii")
            (source / "db.dump").write_bytes(b"tampered")
            with (
                patch.object(importer.transfer, "SCHEDULED_ROOT", root),
                patch.object(importer.transfer, "mount"),
                patch.object(importer.transfer, "require_mount"),
                patch.object(importer.transfer, "safe_directory"),
                patch.object(importer.transfer, "safe_file"),
            ):
                with self.assertRaisesRegex(RuntimeError, "EXISTING_NAS_COPY_HASH_MISMATCH"):
                    importer.import_copy(mount_point, name, hashes)
                self.assertFalse(any(item.name.startswith(".nas-import-") for item in root.iterdir()))


if __name__ == "__main__":
    unittest.main()
