"""Create one random staging-only master key outside the code and database.

This file is preparation for a future reviewed staging deployment. It is not
called by the app or by any current deployment script.
"""

import base64
import os
from pathlib import Path
import secrets
import socket
import stat
import sys


def main():
    if os.name != "posix":
        raise SystemExit("WRONG_HOST_USER_OR_ARGS")
    import pwd
    if (socket.gethostname() != "teacher-workbench"
            or pwd.getpwuid(os.geteuid()).pw_name != "huahua" or str(Path.home()) != "/home/huahua"
            or len(sys.argv) != 1):
        raise SystemExit("WRONG_HOST_USER_OR_ARGS")
    directory = Path("/home/huahua/teacher-workbench-staging-model-keyring")
    if directory.exists() or directory.is_symlink():
        raise SystemExit("STAGING_MODEL_KEYRING_ALREADY_EXISTS")
    old_mask = os.umask(0o077)
    try:
        directory.mkdir(mode=0o700)
        if stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise SystemExit("STAGING_MODEL_KEYRING_DIRECTORY_UNSAFE")
        path = directory / "v1.key"
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
        try:
            with os.fdopen(fd, "wb", closefd=False) as target:
                target.write(base64.b64encode(secrets.token_bytes(32)) + b"\n")
                target.flush()
                os.fsync(target.fileno())
        finally:
            os.close(fd)
        if stat.S_IMODE(path.stat().st_mode) != 0o600:
            raise SystemExit("STAGING_MODEL_KEYRING_FILE_UNSAFE")
    finally:
        os.umask(old_mask)
    print("STAGING_MODEL_KEYRING_V1_READY (value hidden)")


if __name__ == "__main__":
    main()
