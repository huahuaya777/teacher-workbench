"""Copy or import the fixed fictional 2B data snapshot through dedicated NFS.

This never copies the separate model master-key file. Run on Ubuntu 257 as
``sudo python3 transfer_staging_phase2b_data_nas.py copy`` or
``sudo python3 transfer_staging_phase2b_data_nas.py import NAS_BACKUP_NAME``.
Only the fictional snapshot X6F4w9bJ is accepted.
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import uuid


NAS_SOURCE = "10.0.30.6:/teacher-workbench-backup"
MOUNT_PARENT = Path("/mnt")
LOCAL_HOME = Path("/home/huahua")
BACKUP_NAME = "backup-phase2b-keys-X6F4w9bJ"
BACKUP_DIR = LOCAL_HOME / "teacher-workbench-staging-backups" / BACKUP_NAME
NAS_PREFIX = "staging-phase2b-data-X6F4w9bJ-"
PAYLOAD = (
    "db.dump", "private.tar.gz", "app-image.tar.gz", "source.tar.gz",
    "APP_IMAGE_ID", "KEY_SHA256", "SHA256SUMS", "STATE",
)
ORIGINAL_HASHED = PAYLOAD[:6]
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
    if (path / "STATE").read_text(encoding="ascii") != "STAGING_2B_CREDENTIAL_BACKUP_COMPLETE\n":
        raise RuntimeError("SOURCE_BACKUP_INCOMPLETE")
    hashes = manifest(path / "SHA256SUMS", ORIGINAL_HASHED)
    for name, expected in hashes.items():
        if digest(path / name) != expected:
            raise RuntimeError("SOURCE_BACKUP_HASH_MISMATCH")
    if not re.fullmatch(r"[0-9a-f]{64}\n", (path / "KEY_SHA256").read_text(encoding="ascii")):
        raise RuntimeError("KEY_FINGERPRINT_FORMAT_UNEXPECTED")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}\n", (path / "APP_IMAGE_ID").read_text(encoding="ascii")):
        raise RuntimeError("IMAGE_ID_FORMAT_UNEXPECTED")
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


def copy_to_nas(mount_point: Path) -> str:
    import pwd  # Linux only; main checks the host before calling this function.

    safe_directory(BACKUP_DIR.parent, pwd.getpwnam("huahua").pw_uid, {0o700})
    source_hashes = verify_original(BACKUP_DIR, pwd.getpwnam("huahua").pw_uid)
    print("STAGING_2B_NAS_DATA_SOURCE_VERIFIED", flush=True)
    mount(mount_point, writable=True)
    require_mount(mount_point, writable=True)
    safe_directory(mount_point, 65534, {0o700, 0o2700})
    print("STAGING_2B_NAS_MOUNT_VERIFIED", flush=True)
    name = NAS_PREFIX + uuid.uuid4().hex[:12]
    staging = mount_point / (".incoming-" + name)
    final = mount_point / name
    if staging.exists() or final.exists() or staging.is_symlink() or final.is_symlink():
        raise RuntimeError("NAS_TARGET_EXISTS")
    staging.mkdir(mode=0o700)
    safe_directory(staging, 65534, {0o700, 0o2700})
    write_file(staging / "NAS_TRANSFER_STATE", b"INCOMPLETE\n")
    print("STAGING_2B_NAS_STAGING_READY", flush=True)
    for file_name in PAYLOAD:
        require_mount(mount_point, writable=True)
        create_file(BACKUP_DIR / file_name, staging / file_name, source_hashes[file_name], owner=65534)
        print(f"STAGING_2B_NAS_FILE_VERIFIED={file_name}", flush=True)
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
    print("STAGING_2B_NAS_DATA_FILES_VERIFIED", flush=True)
    return name


def import_from_nas(mount_point: Path, name: str) -> Path:
    import pwd  # Linux only; main checks the host before calling this function.

    mount(mount_point, writable=False)
    require_mount(mount_point, writable=False)
    safe_directory(mount_point, 65534, {0o700, 0o2700})
    source = mount_point / name
    safe_directory(source, 65534, {0o700, 0o2700})
    for file_name in NAS_FILES:
        safe_file(source / file_name, 65534)
    if (source / "NAS_TRANSFER_STATE").read_text(encoding="ascii") != "NAS_TRANSFER_COMPLETE\n":
        raise RuntimeError("NAS_TRANSFER_INCOMPLETE")
    hashes = manifest(source / "NAS_SHA256SUMS", PAYLOAD)
    for file_name, expected in hashes.items():
        require_mount(mount_point, writable=False)
        if digest(source / file_name) != expected:
            raise RuntimeError("NAS_DATA_HASH_MISMATCH")
    if manifest(source / "SHA256SUMS", ORIGINAL_HASHED) != {n: hashes[n] for n in ORIGINAL_HASHED}:
        raise RuntimeError("NAS_ORIGINAL_MANIFEST_MISMATCH")
    print("STAGING_2B_NAS_DATA_SOURCE_VERIFIED", flush=True)
    destination = LOCAL_HOME / ("teacher-workbench-nas-import-" + name)
    if destination.exists() or destination.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_EXISTS")
    staging = LOCAL_HOME / (".teacher-workbench-nas-import-" + uuid.uuid4().hex)
    staging.mkdir(mode=0o700)
    print("STAGING_2B_NAS_LOCAL_STAGING_READY", flush=True)
    for file_name in NAS_FILES:
        require_mount(mount_point, writable=False)
        create_file(source / file_name, staging / file_name, digest(source / file_name))
        print(f"STAGING_2B_NAS_IMPORT_FILE_VERIFIED={file_name}", flush=True)
    account = pwd.getpwnam("huahua")
    for file_name in NAS_FILES:
        os.chown(staging / file_name, account.pw_uid, account.pw_gid, follow_symlinks=False)
    os.chown(staging, account.pw_uid, account.pw_gid, follow_symlinks=False)
    verify_original(staging, account.pw_uid)
    if manifest(staging / "NAS_SHA256SUMS", PAYLOAD) != {n: digest(staging / n) for n in PAYLOAD}:
        raise RuntimeError("LOCAL_IMPORT_MANIFEST_MISMATCH")
    if (staging / "NAS_TRANSFER_STATE").read_text(encoding="ascii") != "NAS_TRANSFER_COMPLETE\n":
        raise RuntimeError("LOCAL_IMPORT_INCOMPLETE")
    if destination.exists() or destination.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_EXISTS")
    staging.rename(destination)
    print("STAGING_2B_NAS_LOCAL_IMPORT_VERIFIED", flush=True)
    return destination


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


def main() -> int:
    if len(sys.argv) not in {2, 3} or sys.argv[1] not in {"copy", "import"}:
        print("USAGE: transfer_staging_phase2b_data_nas.py copy | import NAS_BACKUP_NAME")
        return 2
    mode = sys.argv[1]
    if (mode == "copy" and len(sys.argv) != 2) or (
        mode == "import" and (len(sys.argv) != 3 or not re.fullmatch(NAS_PREFIX + r"[0-9a-f]{12}", sys.argv[2]))
    ):
        print("NAS_BACKUP_NAME_UNEXPECTED")
        return 2
    if socket.gethostname() != "teacher-workbench" or os.environ.get("SUDO_USER") != "huahua" or os.geteuid() != 0:
        print("WRONG_HOST_USER_OR_SUDO")
        return 2
    if MOUNT_PARENT.is_symlink() or not MOUNT_PARENT.is_dir() or LOCAL_HOME.is_symlink() or not LOCAL_HOME.is_dir():
        print("HOST_DIRECTORY_UNEXPECTED")
        return 2
    if any(shutil.which(name) is None for name in ("mount", "umount", "findmnt")):
        print("NFS_TOOL_MISSING")
        return 2
    if not Path("/sbin/mount.nfs").exists() and not Path("/usr/sbin/mount.nfs").exists():
        print("NFS_CLIENT_MISSING")
        return 2
    os.umask(0o077)
    print("STAGING_2B_NAS_DATA_" + ("COPY" if mode == "copy" else "IMPORT") + "_START", flush=True)
    mount_point = Path(tempfile.mkdtemp(prefix="teacher-workbench-phase2b-nas-", dir=MOUNT_PARENT))
    outcome: str | Path | None = None
    try:
        outcome = copy_to_nas(mount_point) if mode == "copy" else import_from_nas(mount_point, sys.argv[2])
    except (OSError, subprocess.SubprocessError, RuntimeError, UnicodeError) as exc:
        print(str(exc), flush=True)
    clean = clean_up(mount_point)
    if outcome is None or not clean:
        return 1
    print(("NAS_BACKUP_NAME=" if mode == "copy" else "NAS_LOCAL_IMPORT_DIR=") + str(outcome), flush=True)
    print("STAGING_2B_NAS_DATA_" + ("COPY" if mode == "copy" else "IMPORT") + "_DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
