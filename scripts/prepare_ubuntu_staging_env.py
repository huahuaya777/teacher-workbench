"""Create a fresh private staging env only on the reviewed Ubuntu VM."""

import os
from pathlib import Path
import secrets
import socket
import stat

from check_staging_env import validate
from check_test_env import read_env


def prepare(directory: Path) -> None:
    if directory.is_symlink() or not directory.is_dir() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
        raise SystemExit("STAGING_DIRECTORY_UNSAFE")
    destination = directory / ".env.staging"
    if destination.exists() or destination.is_symlink():
        raise SystemExit("STAGING_ENV_EXISTS_LEAVE_UNCHANGED")
    template = (directory / "staging.env.example").read_text(encoding="utf-8")
    if template.count("replace-with-long-random-staging-secret") != 1:
        raise SystemExit("STAGING_SECRET_TEMPLATE_UNEXPECTED")
    if template.count("replace-with-random-staging-password") != 1:
        raise SystemExit("STAGING_PASSWORD_TEMPLATE_UNEXPECTED")
    output = template.replace("replace-with-long-random-staging-secret", secrets.token_hex(32))
    output = output.replace("replace-with-random-staging-password", secrets.token_hex(24))
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
        handle.write(output)
    values, errors = read_env(destination)
    values.update({
        "TW_STAGING": "1",
        "REDIS_URL": "redis://redis:6379/0",
        "DJANGO_SETTINGS_MODULE": "config.settings_staging",
    })
    errors.extend(validate(values))
    if errors:
        raise SystemExit("STAGING_ENV_VALIDATION_FAILED")
    print("STAGING_ENV_CREATED (random secrets hidden)")


def main() -> None:
    if os.name != "posix" or socket.gethostname() != "teacher-workbench":
        raise SystemExit("WRONG_HOST")
    import pwd

    if pwd.getpwuid(os.geteuid()).pw_name != "huahua":
        raise SystemExit("WRONG_USER")
    prepare(Path.cwd())


if __name__ == "__main__":
    main()
