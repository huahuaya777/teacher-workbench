import base64
import os
from pathlib import Path
import secrets
import stat


DATA = Path("/var/lib/teacher-workbench")
KEYRING = Path("/var/lib/teacher-workbench-keyring")


def read_secret(name):
    info = KEYRING.stat()
    if KEYRING.is_symlink() or stat.S_IMODE(info.st_mode) != 0o700 or info.st_uid != os.geteuid():
        raise RuntimeError("Keyring directory must belong to the runtime user and have mode 700")
    path = KEYRING / name
    if path.is_symlink():
        raise RuntimeError("Keyring files must not be symlinks")
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o600 or info.st_uid != os.geteuid():
        raise RuntimeError("Keyring files must belong to the runtime user and have mode 600")
    value = path.read_text().strip()
    if len(value) < 32:
        raise RuntimeError("Keyring file is invalid")
    if name == "v1.key" and len(base64.b64decode(value, validate=True)) != 32:
        raise RuntimeError("Model encryption key is invalid")
    return value


def initialize_secrets():
    existing_database = (DATA / "postgres" / "PG_VERSION").exists()
    for name, value in (
        ("django-secret", secrets.token_urlsafe(48)),
        ("database-password", secrets.token_urlsafe(36)),
        ("v1.key", base64.b64encode(secrets.token_bytes(32)).decode("ascii")),
    ):
        path = KEYRING / name
        if path.exists() or path.is_symlink():
            read_secret(name)
        elif existing_database:
            raise RuntimeError("Existing database has a missing keyring: restore the matching keyring volume")
        else:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w") as output:
                output.write(value + "\n")


def configure_environment():
    # All processes, including docker exec management commands, read the same files.
    os.environ.update({
        "DJANGO_DEBUG": "0", "DJANGO_SECRET_KEY": read_secret("django-secret"),
        "DB_HOST": "127.0.0.1", "DB_PORT": "5432", "DB_NAME": "workbench", "DB_USER": "workbench",
        "DB_PASSWORD": read_secret("database-password"),
        "REDIS_URL": "redis://127.0.0.1:6379/0", "PRIVATE_FILE_ROOT": str(DATA / "private"),
        "MODEL_KEYRING_DIR": str(KEYRING), "AI_API_KEY": "", "AI_LOCAL_QUEUE": "0",
        "AI_STAGING_MANUAL_QUEUE": "0", "TW_STAGING": "0",
    })
    enabled = os.getenv("TW_ENABLE_MEMBER_AI", "0") == "1"
    os.environ["AI_ENABLED"] = os.environ["AI_MEMBER_TASKS_ENABLED"] = "1" if enabled else "0"
