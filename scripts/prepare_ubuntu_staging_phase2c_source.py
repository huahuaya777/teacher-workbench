"""Prepare an isolated 2C staging Compose directory; never switch online services.

Run on the designated Ubuntu host after the offline image smoke test. The
caller verifies this file's digest before execution. No model key is read.
"""

from pathlib import Path
import os
import re
import socket
import stat
import sys


HOME = Path("/home/huahua")
OLD = HOME / "teacher-workbench-staging-phase2b-20261020"
IMAGE_STAGE = HOME / "teacher-workbench-staging-phase2c-migration-F6yZnxfi"
NEW = HOME / "teacher-workbench-staging-phase2c-20261022"
OLD_TAG = "teacher-workbench-staging-web:credentials-20261020"
NEW_TAG = "teacher-workbench-staging-web:member-quota-20261022"
EXPECTED_IMAGE_ID = "sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a"


def require(condition: bool, marker: str) -> None:
    if not condition:
        raise SystemExit(marker)


def checked_dir(path: Path) -> None:
    require(path.is_dir() and not path.is_symlink() and
            stat.S_IMODE(path.stat().st_mode) == 0o700,
            "STAGING_2C_PREPARE_DIRECTORY_UNSAFE")


def checked_file(path: Path, mode: int | None = None) -> bytes:
    require(path.is_file() and not path.is_symlink() and
            (mode is None or stat.S_IMODE(path.stat().st_mode) == mode),
            "STAGING_2C_PREPARE_FILE_UNSAFE")
    return path.read_bytes()


def write_exclusive(path: Path, content: bytes, mode: int) -> None:
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, mode)
    with os.fdopen(fd, "wb") as output:
        output.write(content)


def render_compose(compose: str) -> str:
    """Change only the image and explicit AI guard in the known 2B Compose file."""
    require(compose.count(f"    image: {OLD_TAG}\n") == 1 and
            "name: teacher-workbench-staging\n" in compose and
            '      AI_ENABLED: "0"\n' in compose and
            '      AI_API_KEY: ""\n' in compose and
            '      AI_STAGING_MANUAL_QUEUE: "1"\n' in compose and
            '      MODEL_KEYRING_DIR: /run/model-keyring\n' in compose and
            '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro\n' in compose and
            '      - "127.0.0.1:18002:8080"\n' in compose and
            "AI_MEMBER_TASKS_ENABLED" not in compose,
            "STAGING_2C_PREPARE_COMPOSE_MISMATCH")
    require(compose.count("    build:\n      context: .\n      dockerfile: Dockerfile.phase2b-paired\n") == 1,
            "STAGING_2C_PREPARE_BUILD_BLOCK_MISMATCH")

    compose = compose.replace(f"    image: {OLD_TAG}\n",
                              f"    image: {NEW_TAG}\n", 1)
    compose = compose.replace(
        "    build:\n      context: .\n      dockerfile: Dockerfile.phase2b-paired\n", "", 1)
    compose = compose.replace('      AI_STAGING_MANUAL_QUEUE: "1"\n',
                              '      AI_STAGING_MANUAL_QUEUE: "1"\n'
                              '      AI_MEMBER_TASKS_ENABLED: "0"\n', 1)
    require(compose.count(f"    image: {NEW_TAG}\n") == 1 and
            "    build:\n" not in compose and
            compose.count('      AI_MEMBER_TASKS_ENABLED: "0"\n') == 1 and
            not re.search(r"(?m)^\s*AI_MEMBER_TASKS_ENABLED:\s*[\"']?1", compose),
            "STAGING_2C_PREPARE_RESULT_MISMATCH")
    return compose


def main() -> None:
    require(os.name == "posix" and len(sys.argv) == 1,
            "STAGING_2C_PREPARE_WRONG_PLATFORM_OR_ARGS")
    import pwd
    require(socket.gethostname() == "teacher-workbench" and
            pwd.getpwuid(os.geteuid()).pw_name == "huahua" and
            Path.home() == HOME,
            "STAGING_2C_PREPARE_WRONG_HOST_OR_USER")
    checked_dir(OLD)
    checked_dir(IMAGE_STAGE)
    require(not NEW.exists() and not NEW.is_symlink(),
            "STAGING_2C_PREPARE_TARGET_EXISTS")

    state = checked_file(IMAGE_STAGE / "IMAGE_BUILD_STATE", 0o600).decode("ascii")
    image_id = checked_file(IMAGE_STAGE / "APP_IMAGE_ID", 0o600).decode("ascii")
    require(state.strip() == "STAGING_2C_OFFLINE_IMAGE_COMPLETE" and
            image_id.strip() == EXPECTED_IMAGE_ID,
            "STAGING_2C_PREPARE_IMAGE_UNVERIFIED")

    compose = checked_file(OLD / "compose.staging.yaml").decode("utf-8")
    env = checked_file(OLD / ".env.staging", 0o600)
    nginx = checked_file(OLD / "config" / "nginx-staging.conf")
    compose = render_compose(compose)

    prior_umask = os.umask(0o077)
    try:
        NEW.mkdir(mode=0o700)
        (NEW / "config").mkdir(mode=0o700)
        write_exclusive(NEW / "compose.staging.yaml", compose.encode("utf-8"), 0o600)
        write_exclusive(NEW / ".env.staging", env, 0o600)
        write_exclusive(NEW / "config" / "nginx-staging.conf", nginx, 0o600)
        write_exclusive(NEW / "APP_IMAGE_ID", (EXPECTED_IMAGE_ID + "\n").encode("ascii"), 0o600)
        write_exclusive(NEW / "STATE", b"STAGING_2C_CONFIG_PREPARED\n", 0o600)
    finally:
        os.umask(prior_umask)

    print("STAGING_2C_CONFIG_PREPARED_AI_OFF")
    print(f"STAGING_2C_CONFIG_DIR={NEW}")


if __name__ == "__main__":
    main()
