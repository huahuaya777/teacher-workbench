"""Prepare or copy the latest pilot data snapshot to dedicated NFS.

``verify`` is read-only. ``copy`` requires a separate root-owned policy file
which is intentionally absent until future recurring NAS transfers are
explicitly authorized. This script never copies the paired secret escrow.
"""

from __future__ import annotations

import hashlib
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import uuid


NAS_SOURCE = "10.0.30.6:/teacher-workbench-backup"
MOUNT_PARENT = Path("/mnt")
LOCAL_HOME = Path("/home/huahua")
SCHEDULED_ROOT = Path("/var/lib/teacher-workbench-pilot-scheduled")
POLICY_FILE = Path("/etc/teacher-workbench-pilot-nas-replication.policy")
BACKUP_HEALTH = Path("/usr/local/libexec/teacher-workbench-pilot-backup-health")
POLICY_CONTENT = (
    "VERSION=1\n"
    "TARGET=10.0.30.6:/teacher-workbench-backup\n"
    "SCOPE=all-future-pilot-snapshots\n"
    "COPY_ESCROW=0\n"
)
BACKUP_NAME_PATTERN = re.compile(r"backup-pilot-[A-Za-z0-9]{8}\Z")
PAYLOAD = (
    "db.dump", "private.tar.gz", "redis.tar.gz", "images.tar.gz",
    "source.tar.gz", "IMAGE_IDS", "KEY_SHA256", "CA_SHA256",
    "SHA256SUMS", "STATE",
)
ORIGINAL_HASHED = PAYLOAD[:8]
NAS_FILES = PAYLOAD + ("NAS_SHA256SUMS", "NAS_TRANSFER_STATE")


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def manifest(path: Path, expected: tuple[str, ...]) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None or match[2] in entries:
            raise RuntimeError("MANIFEST_FORMAT_OR_DUPLICATE_UNEXPECTED")
        entries[match[2]] = match[1]
    if set(entries) != set(expected):
        raise RuntimeError("MANIFEST_FILE_SET_UNEXPECTED")
    return entries


def safe_directory(path: Path, owner: int, modes: set[int]) -> None:
    meta = path.lstat()
    if not stat.S_ISDIR(meta.st_mode) or meta.st_uid != owner or stat.S_IMODE(meta.st_mode) not in modes:
        raise RuntimeError("DIRECTORY_OWNER_OR_MODE_UNEXPECTED")


def safe_file(path: Path, owner: int) -> None:
    meta = path.lstat()
    if not stat.S_ISREG(meta.st_mode) or meta.st_uid != owner or stat.S_IMODE(meta.st_mode) != 0o600 or meta.st_size == 0:
        raise RuntimeError("FILE_OWNER_OR_MODE_UNEXPECTED")


def verify_original(path: Path, owner: int) -> dict[str, str]:
    safe_directory(path, owner, {0o700})
    for name in PAYLOAD:
        safe_file(path / name, owner)
    if (path / "STATE").read_text(encoding="ascii") != "PILOT_BACKUP_COMPLETE\n":
        raise RuntimeError("SOURCE_BACKUP_INCOMPLETE")
    hashes = manifest(path / "SHA256SUMS", ORIGINAL_HASHED)
    for name, expected in hashes.items():
        if digest(path / name) != expected:
            raise RuntimeError("SOURCE_BACKUP_HASH_MISMATCH")
    if not re.fullmatch(r"[0-9a-f]{64}\n", (path / "KEY_SHA256").read_text(encoding="ascii")):
        raise RuntimeError("KEY_FINGERPRINT_FORMAT_UNEXPECTED")
    if not re.fullmatch(r"(sha256:[0-9a-f]{64}\n){4}",
                        (path / "IMAGE_IDS").read_text(encoding="ascii")):
        raise RuntimeError("IMAGE_ID_FORMAT_UNEXPECTED")
    if not re.fullmatch(r"[0-9a-f]{64}\n", (path / "CA_SHA256").read_text(encoding="ascii")):
        raise RuntimeError("CA_FINGERPRINT_FORMAT_UNEXPECTED")
    return {name: digest(path / name) for name in PAYLOAD}


def mount_entry(mount_point: Path) -> tuple[str, str, str, str] | None:
    result = subprocess.run(
        ["findmnt", "--mountpoint", str(mount_point), "-n", "-o", "TARGET,SOURCE,FSTYPE,OPTIONS"],
        capture_output=True, text=True, timeout=10, check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    fields = result.stdout.strip().split(None, 3)
    if len(fields) != 4:
        raise RuntimeError("MOUNT_METADATA_UNEXPECTED")
    return tuple(fields)  # type: ignore[return-value]


def require_mount(mount_point: Path, writable: bool) -> None:
    entry = mount_entry(mount_point)
    if entry is None or entry[0] != str(mount_point) or entry[1] != NAS_SOURCE or entry[2] not in {"nfs", "nfs4"}:
        raise RuntimeError("NAS_MOUNT_SOURCE_UNEXPECTED")
    options = set(entry[3].split(","))
    if ("rw" if writable else "ro") not in options:
        raise RuntimeError("NAS_MOUNT_MODE_UNEXPECTED")


def create_file(source: Path, target: Path, expected: str, owner: int | None = None) -> None:
    handle = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with source.open("rb") as input_stream, os.fdopen(handle, "wb") as output_stream:
        shutil.copyfileobj(input_stream, output_stream, 1024 * 1024)
        output_stream.flush()
        os.fsync(output_stream.fileno())
    if owner is not None:
        safe_file(target, owner)
    if digest(target) != expected:
        raise RuntimeError("TRANSFER_FILE_HASH_MISMATCH")


def write_file(path: Path, payload: bytes) -> None:
    handle = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(handle, "wb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def current_source() -> tuple[Path, dict[str, str], str]:
    safe_directory(SCHEDULED_ROOT, 0, {0o700})
    backup_root = SCHEDULED_ROOT / "backups"
    escrow_root = SCHEDULED_ROOT / "escrow"
    safe_directory(backup_root, 0, {0o700})
    safe_directory(escrow_root, 0, {0o700})
    record = backup_root / "LAST_SUCCESS"
    safe_file(record, 0)
    lines = record.read_text(encoding="ascii").splitlines()
    if len(lines) != 2 or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", lines[0]):
        raise RuntimeError("LATEST_RECORD_FORMAT_UNEXPECTED")
    backup = Path(lines[1])
    if backup.parent != backup_root or BACKUP_NAME_PATTERN.fullmatch(backup.name) is None:
        raise RuntimeError("LATEST_BACKUP_PATH_UNEXPECTED")
    saved_at = datetime.strptime(lines[0], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    age = (datetime.now(timezone.utc) - saved_at).total_seconds()
    if age < 0 or age > 36 * 3600:
        raise RuntimeError("LATEST_BACKUP_STALE")
    source_hashes = verify_original(backup, 0)
    suffix = backup.name.removeprefix("backup-pilot-")
    escrow = escrow_root / ("escrow-" + suffix)
    safe_directory(escrow, 0, {0o700})
    escrow_files = ("env.pilot", "v1.key", "caddy_data.tar.gz", "caddy_config.tar.gz")
    for name in escrow_files + ("SHA256SUMS", "STATE"):
        safe_file(escrow / name, 0)
    if (escrow / "STATE").read_text(encoding="ascii") != "PILOT_ESCROW_COMPLETE\n":
        raise RuntimeError("PAIRED_ESCROW_INCOMPLETE")
    escrow_hashes = manifest(escrow / "SHA256SUMS", escrow_files)
    for name, expected in escrow_hashes.items():
        if digest(escrow / name) != expected:
            raise RuntimeError("PAIRED_ESCROW_HASH_MISMATCH")
    if digest(escrow / "v1.key") != (backup / "KEY_SHA256").read_text(encoding="ascii").strip():
        raise RuntimeError("PAIRED_KEY_MISMATCH")
    return backup, source_hashes, "pilot-scheduled-data-" + suffix + "-"


def require_copy_policy() -> None:
    safe_file(POLICY_FILE, 0)
    if POLICY_FILE.read_text(encoding="ascii") != POLICY_CONTENT:
        raise RuntimeError("RECURRING_NAS_SCOPE_NOT_APPROVED")


def require_backup_health() -> None:
    meta = BACKUP_HEALTH.lstat()
    mode = stat.S_IMODE(meta.st_mode)
    if (not stat.S_ISREG(meta.st_mode) or meta.st_uid != 0 or
            mode & 0o022 or not mode & 0o100 or meta.st_size == 0):
        raise RuntimeError("BACKUP_HEALTH_PROGRAM_UNEXPECTED")
    result = subprocess.run([str(BACKUP_HEALTH)], stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, timeout=180, check=False)
    if result.returncode != 0:
        raise RuntimeError("LOCAL_BACKUP_HEALTH_FAILED")


def verify_existing_nas(path: Path, source_hashes: dict[str, str]) -> None:
    safe_directory(path, 65534, {0o700, 0o2700})
    for name in NAS_FILES:
        safe_file(path / name, 65534)
    if (path / "NAS_TRANSFER_STATE").read_text(encoding="ascii") != "NAS_TRANSFER_COMPLETE\n":
        raise RuntimeError("EXISTING_NAS_COPY_INCOMPLETE")
    if manifest(path / "NAS_SHA256SUMS", PAYLOAD) != source_hashes:
        raise RuntimeError("EXISTING_NAS_MANIFEST_MISMATCH")
    for name, expected in source_hashes.items():
        if digest(path / name) != expected:
            raise RuntimeError("EXISTING_NAS_COPY_HASH_MISMATCH")


def copy_to_nas(mount_point: Path, backup: Path, source_hashes: dict[str, str], nas_prefix: str) -> str:
    print("PILOT_RECURRING_NAS_DATA_SOURCE_VERIFIED", flush=True)
    mount(mount_point, writable=True)
    require_mount(mount_point, writable=True)
    safe_directory(mount_point, 65534, {0o700, 0o2700})
    print("PILOT_RECURRING_NAS_MOUNT_VERIFIED", flush=True)
    existing = [path for path in mount_point.iterdir() if path.name.startswith(nas_prefix) and
                re.fullmatch(re.escape(nas_prefix) + r"[0-9a-f]{12}", path.name)]
    if len(existing) > 1:
        raise RuntimeError("MULTIPLE_NAS_COPIES_REQUIRE_REVIEW")
    if existing:
        require_mount(mount_point, writable=True)
        verify_existing_nas(existing[0], source_hashes)
        print("PILOT_RECURRING_NAS_ALREADY_VERIFIED", flush=True)
        return existing[0].name
    payload_bytes = sum((backup / name).stat().st_size for name in PAYLOAD)
    required_bytes = payload_bytes + max(64 * 1024 * 1024, payload_bytes // 10)
    if shutil.disk_usage(mount_point).free < required_bytes:
        raise RuntimeError("NAS_FREE_SPACE_TOO_LOW")
    name = nas_prefix + uuid.uuid4().hex[:12]
    staging = mount_point / (".incoming-" + name)
    final = mount_point / name
    if staging.exists() or final.exists() or staging.is_symlink() or final.is_symlink():
        raise RuntimeError("NAS_TARGET_EXISTS")
    staging.mkdir(mode=0o700)
    safe_directory(staging, 65534, {0o700, 0o2700})
    write_file(staging / "NAS_TRANSFER_STATE", b"INCOMPLETE\n")
    print("PILOT_RECURRING_NAS_STAGING_READY", flush=True)
    for file_name in PAYLOAD:
        require_mount(mount_point, writable=True)
        create_file(backup / file_name, staging / file_name, source_hashes[file_name], owner=65534)
        print(f"PILOT_RECURRING_NAS_FILE_VERIFIED={file_name}", flush=True)
    hashes = "".join(f"{source_hashes[name]}  {name}\n" for name in PAYLOAD)
    write_file(staging / "NAS_SHA256SUMS", hashes.encode("ascii"))
    write_file(staging / "NAS_TRANSFER_STATE.ready", b"NAS_TRANSFER_COMPLETE\n")
    os.replace(staging / "NAS_TRANSFER_STATE.ready", staging / "NAS_TRANSFER_STATE")
    safe_file(staging / "NAS_SHA256SUMS", 65534)
    safe_file(staging / "NAS_TRANSFER_STATE", 65534)
    if manifest(staging / "NAS_SHA256SUMS", PAYLOAD) != source_hashes:
        raise RuntimeError("NAS_MANIFEST_MISMATCH")
    require_mount(mount_point, writable=True)
    staging.rename(final)
    print("PILOT_RECURRING_NAS_DATA_FILES_VERIFIED", flush=True)
    return name




def mount(mount_point: Path, writable: bool) -> None:
    options = "vers=4," + ("rw" if writable else "ro") + ",resvport,nosuid,nodev,noexec"
    try:
        result = subprocess.run(
            ["mount", "-t", "nfs", "-o", options, NAS_SOURCE, str(mount_point)],
            capture_output=True, text=True, timeout=45, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("NAS_MOUNT_TIMEOUT") from exc
    if result.returncode != 0:
        raise RuntimeError("NAS_MOUNT_FAILED")


def clean_up(mount_point: Path) -> bool:
    try:
        if mount_entry(mount_point) is not None:
            result = subprocess.run(["umount", str(mount_point)], capture_output=True, text=True, timeout=30, check=False)
            if result.returncode != 0:
                print("NAS_UNMOUNT_FAILED", flush=True)
                return False
        if mount_entry(mount_point) is not None:
            return False
        mount_point.rmdir()
        print("NAS_MOUNT_CLEANED", flush=True)
        return True
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("NAS_MOUNT_CLEANUP_UNVERIFIED", flush=True)
        return False


def copy_interrupted(signum: int, _frame: object) -> None:
    raise RuntimeError(f"NAS_COPY_INTERRUPTED_SIGNAL_{signum}")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"verify", "copy"}:
        print("USAGE: replicate_ubuntu_pilot_scheduled_nas.py verify | copy")
        return 2
    mode = sys.argv[1]
    if socket.gethostname() != "teacher-workbench" or os.geteuid() != 0:
        print("WRONG_HOST_OR_USER")
        return 2
    if MOUNT_PARENT.is_symlink() or not MOUNT_PARENT.is_dir() or LOCAL_HOME.is_symlink() or not LOCAL_HOME.is_dir():
        print("HOST_DIRECTORY_UNEXPECTED")
        return 2
    try:
        backup, source_hashes, nas_prefix = current_source()
    except (OSError, RuntimeError, UnicodeError, ValueError) as exc:
        print(f"PILOT_RECURRING_NAS_SOURCE_INVALID={exc}", flush=True)
        return 1
    print(f"PILOT_RECURRING_NAS_SOURCE_NAME={backup.name}", flush=True)
    print(f"PILOT_RECURRING_NAS_SOURCE_MANIFEST_SHA256={digest(backup / 'SHA256SUMS')}", flush=True)
    if mode == "verify":
        print("PILOT_RECURRING_NAS_READONLY_PREFLIGHT_OK", flush=True)
        return 0
    try:
        require_copy_policy()
    except FileNotFoundError:
        print("PILOT_RECURRING_NAS_COPY_DISABLED_NO_POLICY", flush=True)
        return 2
    except (OSError, RuntimeError, UnicodeError, ValueError) as exc:
        print(f"PILOT_RECURRING_NAS_COPY_POLICY_INVALID={exc}", flush=True)
        return 2
    try:
        require_backup_health()
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        print(f"PILOT_RECURRING_NAS_BACKUP_HEALTH_INVALID={exc}", flush=True)
        return 2
    if any(shutil.which(name) is None for name in ("mount", "umount", "findmnt")):
        print("NFS_TOOL_MISSING")
        return 2
    if not Path("/sbin/mount.nfs").exists() and not Path("/usr/sbin/mount.nfs").exists():
        print("NFS_CLIENT_MISSING")
        return 2
    os.umask(0o077)
    import fcntl

    lock_fd = os.open(SCHEDULED_ROOT / ".nas-replication.lock",
                      os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(lock_fd)
        print("PILOT_RECURRING_NAS_COPY_ALREADY_RUNNING", flush=True)
        return 2
    print("PILOT_RECURRING_NAS_COPY_START", flush=True)
    mount_point = Path(tempfile.mkdtemp(prefix="teacher-workbench-pilot-nas-", dir=MOUNT_PARENT))
    outcome: str | None = None
    previous_term = signal.signal(signal.SIGTERM, copy_interrupted)
    previous_int = signal.signal(signal.SIGINT, copy_interrupted)
    try:
        try:
            outcome = copy_to_nas(mount_point, backup, source_hashes, nas_prefix)
        except (OSError, subprocess.SubprocessError, RuntimeError, UnicodeError) as exc:
            print(str(exc), flush=True)
        clean = clean_up(mount_point)
    finally:
        signal.signal(signal.SIGTERM, previous_term)
        signal.signal(signal.SIGINT, previous_int)
        os.close(lock_fd)
    if outcome is None or not clean:
        return 1
    print("NAS_BACKUP_NAME=" + outcome, flush=True)
    print("PILOT_RECURRING_NAS_COPY_DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
