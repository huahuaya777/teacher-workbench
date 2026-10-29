#!/usr/bin/env python3
"""Read-only inventory of paired pilot snapshots and local disk headroom.

The live entry point is fixed to the Ubuntu pilot's root-private directory.
``audit`` accepts a different directory only so isolated fixtures can exercise
the checks. This script never mounts NAS, reads secrets, or removes files.
"""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import socket
import stat
import sys


BASE = Path("/var/lib/teacher-workbench-pilot-scheduled")
SNAPSHOT = re.compile(r"backup-pilot-([A-Za-z0-9]{8})\Z")
GIB = 1024 ** 3
FLOOR_BYTES = 12 * GIB


def checked_directory(path: Path, owner: int) -> None:
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != owner or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError("BACKUP_DIRECTORY_OWNER_OR_MODE_UNEXPECTED")


def checked_file(path: Path, owner: int) -> None:
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != owner or stat.S_IMODE(info.st_mode) != 0o600:
        raise ValueError("BACKUP_FILE_OWNER_OR_MODE_UNEXPECTED")


def tree_bytes(directory: Path, owner: int) -> int:
    total = 0
    pending = [directory]
    while pending:
        current = pending.pop()
        checked_directory(current, owner)
        with os.scandir(current) as entries:
            for entry in entries:
                child = Path(entry.path)
                mode = entry.stat(follow_symlinks=False).st_mode
                if stat.S_ISDIR(mode):
                    pending.append(child)
                elif stat.S_ISREG(mode):
                    checked_file(child, owner)
                    total += entry.stat(follow_symlinks=False).st_size
                else:
                    raise ValueError("BACKUP_ENTRY_TYPE_UNEXPECTED")
    return total


def state(path: Path, owner: int) -> str:
    checked_file(path, owner)
    return path.read_text(encoding="ascii").strip()


def audit(base: Path, owner: int) -> dict[str, int]:
    checked_directory(base, owner)
    backups = base / "backups"
    escrows = base / "escrow"
    checked_directory(backups, owner)
    checked_directory(escrows, owner)
    latest_file = backups / "LAST_SUCCESS"
    checked_file(latest_file, owner)
    latest_lines = latest_file.read_text(encoding="ascii").splitlines()
    if len(latest_lines) != 2 or not re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", latest_lines[0]
    ):
        raise ValueError("LATEST_BACKUP_RECORD_UNEXPECTED")
    latest_path = Path(latest_lines[1])
    if latest_path.parent != backups or SNAPSHOT.fullmatch(latest_path.name) is None:
        raise ValueError("LATEST_BACKUP_PATH_UNEXPECTED")

    complete = incomplete = backup_bytes = escrow_bytes = latest_bytes = 0
    latest_complete = False
    seen_suffixes: set[str] = set()
    for path in backups.iterdir():
        match = SNAPSHOT.fullmatch(path.name)
        if match is None:
            continue
        suffix = match[1]
        seen_suffixes.add(suffix)
        escrow = escrows / f"escrow-{suffix}"
        size = tree_bytes(path, owner)
        backup_bytes += size
        if path == latest_path:
            latest_bytes = size
        if not escrow.exists() and not escrow.is_symlink():
            incomplete += 1
            continue
        escrow_bytes += tree_bytes(escrow, owner)
        paired_complete = state(path / "STATE", owner) == "PILOT_BACKUP_COMPLETE" and state(
            escrow / "STATE", owner
        ) == "PILOT_ESCROW_COMPLETE"
        if paired_complete:
            complete += 1
            if path == latest_path:
                latest_complete = True
        else:
            incomplete += 1
    orphans = 0
    for path in escrows.iterdir():
        if not path.name.startswith("escrow-"):
            continue
        suffix = path.name.removeprefix("escrow-")
        if not re.fullmatch(r"[A-Za-z0-9]{8}", suffix):
            raise ValueError("ESCROW_NAME_UNEXPECTED")
        if suffix not in seen_suffixes:
            tree_bytes(path, owner)
            orphans += 1
    if latest_bytes == 0 or not latest_complete:
        raise ValueError("LATEST_COMPLETE_BACKUP_MISSING")
    free = shutil.disk_usage(base).free
    remaining = max(0, free - FLOOR_BYTES)
    return {
        "complete": complete,
        "incomplete": incomplete,
        "orphan_escrow": orphans,
        "backup_bytes": backup_bytes,
        "escrow_bytes": escrow_bytes,
        "latest_bytes": latest_bytes,
        "free_bytes": free,
        "headroom_bytes": remaining,
        "estimated_more_copies": remaining // latest_bytes,
    }


def main() -> int:
    if len(sys.argv) != 1 or socket.gethostname() != "teacher-workbench" or os.geteuid() != 0:
        print("PILOT_STORAGE_AUDIT_WRONG_HOST_USER_OR_ARGS")
        return 2
    try:
        result = audit(BASE, 0)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"PILOT_STORAGE_AUDIT_FAILED={exc}")
        return 1
    for name, value in result.items():
        print(f"PILOT_STORAGE_{name.upper()}={value}")
    if result["incomplete"] or result["orphan_escrow"] or result["headroom_bytes"] == 0:
        print("PILOT_STORAGE_REVIEW_REQUIRED")
        return 1
    print("PILOT_STORAGE_READONLY_AUDIT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
