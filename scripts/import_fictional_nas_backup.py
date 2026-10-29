"""Import the known fictional NAS backup to a new private Ubuntu directory.

Run as ``sudo python3 import_fictional_nas_backup.py`` on Ubuntu 257 from a
huahua SSH login. Mounts only the dedicated NFS export read-only, verifies its
completed snapshot and hashes, copies it into a new local directory, then
unmounts. It never modifies the NAS snapshot or existing local backups.
"""

from __future__ import annotations

import hashlib
import os
import pathlib
import re
import shutil
import socket
import stat
import subprocess
import tempfile
import uuid


NAS_SOURCE = "10.0.30.6:/teacher-workbench-backup"
NAS_BACKUP_NAME = "fictional-backup-NX5wqA1m-dab1c5b855e1"
MOUNT_PARENT = pathlib.Path("/mnt")
MOUNT_OPTIONS = "vers=4,ro,resvport,nosuid,nodev,noexec"
LOCAL_HOME = pathlib.Path("/home/huahua")
LOCAL_IMPORT = LOCAL_HOME / "teacher-workbench-nas-import-dab1c5b855e1"
SOURCE_ARCHIVE_NAME = "teacher-workbench-test-9e29fddf.tar.gz"
PAYLOAD_NAMES = (
    "db.dump",
    "private.tar.gz",
    "SHA256SUMS",
    "SOURCE_SHA256SUMS",
    "STATE",
    SOURCE_ARCHIVE_NAME,
)
ALL_NAMES = PAYLOAD_NAMES + ("NAS_SHA256SUMS", "NAS_TRANSFER_STATE")


def mount_entry(mount_point: pathlib.Path) -> tuple[str, str, str, str] | None:
    result = subprocess.run(
        ["findmnt", "--mountpoint", str(mount_point), "-n", "-o", "TARGET,SOURCE,FSTYPE,OPTIONS"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    fields = result.stdout.strip().split(None, 3)
    if len(fields) != 4:
        raise RuntimeError("MOUNT_METADATA_UNEXPECTED")
    return tuple(fields)  # type: ignore[return-value]


def require_readonly_mount(mount_point: pathlib.Path) -> None:
    entry = mount_entry(mount_point)
    if entry is None or entry[0] != str(mount_point) or entry[1] != NAS_SOURCE or entry[2] not in {"nfs", "nfs4"}:
        raise RuntimeError("NAS_MOUNT_SOURCE_UNEXPECTED")
    if "ro" not in entry[3].split(","):
        raise RuntimeError("NAS_MOUNT_NOT_READONLY")


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_manifest(path: pathlib.Path, expected_names: tuple[str, ...]) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None:
            raise RuntimeError("NAS_MANIFEST_FORMAT_UNEXPECTED")
        digest, name = match.groups()
        if name in entries:
            raise RuntimeError("NAS_MANIFEST_DUPLICATE")
        entries[name] = digest
    if set(entries) != set(expected_names):
        raise RuntimeError("NAS_MANIFEST_FILES_UNEXPECTED")
    return entries


def verify_snapshot(mount_point: pathlib.Path) -> tuple[pathlib.Path, dict[str, str]]:
    require_readonly_mount(mount_point)
    root_meta = mount_point.stat()
    if root_meta.st_uid != 65534 or stat.S_IMODE(root_meta.st_mode) not in {0o700, 0o2700}:
        raise RuntimeError("NAS_ROOT_PERMISSIONS_UNEXPECTED")
    source_dir = mount_point / NAS_BACKUP_NAME
    directory_meta = source_dir.lstat()
    if not stat.S_ISDIR(directory_meta.st_mode) or directory_meta.st_uid != 65534 or stat.S_IMODE(directory_meta.st_mode) not in {0o700, 0o2700}:
        raise RuntimeError("NAS_BACKUP_DIRECTORY_UNSAFE")
    for name in ALL_NAMES:
        metadata = (source_dir / name).lstat()
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 65534 or stat.S_IMODE(metadata.st_mode) != 0o600:
            raise RuntimeError("NAS_BACKUP_FILE_UNSAFE")
    if (source_dir / "NAS_TRANSFER_STATE").read_text(encoding="ascii") != "NAS_TRANSFER_COMPLETE\n":
        raise RuntimeError("NAS_BACKUP_NOT_COMPLETE")
    if (source_dir / "STATE").read_text(encoding="ascii") != "TEST_BACKUP_COMPLETE\n":
        raise RuntimeError("NAS_ORIGINAL_BACKUP_NOT_COMPLETE")
    manifest = parse_manifest(source_dir / "NAS_SHA256SUMS", PAYLOAD_NAMES)
    for name, expected_hash in manifest.items():
        require_readonly_mount(mount_point)
        if sha256_file(source_dir / name) != expected_hash:
            raise RuntimeError("NAS_BACKUP_CHECKSUM_MISMATCH")
    original_manifest = parse_manifest(source_dir / "SHA256SUMS", ("db.dump", "private.tar.gz"))
    for name, expected_hash in original_manifest.items():
        if manifest[name] != expected_hash:
            raise RuntimeError("NAS_ORIGINAL_CHECKSUM_MISMATCH")
    print("NAS_SOURCE_BACKUP_VERIFIED", flush=True)
    return source_dir, manifest


def copy_file(source: pathlib.Path, destination: pathlib.Path, expected_hash: str) -> None:
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with source.open("rb") as input_stream, os.fdopen(fd, "wb") as output_stream:
        shutil.copyfileobj(input_stream, output_stream, 1024 * 1024)
        output_stream.flush()
        os.fsync(output_stream.fileno())
    if sha256_file(destination) != expected_hash or stat.S_IMODE(destination.stat().st_mode) != 0o600:
        raise RuntimeError("LOCAL_IMPORT_CHECKSUM_OR_MODE_MISMATCH")


def import_snapshot(mount_point: pathlib.Path) -> None:
    import pwd  # Linux only; main() rejects other hosts before reaching this.

    try:
        mounted = subprocess.run(
            ["mount", "-t", "nfs", "-o", MOUNT_OPTIONS, NAS_SOURCE, str(mount_point)],
            capture_output=True,
            text=True,
            timeout=45,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("NAS_MOUNT_TIMEOUT") from exc
    if mounted.returncode != 0:
        raise RuntimeError("NAS_MOUNT_FAILED")
    source_dir, manifest = verify_snapshot(mount_point)

    if LOCAL_IMPORT.exists() or LOCAL_IMPORT.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_ALREADY_EXISTS")
    stage = LOCAL_HOME / f".teacher-workbench-nas-import-{uuid.uuid4().hex}"
    stage.mkdir(mode=0o700)
    if stat.S_IMODE(stage.stat().st_mode) != 0o700:
        raise RuntimeError("LOCAL_STAGE_PERMISSIONS_UNEXPECTED")
    print("NAS_LOCAL_IMPORT_STAGING_READY", flush=True)
    for name in ALL_NAMES:
        require_readonly_mount(mount_point)
        expected_hash = manifest[name] if name in manifest else sha256_file(source_dir / name)
        copy_file(source_dir / name, stage / name, expected_hash)
        print(f"NAS_IMPORT_FILE_VERIFIED={name}", flush=True)

    account = pwd.getpwnam("huahua")
    for name in ALL_NAMES:
        os.chown(stage / name, account.pw_uid, account.pw_gid, follow_symlinks=False)
    os.chown(stage, account.pw_uid, account.pw_gid, follow_symlinks=False)
    if LOCAL_IMPORT.exists() or LOCAL_IMPORT.is_symlink():
        raise RuntimeError("LOCAL_IMPORT_ALREADY_EXISTS")
    stage.rename(LOCAL_IMPORT)
    print("NAS_LOCAL_IMPORT_FILES_VERIFIED", flush=True)


def clean_up(mount_point: pathlib.Path) -> bool:
    try:
        entry = mount_entry(mount_point)
        if entry is not None:
            unmounted = subprocess.run(
                ["umount", str(mount_point)],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            if unmounted.returncode != 0:
                print("NAS_UNMOUNT_FAILED", flush=True)
                return False
        if mount_entry(mount_point) is not None:
            print("NAS_MOUNT_LEFT_ACTIVE", flush=True)
            return False
        mount_point.rmdir()
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("NAS_MOUNT_CLEANUP_UNVERIFIED", flush=True)
        return False
    print("NAS_MOUNT_CLEANED", flush=True)
    return True


def main() -> int:
    if socket.gethostname() != "teacher-workbench" or os.environ.get("SUDO_USER") != "huahua" or os.geteuid() != 0:
        print("WRONG_HOST_USER_OR_SUDO")
        return 2
    if not MOUNT_PARENT.is_dir() or MOUNT_PARENT.is_symlink():
        print("MOUNT_PARENT_UNEXPECTED")
        return 2
    if LOCAL_HOME.is_symlink() or not LOCAL_HOME.is_dir():
        print("LOCAL_HOME_UNEXPECTED")
        return 2
    for tool in ("mount", "umount", "findmnt"):
        if shutil.which(tool) is None:
            print("REQUIRED_TOOL_MISSING")
            return 2
    if not pathlib.Path("/sbin/mount.nfs").exists() and not pathlib.Path("/usr/sbin/mount.nfs").exists():
        print("NFS_CLIENT_MISSING")
        return 2
    os.umask(0o077)
    print("NAS_IMPORT_START", flush=True)
    mount_point = pathlib.Path(tempfile.mkdtemp(prefix="teacher-workbench-nas-import-", dir=MOUNT_PARENT))
    imported = False
    try:
        import_snapshot(mount_point)
        imported = True
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        print(str(exc), flush=True)
    cleaned = clean_up(mount_point)
    if imported and cleaned:
        print(f"NAS_LOCAL_IMPORT_DIR={LOCAL_IMPORT}", flush=True)
        print("NAS_IMPORT_DONE", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
