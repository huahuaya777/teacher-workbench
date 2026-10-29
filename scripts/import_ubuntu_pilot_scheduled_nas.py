"""Import the latest completed pilot snapshot from its read-only NFS copy.

Run as root on Ubuntu 257 with the exact NAS directory name reported by the
replication service. Only the ten data files and two transfer markers are
copied. The paired key, environment and CA escrow stay outside NAS.
"""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import uuid
import hashlib
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader


INSTALLED_TRANSFER = Path("/usr/local/libexec/teacher-workbench-pilot-nas-replication")
EXPECTED_TRANSFER_SHA256 = "4360636fb2ec061211be7739966d9ec7d785ad711f8f4b54e89a2b2440d2a442"


def load_transfer():
    path = (INSTALLED_TRANSFER if socket.gethostname() == "teacher-workbench" else
            Path(__file__).with_name("replicate_ubuntu_pilot_scheduled_nas.py"))
    if path == INSTALLED_TRANSFER:
        meta = path.lstat()
        if not path.is_file() or meta.st_uid != 0 or meta.st_mode & 0o022:
            raise RuntimeError("INSTALLED_TRANSFER_OWNER_OR_MODE_UNEXPECTED")
        if hashlib.sha256(path.read_bytes()).hexdigest() != EXPECTED_TRANSFER_SHA256:
            raise RuntimeError("INSTALLED_TRANSFER_HASH_UNEXPECTED")
    loader = SourceFileLoader("pilot_scheduled_nas_transfer", str(path))
    spec = spec_from_loader(loader.name, loader)
    assert spec is not None
    module = module_from_spec(spec)
    loader.exec_module(module)
    return module


transfer = load_transfer()


def interrupted(signum: int, _frame: object) -> None:
    raise RuntimeError(f"NAS_IMPORT_INTERRUPTED_SIGNAL_{signum}")


def inspect_copy(mount_point: Path, name: str, source_hashes: dict[str, str]) -> Path:
    transfer.mount(mount_point, writable=False)
    transfer.require_mount(mount_point, writable=False)
    transfer.safe_directory(mount_point, 65534, {0o700, 0o2700})
    source = mount_point / name
    transfer.verify_existing_nas(source, source_hashes)
    if {item.name for item in source.iterdir()} != set(transfer.NAS_FILES):
        raise RuntimeError("NAS_FILE_SET_UNEXPECTED")
    print("PILOT_RECURRING_NAS_IMPORT_SOURCE_VERIFIED", flush=True)
    return source


def import_copy(mount_point: Path, name: str, source_hashes: dict[str, str]) -> Path:
    destination = transfer.SCHEDULED_ROOT / ("nas-import-" + name)
    if destination.exists() or destination.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_ALREADY_EXISTS")
    source = inspect_copy(mount_point, name, source_hashes)
    required = sum((source / item).stat().st_size for item in transfer.NAS_FILES)
    if shutil.disk_usage(transfer.SCHEDULED_ROOT).free < required + max(64 * 1024 * 1024, required // 10):
        raise RuntimeError("LOCAL_IMPORT_FREE_SPACE_TOO_LOW")
    staging = transfer.SCHEDULED_ROOT / (".nas-import-" + uuid.uuid4().hex)
    staging.mkdir(mode=0o700)
    print("PILOT_RECURRING_NAS_IMPORT_STAGING_READY", flush=True)
    for item in transfer.NAS_FILES:
        transfer.require_mount(mount_point, writable=False)
        transfer.create_file(source / item, staging / item, transfer.digest(source / item), owner=0)
        print(f"PILOT_RECURRING_NAS_IMPORT_FILE_VERIFIED={item}", flush=True)
    if transfer.verify_original(staging, 0) != source_hashes:
        raise RuntimeError("LOCAL_IMPORT_SOURCE_MISMATCH")
    if transfer.manifest(staging / "NAS_SHA256SUMS", transfer.PAYLOAD) != source_hashes:
        raise RuntimeError("LOCAL_IMPORT_NAS_MANIFEST_MISMATCH")
    if (staging / "NAS_TRANSFER_STATE").read_text(encoding="ascii") != "NAS_TRANSFER_COMPLETE\n":
        raise RuntimeError("LOCAL_IMPORT_INCOMPLETE")
    if destination.exists() or destination.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_ALREADY_EXISTS")
    staging.rename(destination)
    print("PILOT_RECURRING_NAS_LOCAL_IMPORT_VERIFIED", flush=True)
    return destination


def main() -> int:
    if (len(sys.argv) != 3 or sys.argv[1] not in {"verify", "import"} or
            not re.fullmatch(r"pilot-scheduled-data-[A-Za-z0-9]{8}-[0-9a-f]{12}", sys.argv[2])):
        print("USAGE: import_ubuntu_pilot_scheduled_nas.py verify|import NAS_BACKUP_NAME")
        return 2
    mode, name = sys.argv[1:]
    if socket.gethostname() != "teacher-workbench" or os.geteuid() != 0:
        print("WRONG_HOST_OR_USER")
        return 2
    if transfer.MOUNT_PARENT.is_symlink() or not transfer.MOUNT_PARENT.is_dir():
        print("HOST_MOUNT_PARENT_UNEXPECTED")
        return 2
    try:
        backup, source_hashes, prefix = transfer.current_source()
        if not name.startswith(prefix):
            raise RuntimeError("NAS_NAME_NOT_LATEST_SOURCE")
        transfer.safe_directory(transfer.SCHEDULED_ROOT, 0, {0o700})
        if any(shutil.which(item) is None for item in ("mount", "umount", "findmnt")):
            raise RuntimeError("NFS_TOOL_MISSING")
        if not Path("/sbin/mount.nfs").exists() and not Path("/usr/sbin/mount.nfs").exists():
            raise RuntimeError("NFS_CLIENT_MISSING")
    except (OSError, RuntimeError, UnicodeError, ValueError) as exc:
        print(f"PILOT_RECURRING_NAS_IMPORT_PREFLIGHT_FAILED={exc}", flush=True)
        return 1
    print(f"PILOT_RECURRING_NAS_IMPORT_SOURCE_NAME={backup.name}", flush=True)
    os.umask(0o077)
    mount_point = Path(tempfile.mkdtemp(prefix="teacher-workbench-pilot-nas-import-", dir=transfer.MOUNT_PARENT))
    old_term = signal.signal(signal.SIGTERM, interrupted)
    old_int = signal.signal(signal.SIGINT, interrupted)
    result: Path | None = None
    try:
        try:
            result = (inspect_copy(mount_point, name, source_hashes) if mode == "verify" else
                      import_copy(mount_point, name, source_hashes))
        except (OSError, RuntimeError, UnicodeError, subprocess.SubprocessError) as exc:
            print(f"PILOT_RECURRING_NAS_IMPORT_FAILED={exc}", flush=True)
        clean = transfer.clean_up(mount_point)
    finally:
        signal.signal(signal.SIGTERM, old_term)
        signal.signal(signal.SIGINT, old_int)
    if result is None or not clean:
        return 1
    if mode == "verify":
        print("PILOT_RECURRING_NAS_READONLY_VERIFIED", flush=True)
    else:
        print(f"NAS_LOCAL_IMPORT_DIR={result}", flush=True)
        print("PILOT_RECURRING_NAS_IMPORT_DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
