"""Read-only connectivity and mount survey from Ubuntu VM 257 to the known OMV host.

Prints only booleans/counts. It neither authenticates nor reads/writes NAS files.
"""

from __future__ import annotations

import socket
import subprocess


NAS_HOST = "10.0.30.6"


def port_reachable(port: int) -> bool:
    try:
        with socket.create_connection((NAS_HOST, port), timeout=3):
            return True
    except OSError:
        return False


def mount_counts() -> tuple[int, int] | None:
    try:
        result = subprocess.run(
            ["findmnt", "--noheadings", "--raw", "--types", "nfs,nfs4,cifs", "--output", "SOURCE"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    if result.returncode not in (0, 1):
        return None
    sources = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    matching = sum(
        source.startswith(f"{NAS_HOST}:") or source.startswith(f"//{NAS_HOST}/")
        for source in sources
    )
    return len(sources), matching


def main() -> None:
    print(f"NAS_TARGET={NAS_HOST}")
    print(f"NAS_NFS_TCP_2049={'reachable' if port_reachable(2049) else 'not_reachable'}")
    print(f"NAS_SMB_TCP_445={'reachable' if port_reachable(445) else 'not_reachable'}")
    counts = mount_counts()
    if counts is None:
        print("NETWORK_MOUNT_CHECK=unavailable")
    else:
        total, matching = counts
        print(f"NETWORK_MOUNT_COUNT={total}")
        print(f"NAS_IP_MOUNT_COUNT={matching}")
    print("NAS_READONLY_SURVEY_DONE")


if __name__ == "__main__":
    main()
