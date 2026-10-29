"""Create one non-privileged fictional login in the isolated Ubuntu test database.

Run only through prepare_ubuntu_browser_preview_user.sh. The password is read
from a terminal without echo and is never printed or written to a file.
"""

from __future__ import annotations

import getpass
import os
import sys

sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction


USERNAME = "browser_preview_20261017"


def require_isolated_test_runtime() -> None:
    database = settings.DATABASES["default"]
    if not (
        settings.DEBUG
        and database["ENGINE"] == "django.db.backends.postgresql"
        and database["HOST"] == "db"
        and set(settings.ALLOWED_HOSTS) == {"localhost", "127.0.0.1"}
        and os.environ.get("PRIVATE_FILE_ROOT") == "/app/data/private"
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and not settings.AI_LOCAL_QUEUE
    ):
        raise SystemExit("PREVIEW_TEST_RUNTIME_GUARD_FAILED; no account created")


def main() -> None:
    if sys.argv[1:] != ["--confirm-test-account"]:
        raise SystemExit("PREVIEW_EXPLICIT_CONFIRMATION_REQUIRED; no account created")
    require_isolated_test_runtime()
    if not sys.stdin.isatty():
        raise SystemExit("PREVIEW_INTERACTIVE_TERMINAL_REQUIRED; no account created")

    user_model = get_user_model()
    if user_model.objects.filter(username=USERNAME).exists():
        raise SystemExit("PREVIEW_ACCOUNT_ALREADY_EXISTS; no password changed")

    print(f"只为隔离测试库创建普通账号 {USERNAME}；请在本机终端输入新的测试密码。")
    password = getpass.getpass("测试密码（输入不显示）：")
    confirmation = getpass.getpass("再次输入测试密码：")
    if password != confirmation:
        raise SystemExit("PREVIEW_PASSWORDS_DIFFER; no account created")

    user = user_model(username=USERNAME, is_active=True, is_staff=False, is_superuser=False)
    try:
        validate_password(password, user=user)
    except ValidationError as exc:
        raise SystemExit("PREVIEW_PASSWORD_REJECTED: " + "；".join(exc.messages)) from exc
    user.set_password(password)
    password = None
    confirmation = None
    try:
        with transaction.atomic():
            user.save(force_insert=True)
    except IntegrityError as exc:
        raise SystemExit("PREVIEW_ACCOUNT_ALREADY_EXISTS; no password changed") from exc

    print(f"PREVIEW_TEST_ACCOUNT_READY username={USERNAME} staff=False; password hidden")


if __name__ == "__main__":
    main()
