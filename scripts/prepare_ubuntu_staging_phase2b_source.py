"""Stage a reviewed 2B source bundle beside the current 2A staging directory.

Run on Ubuntu 257 only after the 2A paired backup and independent restore.
The caller verifies this helper and the bundle hashes before execution.
"""

from pathlib import Path, PurePosixPath
import os
import socket
import stat
import sys
import tarfile


OLD = Path("/home/huahua/teacher-workbench-staging-phase2a-1bf5a500")
NEW = Path("/home/huahua/teacher-workbench-staging-phase2b-20261020")
BUNDLE = Path("/home/huahua/teacher-workbench-staging-phase2b.tar.gz")
KEYRING = "/home/huahua/teacher-workbench-staging-model-keyring"
OLD_TAG = "teacher-workbench-staging-web:manual-queue-20261017"
NEW_TAG = "teacher-workbench-staging-web:credentials-20261020"


def render_compose(content):
    replacements = (
        (f"image: {OLD_TAG}", f"image: {NEW_TAG}"),
        ("dockerfile: Dockerfile.staging-offline", "dockerfile: Dockerfile.phase2b-paired"),
        ('      AI_STAGING_MANUAL_QUEUE: "1"',
         '      AI_STAGING_MANUAL_QUEUE: "1"\n'
         '      MODEL_KEYRING_DIR: /run/model-keyring\n'
         '      MODEL_ACTIVE_KEY_VERSION: "1"'),
        ("      - staging_private:/app/data/private",
         f"      - {KEYRING}:/run/model-keyring:ro\n"
         "      - staging_private:/app/data/private"),
    )
    for before, after in replacements:
        if content.count(before) != 1:
            raise ValueError("STAGING_PHASE2B_COMPOSE_TEMPLATE_MISMATCH")
        content = content.replace(before, after)
    return content


def main():
    if os.name != "posix" or len(sys.argv) != 1:
        raise SystemExit("STAGING_PHASE2B_WRONG_HOST_USER_OR_ARGS")
    import pwd
    if (socket.gethostname() != "teacher-workbench"
            or pwd.getpwuid(os.geteuid()).pw_name != "huahua"
            or str(Path.home()) != "/home/huahua"):
        raise SystemExit("STAGING_PHASE2B_WRONG_HOST_USER_OR_ARGS")
    if (OLD.is_symlink() or not OLD.is_dir() or stat.S_IMODE(OLD.stat().st_mode) != 0o700
            or BUNDLE.is_symlink() or not BUNDLE.is_file() or NEW.exists() or NEW.is_symlink()):
        raise SystemExit("STAGING_PHASE2B_SOURCE_PATH_UNSAFE")
    env_source = OLD / ".env.staging"
    if env_source.is_symlink() or not env_source.is_file() or stat.S_IMODE(env_source.stat().st_mode) != 0o600:
        raise SystemExit("STAGING_PHASE2B_OLD_ENV_UNSAFE")

    with tarfile.open(BUNDLE, "r:gz") as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        if len(names) != 95 or len(names) != len(set(names)):
            raise SystemExit("STAGING_PHASE2B_BUNDLE_MANIFEST_MISMATCH")
        for member in members:
            name = PurePosixPath(member.name)
            if (name.is_absolute() or ".." in name.parts or not member.isfile()
                    or member.size > 20_000_000 or member.name.startswith("data/")
                    or member.name.endswith((".key", ".env.staging"))):
                raise SystemExit("STAGING_PHASE2B_BUNDLE_MEMBER_UNSAFE")
        required = {
            "manage.py", "requirements.txt", "compose.staging.yaml",
            "config/settings.py", "workbench/credential_vault.py",
            "workbench/migrations/0005_modelcredential.py", "workbench/tests_credentials.py",
            "scripts/check_staging_env.py",
        }
        if not required.issubset(names):
            raise SystemExit("STAGING_PHASE2B_BUNDLE_INCOMPLETE")
        old_mask = os.umask(0o077)
        try:
            NEW.mkdir(mode=0o700)
            archive.extractall(NEW, filter="data")
        finally:
            os.umask(old_mask)

    try:
        content = render_compose((NEW / "compose.staging.yaml").read_text(encoding="utf-8"))
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    (NEW / "compose.staging.yaml").write_text(content, encoding="utf-8", newline="\n")
    dockerfile = """FROM teacher-workbench-staging-web:accounts-20261018
WORKDIR /app
COPY wheelhouse/ /wheelhouse/
RUN pip install --no-cache-dir --no-index --find-links=/wheelhouse cryptography==50.0.2 && rm -rf /wheelhouse
COPY requirements.txt ./requirements.txt
COPY manage.py ./
COPY config/ ./config/
COPY workbench/ ./workbench/
COPY templates/ ./templates/
COPY scripts/check_staging_env.py ./scripts/check_staging_env.py
"""
    (NEW / "Dockerfile.phase2b-paired").write_text(dockerfile, encoding="utf-8", newline="\n")
    fd = os.open(NEW / ".env.staging", os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "wb") as output:
        output.write(env_source.read_bytes())
    if (stat.S_IMODE(NEW.stat().st_mode) != 0o700
            or stat.S_IMODE((NEW / ".env.staging").stat().st_mode) != 0o600):
        raise SystemExit("STAGING_PHASE2B_NEW_SOURCE_PERMISSIONS_UNSAFE")
    print("STAGING_PHASE2B_SOURCE_AND_COMPOSE_READY")
    print(f"STAGING_PHASE2B_NEW_DIR={NEW}")


if __name__ == "__main__":
    main()
