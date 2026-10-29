"""Safety regression for the disabled recurring NAS transfer entry point."""

from contextlib import redirect_stdout
import importlib.util
from io import StringIO
from pathlib import Path
import hashlib
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("replicate_ubuntu_pilot_scheduled_nas.py")
SPEC = importlib.util.spec_from_file_location("pilot_replication", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
replication = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(replication)


class ReplicationAuthorizationTests(unittest.TestCase):
    def test_missing_policy_stops_before_mount_or_copy(self):
        output = StringIO()
        safe_local_directory = Path.cwd()
        with (
            patch.object(replication.sys, "argv", [str(SCRIPT), "copy"]),
            patch.object(replication.socket, "gethostname", return_value="teacher-workbench"),
            patch.object(replication.os, "geteuid", return_value=0, create=True),
            patch.object(replication, "MOUNT_PARENT", safe_local_directory),
            patch.object(replication, "LOCAL_HOME", safe_local_directory),
            patch.object(replication, "current_source", return_value=(
                Path("/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-ABCDEFGH"),
                {}, "pilot-scheduled-data-ABCDEFGH-",
            )),
            patch.object(replication, "digest", return_value="a" * 64),
            patch.object(replication, "require_copy_policy", side_effect=FileNotFoundError),
            patch.object(replication, "mount") as mount,
            patch.object(replication, "copy_to_nas") as copy,
            redirect_stdout(output),
        ):
            self.assertEqual(replication.main(), 2)
        self.assertIn("PILOT_RECURRING_NAS_COPY_DISABLED_NO_POLICY", output.getvalue())
        mount.assert_not_called()
        copy.assert_not_called()

    def test_failed_local_backup_health_stops_before_mount(self):
        output = StringIO()
        safe_local_directory = Path.cwd()
        with (
            patch.object(replication.sys, "argv", [str(SCRIPT), "copy"]),
            patch.object(replication.socket, "gethostname", return_value="teacher-workbench"),
            patch.object(replication.os, "geteuid", return_value=0, create=True),
            patch.object(replication, "MOUNT_PARENT", safe_local_directory),
            patch.object(replication, "LOCAL_HOME", safe_local_directory),
            patch.object(replication, "current_source", return_value=(
                Path("/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-ABCDEFGH"),
                {}, "pilot-scheduled-data-ABCDEFGH-",
            )),
            patch.object(replication, "digest", return_value="a" * 64),
            patch.object(replication, "require_copy_policy"),
            patch.object(replication, "require_backup_health", side_effect=RuntimeError("LOCAL_BACKUP_HEALTH_FAILED")),
            patch.object(replication, "mount") as mount,
            patch.object(replication, "copy_to_nas") as copy,
            redirect_stdout(output),
        ):
            self.assertEqual(replication.main(), 2)
        self.assertIn("PILOT_RECURRING_NAS_BACKUP_HEALTH_INVALID", output.getvalue())
        mount.assert_not_called()
        copy.assert_not_called()

    def test_new_copy_is_verified_then_idempotent_and_tampering_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            mount_point = root / "nas"
            source.mkdir()
            mount_point.mkdir()
            hashes = {}
            for name in replication.PAYLOAD:
                data = ("fixture:" + name).encode("ascii")
                (source / name).write_bytes(data)
                hashes[name] = hashlib.sha256(data).hexdigest()
            prefix = "pilot-scheduled-data-ABCDEFGH-"
            with (
                patch.object(replication, "mount"),
                patch.object(replication, "require_mount"),
                patch.object(replication, "safe_directory"),
                patch.object(replication, "safe_file"),
                patch.object(replication.os, "O_NOFOLLOW", 0, create=True),
            ):
                name = replication.copy_to_nas(mount_point, source, hashes, prefix)
                self.assertEqual(len(name), len(prefix) + 12)
                self.assertEqual((mount_point / name / "NAS_TRANSFER_STATE").read_bytes(),
                                 b"NAS_TRANSFER_COMPLETE\n")
                self.assertEqual(replication.copy_to_nas(mount_point, source, hashes, prefix), name)
                (mount_point / name / "db.dump").write_bytes(b"tampered")
                with self.assertRaisesRegex(RuntimeError, "EXISTING_NAS_COPY_HASH_MISMATCH"):
                    replication.copy_to_nas(mount_point, source, hashes, prefix)


if __name__ == "__main__":
    unittest.main()
