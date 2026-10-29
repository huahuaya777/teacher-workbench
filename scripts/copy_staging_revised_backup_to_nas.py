"""Copy the paired two-version fictional staging snapshot to dedicated OMV NFS.

Run on Ubuntu 257 as ``sudo python3 copy_staging_revised_backup_to_nas.py``
from a huahua SSH login. This reads only the known completed local backup,
checks all source hashes, copies to a new private directory, verifies each
file on NAS, and unmounts. It never reads live Docker volumes or calls AI.
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
MOUNT_PARENT = pathlib.Path("/mnt")
MOUNT_OPTIONS = "vers=4,rw,resvport,nosuid,nodev,noexec"
USER_HOME = pathlib.Path("/home/huahua")
BACKUP_DIR = USER_HOME / "teacher-workbench-staging-backups/backup-revised-X7Bv9cfE"
STAGE_DIR = USER_HOME / "teacher-workbench-staging-1d3ed18b"
SOURCE_ARCHIVE = USER_HOME / "teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
HELPER = USER_HOME / "verify_staging_revised_snapshot.py"
ARCHIVE_NAME = SOURCE_ARCHIVE.name
PATCH_NAME = "teacher-workbench-staging-linebreak-fix-7198283e.tar.gz"
APPLY_NAME = "apply_ubuntu_staging_linebreak_fix.sh"
SNAPSHOT_NAMES = (
    "db.dump",
    "private.tar.gz",
    "SHA256SUMS",
    "SOURCE_SHA256SUMS",
    "STATE",
    "APP_IMAGE_ID",
    ARCHIVE_NAME,
)
COPY_NAMES = SNAPSHOT_NAMES + (PATCH_NAME, APPLY_NAME)


def source_path(name: str) -> pathlib.Path:
    return BACKUP_DIR / name if name in SNAPSHOT_NAMES else USER_HOME / name


def manifest_names(path: pathlib.Path) -> set[str]:
    names: list[str] = []
    for line in path.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"[0-9a-f]{64}  (\S+)", line)
        if match is None:
            raise RuntimeError("SOURCE_MANIFEST_FORMAT_UNEXPECTED")
        names.append(match.group(1))
    if len(names) != len(set(names)):
        raise RuntimeError("SOURCE_MANIFEST_DUPLICATE")
    return set(names)


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


def require_nas_mount(mount_point: pathlib.Path) -> None:
    entry = mount_entry(mount_point)
    if entry is None or entry[0] != str(mount_point) or entry[1] != NAS_SOURCE or entry[2] not in {"nfs", "nfs4"}:
        raise RuntimeError("NAS_MOUNT_SOURCE_UNEXPECTED")
    if "rw" not in entry[3].split(","):
        raise RuntimeError("NAS_MOUNT_NOT_WRITABLE")


def require_safe_source() -> None:
    for directory in (BACKUP_DIR.parent, BACKUP_DIR, STAGE_DIR):
        if directory.is_symlink() or not directory.is_dir() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise RuntimeError("SOURCE_DIRECTORY_UNSAFE")
    if (BACKUP_DIR / "STATE").read_text(encoding="ascii") != "STAGING_REVISED_BACKUP_COMPLETE\n":
        raise RuntimeError("SOURCE_BACKUP_NOT_COMPLETE")
    for name in SNAPSHOT_NAMES:
        source = BACKUP_DIR / name
        metadata = source.lstat()
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size == 0 or stat.S_IMODE(metadata.st_mode) != 0o600:
            raise RuntimeError("SOURCE_FILE_MISSING_OR_UNSAFE")
    for source in (SOURCE_ARCHIVE, HELPER):
        metadata = source.lstat()
        if not stat.S_ISREG(metadata.st_mode):
            raise RuntimeError("SOURCE_HELPER_OR_ARCHIVE_UNSAFE")
    if sha256_file(SOURCE_ARCHIVE) != "1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb":
        raise RuntimeError("SOURCE_ARCHIVE_HASH_MISMATCH")
    if sha256_file(HELPER) != "694036a7e5964915ba143450d03d5dc6ca26320ceebe548626310739a4c06dd1":
        raise RuntimeError("SOURCE_HELPER_HASH_MISMATCH")
    for name, expected in (
        (PATCH_NAME, "7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d"),
        (APPLY_NAME, "11c86b65650f29b4edd21f27c44f766e62cb1e269d6a7f68e9b0b1398fb0019c"),
    ):
        source = USER_HOME / name
        if not stat.S_ISREG(source.lstat().st_mode) or sha256_file(source) != expected:
            raise RuntimeError("RENDER_PATCH_OR_APPLY_SCRIPT_UNSAFE")
    if sha256_file(BACKUP_DIR / ARCHIVE_NAME) != sha256_file(SOURCE_ARCHIVE):
        raise RuntimeError("BACKUP_ARCHIVE_HASH_MISMATCH")
    if manifest_names(BACKUP_DIR / "SHA256SUMS") != {"db.dump", "private.tar.gz", ARCHIVE_NAME}:
        raise RuntimeError("SOURCE_BACKUP_MANIFEST_FILES_UNEXPECTED")
    if manifest_names(BACKUP_DIR / "SOURCE_SHA256SUMS") != {
        str(SOURCE_ARCHIVE), str(HELPER),
        "compose.staging.yaml", "Dockerfile.staging-offline", "config/nginx-staging.conf",
    }:
        raise RuntimeError("SOURCE_CODE_MANIFEST_FILES_UNEXPECTED")
    image_id = (BACKUP_DIR / "APP_IMAGE_ID").read_text(encoding="ascii").strip()
    if len(image_id) != 71 or not image_id.startswith("sha256:") or any(c not in "0123456789abcdef" for c in image_id[7:]):
        raise RuntimeError("BACKUP_IMAGE_ID_UNEXPECTED")
    old_image = subprocess.run(
        ["docker", "image", "inspect", "-f", "{{.Id}}", "teacher-workbench-staging-web:manual-queue-20261017"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if old_image.returncode != 0 or old_image.stdout.strip() != image_id:
        raise RuntimeError("BACKUP_IMAGE_NOT_AVAILABLE")
    for cwd, checksum_file in (
        (BACKUP_DIR, "SHA256SUMS"),
        (STAGE_DIR, str(BACKUP_DIR / "SOURCE_SHA256SUMS")),
    ):
        result = subprocess.run(
            ["sha256sum", "-c", checksum_file],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError("SOURCE_CHECKSUM_MISMATCH")
    print("REVISED_STAGING_SOURCE_BACKUP_VERIFIED", flush=True)


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_new_file(path: pathlib.Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def copy_new_file(source: pathlib.Path, destination: pathlib.Path) -> None:
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with source.open("rb") as input_stream, os.fdopen(fd, "wb") as output_stream:
        shutil.copyfileobj(input_stream, output_stream, 1024 * 1024)
        output_stream.flush()
        os.fsync(output_stream.fileno())
    metadata = destination.stat(follow_symlinks=False)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 65534 or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise RuntimeError("NAS_FILE_PERMISSIONS_UNEXPECTED")
    if sha256_file(source) != sha256_file(destination):
        raise RuntimeError("NAS_COPY_CHECKSUM_MISMATCH")


def copy_to_nas(mount_point: pathlib.Path) -> str:
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
    require_nas_mount(mount_point)
    root_metadata = mount_point.stat()
    if root_metadata.st_uid != 65534 or stat.S_IMODE(root_metadata.st_mode) not in {0o700, 0o2700}:
        raise RuntimeError("NAS_ROOT_PERMISSIONS_UNEXPECTED")
    print("DEDICATED_NAS_MOUNT_VERIFIED", flush=True)

    backup_id = uuid.uuid4().hex[:12]
    stage = mount_point / f".incoming-staging-revised-X7Bv9cfE-{backup_id}"
    final = mount_point / f"staging-revised-X7Bv9cfE-{backup_id}"
    if stage.exists() or final.exists():
        raise RuntimeError("NAS_TARGET_ALREADY_EXISTS")
    stage.mkdir(mode=0o700)
    stage_mode = stat.S_IMODE(stage.stat().st_mode)
    if stage.stat().st_uid != 65534 or stage_mode not in {0o700, 0o2700}:
        raise RuntimeError("NAS_STAGE_PERMISSIONS_UNEXPECTED")
    write_new_file(stage / "NAS_TRANSFER_STATE", b"INCOMPLETE\n")
    print("NAS_STAGING_DIRECTORY_READY", flush=True)

    manifest_lines = []
    for name in COPY_NAMES:
        require_nas_mount(mount_point)
        source = source_path(name)
        destination = stage / name
        copy_new_file(source, destination)
        manifest_lines.append(f"{sha256_file(destination)}  {name}\n")
        print(f"NAS_COPY_FILE_VERIFIED={name}", flush=True)
    write_new_file(stage / "NAS_SHA256SUMS", "".join(manifest_lines).encode("ascii"))
    manifest_check = subprocess.run(
        ["sha256sum", "-c", "NAS_SHA256SUMS"],
        cwd=stage,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    if manifest_check.returncode != 0:
        raise RuntimeError("NAS_MANIFEST_CHECK_FAILED")
    for name in COPY_NAMES:
        source = source_path(name)
        if sha256_file(stage / name) != sha256_file(source):
            raise RuntimeError("NAS_FINAL_CHECKSUM_MISMATCH")
    require_nas_mount(mount_point)
    write_new_file(stage / "NAS_TRANSFER_STATE.ready", b"NAS_TRANSFER_COMPLETE\n")
    os.replace(stage / "NAS_TRANSFER_STATE.ready", stage / "NAS_TRANSFER_STATE")
    state_meta = (stage / "NAS_TRANSFER_STATE").stat()
    if state_meta.st_uid != 65534 or stat.S_IMODE(state_meta.st_mode) != 0o600:
        raise RuntimeError("NAS_STATE_PERMISSIONS_UNEXPECTED")
    if final.exists():
        raise RuntimeError("NAS_TARGET_ALREADY_EXISTS")
    require_nas_mount(mount_point)
    stage.rename(final)
    print("NAS_REVISED_STAGING_FILES_VERIFIED", flush=True)
    return final.name


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
    for tool in ("mount", "umount", "findmnt", "sha256sum", "docker"):
        if shutil.which(tool) is None:
            print("REQUIRED_TOOL_MISSING")
            return 2
    if not pathlib.Path("/sbin/mount.nfs").exists() and not pathlib.Path("/usr/sbin/mount.nfs").exists():
        print("NFS_CLIENT_MISSING")
        return 2
    os.umask(0o077)
    print("NAS_REVISED_STAGING_COPY_START", flush=True)
    try:
        require_safe_source()
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        print(str(exc), flush=True)
        return 1
    mount_point = pathlib.Path(tempfile.mkdtemp(prefix="teacher-workbench-nas-copy-", dir=MOUNT_PARENT))
    copy_name = None
    try:
        copy_name = copy_to_nas(mount_point)
    except (OSError, subprocess.SubprocessError, RuntimeError) as exc:
        print(str(exc), flush=True)
    clean = clean_up(mount_point)
    if copy_name and clean:
        print(f"NAS_BACKUP_NAME={copy_name}", flush=True)
        print("NAS_REVISED_STAGING_COPY_DONE", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
