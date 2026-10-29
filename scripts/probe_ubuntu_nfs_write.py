"""One-time fictional write probe for the dedicated OMV NFS export.

Run as ``sudo python3 probe_ubuntu_nfs_write.py`` on Ubuntu 257 as huahua.
Only a random, fictional probe file is created and removed. No backup data is
read or copied. A failed cleanup is reported and must be inspected manually.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import socket
import stat
import subprocess
import tempfile
import uuid


NAS_HOST = "10.0.30.6"
NFS_SOURCE = f"{NAS_HOST}:/teacher-workbench-backup"
MOUNT_PARENT = pathlib.Path("/mnt")
MOUNT_OPTIONS = "vers=4,rw,resvport,nosuid,nodev,noexec"


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


def write_probe(mount_point: pathlib.Path) -> bool:
    try:
        mounted = subprocess.run(
            ["mount", "-t", "nfs", "-o", MOUNT_OPTIONS, NFS_SOURCE, str(mount_point)],
            capture_output=True,
            text=True,
            timeout=45,
            check=False,
        )
    except subprocess.TimeoutExpired:
        print("MOUNT_TIMEOUT", flush=True)
    else:
        if mounted.returncode != 0:
            print(f"MOUNT_FAILED_EXIT={mounted.returncode}", flush=True)

    entry = mount_entry(mount_point)
    if entry is None:
        print("NFS_NOT_MOUNTED", flush=True)
        return False
    target, source, fs_type, options = entry
    if target != str(mount_point) or source != NFS_SOURCE or fs_type not in {"nfs", "nfs4"}:
        print("MOUNT_SOURCE_UNEXPECTED", flush=True)
        return False
    if "rw" not in options.split(","):
        print("MOUNT_NOT_WRITABLE", flush=True)
        return False

    metadata = mount_point.stat()
    mode = stat.S_IMODE(metadata.st_mode)
    print(f"NFS_ROOT_UID={metadata.st_uid}", flush=True)
    print(f"NFS_ROOT_MODE={mode:03o}", flush=True)
    if metadata.st_uid != 65534 or mode not in {0o700, 0o2700}:
        print("DEDICATED_NFS_METADATA_UNEXPECTED", flush=True)
        return False
    print("DEDICATED_NFS_WRITE_MOUNT_OK", flush=True)

    probe_id = uuid.uuid4().hex
    probe_path = mount_point / f".teacher-workbench-fictional-probe-{probe_id}"
    marker = f"teacher-workbench fictional write probe {probe_id}\n".encode("ascii")
    created = False
    result = False
    try:
        old_umask = os.umask(0o077)
        try:
            fd = os.open(probe_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        finally:
            os.umask(old_umask)
        created = True
        with os.fdopen(fd, "wb") as stream:
            stream.write(marker)
            stream.flush()
            os.fsync(stream.fileno())

        file_meta = probe_path.stat(follow_symlinks=False)
        file_mode = stat.S_IMODE(file_meta.st_mode)
        print(f"NFS_PROBE_FILE_UID={file_meta.st_uid}", flush=True)
        print(f"NFS_PROBE_FILE_MODE={file_mode:03o}", flush=True)
        if not stat.S_ISREG(file_meta.st_mode) or file_meta.st_uid != 65534 or file_mode != 0o600:
            print("NFS_PROBE_FILE_METADATA_UNEXPECTED", flush=True)
        elif probe_path.read_bytes() != marker:
            print("NFS_PROBE_READBACK_MISMATCH", flush=True)
        else:
            print("NFS_FICTIONAL_WRITE_READBACK_OK", flush=True)
            result = True
    except OSError:
        print("NFS_FICTIONAL_WRITE_FAILED", flush=True)
    finally:
        if created:
            try:
                current = probe_path.stat(follow_symlinks=False)
                if stat.S_ISREG(current.st_mode) and current.st_uid == 65534 and probe_path.read_bytes() == marker:
                    probe_path.unlink()
                    print("NFS_PROBE_FILE_REMOVED", flush=True)
                else:
                    print("NFS_PROBE_FILE_LEFT_FOR_REVIEW", flush=True)
                    result = False
            except OSError:
                print("NFS_PROBE_FILE_CLEANUP_FAILED", flush=True)
                result = False
    return result


def clean_up(mount_point: pathlib.Path) -> bool:
    try:
        entry = mount_entry(mount_point)
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("MOUNT_STATE_CHECK_FAILED", flush=True)
        return False
    if entry is not None:
        try:
            unmounted = subprocess.run(
                ["umount", str(mount_point)],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
        except subprocess.TimeoutExpired:
            print("PROBE_UNMOUNT_TIMEOUT", flush=True)
            return False
        if unmounted.returncode != 0:
            print(f"PROBE_UNMOUNT_FAILED_EXIT={unmounted.returncode}", flush=True)
            return False
    try:
        if mount_entry(mount_point) is not None:
            print("PROBE_MOUNT_LEFT_ACTIVE", flush=True)
            return False
        mount_point.rmdir()
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("PROBE_MOUNT_CLEANUP_UNVERIFIED", flush=True)
        return False
    print("PROBE_MOUNT_CLEANED", flush=True)
    return True


def main() -> int:
    if socket.gethostname() != "teacher-workbench" or os.environ.get("SUDO_USER") != "huahua" or os.geteuid() != 0:
        print("WRONG_HOST_USER_OR_SUDO")
        return 2
    if not pathlib.Path("/sbin/mount.nfs").exists() and not pathlib.Path("/usr/sbin/mount.nfs").exists():
        print("NFS_CLIENT_MISSING")
        return 2
    if shutil.which("findmnt") is None or shutil.which("mount") is None or shutil.which("umount") is None:
        print("MOUNT_TOOLS_MISSING")
        return 2
    if not MOUNT_PARENT.is_dir() or MOUNT_PARENT.is_symlink():
        print("MOUNT_PARENT_UNEXPECTED")
        return 2

    mount_point = pathlib.Path(tempfile.mkdtemp(prefix="teacher-workbench-nfs-write-probe-", dir=MOUNT_PARENT))
    os.chmod(mount_point, 0o700)
    print("NFS_WRITE_PROBE_START", flush=True)
    try:
        probe_ok = write_probe(mount_point)
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("NFS_WRITE_PROBE_ERROR", flush=True)
        probe_ok = False
    clean_ok = clean_up(mount_point)
    if probe_ok and clean_ok:
        print("NFS_WRITE_PROBE_DONE", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
