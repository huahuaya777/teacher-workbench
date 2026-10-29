"""Create one fictional ordinary account only in the isolated staging DB."""

import getpass
import os
import sys


USERNAME = "staging_preview_20261017"


def main() -> None:
    if sys.argv[1:] != ["--confirm-staging-account"]:
        raise SystemExit("STAGING_ACCOUNT_CONFIRMATION_REQUIRED")
    if (os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings_staging"
            or os.getenv("TW_STAGING") != "1"):
        raise SystemExit("STAGING_SETTINGS_GUARD_FAILED")
    if not sys.stdin.isatty():
        raise SystemExit("STAGING_INTERACTIVE_TERMINAL_REQUIRED")

    sys.path.insert(0, os.getcwd())
    import django

    django.setup()
    from django.conf import settings
    from django.contrib.auth import get_user_model
    from django.contrib.auth.password_validation import validate_password
    from django.core.exceptions import ValidationError
    from django.db import IntegrityError, transaction

    database = settings.DATABASES["default"]
    cache = settings.CACHES["default"]
    if not (
        settings.DEBUG
        and database["ENGINE"] == "django.db.backends.postgresql"
        and database["NAME"] == "teacher_workbench_staging"
        and database["HOST"] == "db"
        and cache["BACKEND"] == "django.core.cache.backends.redis.RedisCache"
        and cache["LOCATION"] == "redis://redis:6379/0"
        and set(settings.ALLOWED_HOSTS) == {"localhost", "127.0.0.1"}
        and os.getenv("PRIVATE_FILE_ROOT") == "/app/data/private"
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and not settings.AI_LOCAL_QUEUE
    ):
        raise SystemExit("STAGING_RUNTIME_GUARD_FAILED")

    user_model = get_user_model()
    if user_model.objects.filter(username=USERNAME).exists():
        raise SystemExit("STAGING_ACCOUNT_ALREADY_EXISTS_LEAVE_UNCHANGED")
    print(f"只在独立预发布库创建普通测试账号 {USERNAME}；请输入新的测试专用密码。")
    password = getpass.getpass("测试密码（输入不显示）：")
    confirmation = getpass.getpass("再次输入测试密码：")
    if password != confirmation:
        raise SystemExit("STAGING_PASSWORDS_DIFFER")
    user = user_model(username=USERNAME, is_active=True, is_staff=False, is_superuser=False)
    try:
        validate_password(password, user=user)
    except ValidationError as error:
        raise SystemExit("STAGING_PASSWORD_REJECTED: " + "；".join(error.messages)) from error
    user.set_password(password)
    password = None
    confirmation = None
    try:
        with transaction.atomic():
            user.save(force_insert=True)
    except IntegrityError as error:
        raise SystemExit("STAGING_ACCOUNT_ALREADY_EXISTS_LEAVE_UNCHANGED") from error
    print(f"STAGING_BROWSER_ACCOUNT_READY username={USERNAME} staff=False; password hidden")


if __name__ == "__main__":
    main()
