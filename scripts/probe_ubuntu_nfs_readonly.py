"""Read-only, one-time probe of the dedicated OMV NFS export on Ubuntu 257.

Run only as ``sudo python3 probe_ubuntu_nfs_readonly.py`` after installing
``nfs-common``. The script creates a unique local mount point, mounts only the
known workbench export read-only, checks metadata without printing filenames,
then unmounts and removes that empty local mount point.
"""

from __future__ import annotations

import os
import pathlib
import shutil
import socket
import stat
import subprocess
import tempfile


NAS_HOST = "10.0.30.6"
NFS_SOURCE = f"{NAS_HOST}:/teacher-workbench-backup"
MOUNT_PARENT = pathlib.Path("/mnt")
MOUNT_OPTIONS = "vers=4,ro,resvport,nosuid,nodev,noexec"


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


def probe(mount_point: pathlib.Path) -> bool:
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
    if "ro" not in options.split(","):
        print("MOUNT_NOT_READONLY", flush=True)
        return False
    print("DEDICATED_NFS_READONLY_MOUNT_OK", flush=True)
    try:
        metadata = mount_point.stat()
        # Do not expose filenames or file contents from the NAS.
        with os.scandir(mount_point) as entries:
            next(entries, None)
    except OSError:
        print("DEDICATED_NFS_DIRECTORY_ACCESS_FAILED", flush=True)
        return False
    print(f"NFS_ROOT_UID={metadata.st_uid}", flush=True)
    print(f"NFS_ROOT_MODE={stat.S_IMODE(metadata.st_mode):03o}", flush=True)
    # OMV may retain the directory setgid bit (2700). It does not add group
    # access, but descendants inherit the group, so writers must use umask 077.
    mode = stat.S_IMODE(metadata.st_mode)
    if metadata.st_uid != 65534 or mode not in {0o700, 0o2700}:
        print("DEDICATED_NFS_METADATA_UNEXPECTED", flush=True)
        return False
    if mode == 0o2700:
        print("NFS_ROOT_SETGID_PRESENT", flush=True)
    print("DEDICATED_NFS_DIRECTORY_READ_OK", flush=True)
    return True


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

    mount_point = pathlib.Path(tempfile.mkdtemp(prefix="teacher-workbench-nfs-probe-", dir=MOUNT_PARENT))
    os.chmod(mount_point, 0o700)
    print("NFS_READONLY_PROBE_START", flush=True)
    try:
        probe_ok = probe(mount_point)
    except (OSError, subprocess.SubprocessError, RuntimeError):
        print("NFS_READONLY_PROBE_ERROR", flush=True)
        probe_ok = False
    clean_ok = clean_up(mount_point)
    if probe_ok and clean_ok:
        print("NFS_READONLY_PROBE_DONE", flush=True)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
