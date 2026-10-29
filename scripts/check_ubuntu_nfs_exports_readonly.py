"""Inspect the known OMV NFS export from Ubuntu without mounting or writing.

The result is informational: showmount is an NFS export listing, not an
authorization test. NFSv4 setups may work even when showmount is unavailable.
"""

from __future__ import annotations

import getpass
import pathlib
import shutil
import socket
import subprocess


NAS_HOST = "10.0.30.6"
KNOWN_EXPORT = "/export/backup"


def executable(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for directory in ("/usr/sbin", "/sbin"):
        candidate = pathlib.Path(directory) / name
        if candidate.is_file():
            return str(candidate)
    return None


def known_export_clients(output: str) -> str | None:
    for line in output.splitlines():
        fields = line.split(None, 1)
        if fields and fields[0] == KNOWN_EXPORT:
            return fields[1].strip() if len(fields) == 2 else "(not shown)"
    return None


def main() -> None:
    if socket.gethostname() != "teacher-workbench" or getpass.getuser() != "huahua":
        raise SystemExit("WRONG_HOST_OR_USER")

    print(f"NAS_TARGET={NAS_HOST}")
    print(f"NFS_MOUNT_HELPER={'present' if executable('mount.nfs') else 'absent'}")
    showmount = executable("showmount")
    if not showmount:
        print("NFS_EXPORT_LIST=tool_absent")
        print("NFS_EXPORT_SURVEY_DONE")
        return

    try:
        result = subprocess.run(
            [showmount, "-e", NAS_HOST],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        print("NFS_EXPORT_LIST=unavailable")
        print("NFS_EXPORT_SURVEY_DONE")
        return

    if result.returncode != 0:
        print("NFS_EXPORT_LIST=unavailable")
    else:
        print("NFS_EXPORT_LIST=returned")
        clients = known_export_clients(result.stdout)
        print(f"KNOWN_PVE_BACKUP_EXPORT={'listed' if clients is not None else 'not_listed'}")
        if clients is not None:
            # The ACL is NAS metadata, not a credential. Limit terminal output.
            print(f"KNOWN_EXPORT_CLIENTS={clients[:160]}")
    print("NFS_EXPORT_SURVEY_DONE")


if __name__ == "__main__":
    main()
