"""Prepare only the isolated Ubuntu test directory; never print secrets.

This helper is transferred separately and run on teacher-workbench by huahua.
It verifies the received archive and extracted files before creating .env.
It does not contact Docker, call AI, or start services.
"""

import hashlib
import os
import secrets
import socket
import stat
import tarfile
from pathlib import Path


ARCHIVE_SHA256 = "9e29fddfbf6bd33674406aa0e77155574d69cd09557edc0998ce95ea1104bb4c"
DIRECTORY = "teacher-workbench-test-9e29fddf"
ARCHIVE = "teacher-workbench-test-9e29fddf.tar.gz"
SECRET_PLACEHOLDER = "replace-with-long-random-test-secret"
PASSWORD_PLACEHOLDER = "replace-with-random-test-password"


def prepare(home: Path, *, check_directory_mode: bool = True) -> None:
    archive_path = home / ARCHIVE
    target = home / DIRECTORY
    if target.is_symlink() or not target.is_dir():
        raise SystemExit("Isolated test directory is missing or unsafe.")
    if check_directory_mode and stat.S_IMODE(target.stat().st_mode) != 0o700:
        raise SystemExit("Isolated test directory must have mode 700.")
    if (target / ".env").exists():
        raise SystemExit("Test .env already exists; refusing to overwrite it.")
    if not archive_path.is_file() or hashlib.sha256(archive_path.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise SystemExit("Test archive hash does not match the reviewed bundle.")

    with tarfile.open(archive_path, "r:gz") as archive:
        for item in archive.getmembers():
            if not item.isfile() or item.name.startswith("/") or ".." in Path(item.name).parts:
                raise SystemExit("Test archive has an unsafe member.")
            extracted = target / item.name
            if extracted.is_symlink() or not extracted.is_file():
                raise SystemExit("Extracted test source is missing or unsafe.")
            source = archive.extractfile(item)
            if source is None or source.read() != extracted.read_bytes():
                raise SystemExit("Extracted test source differs from the reviewed archive.")

    example = (target / ".env.example").read_text(encoding="utf-8")
    if example.count(SECRET_PLACEHOLDER) != 1 or example.count(PASSWORD_PLACEHOLDER) != 1:
        raise SystemExit("Test environment template has unexpected placeholders.")
    text = example.replace(SECRET_PLACEHOLDER, secrets.token_hex(32))
    text = text.replace(PASSWORD_PLACEHOLDER, secrets.token_hex(24))
    destination = target / ".env"
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as output:
        output.write(text)
    print("TEST_ENV_CREATED (random test secrets; contents hidden)")


def main() -> None:
    if os.name != "posix" or socket.gethostname() != "teacher-workbench":
        raise SystemExit("This helper runs only as huahua on teacher-workbench.")
    import pwd

    if pwd.getpwuid(os.geteuid()).pw_name != "huahua":
        raise SystemExit("This helper runs only as huahua on teacher-workbench.")
    prepare(Path.home())


if __name__ == "__main__":
    main()
