"""Create one fictional non-staff manager in the isolated HTTPS pilot."""

import getpass
import os
import sys


USERNAME = "pilot_manager_20261026"


def main():
    if sys.argv[1:] != ["--create-fictional-pilot-manager"]:
        raise SystemExit("PILOT_MANAGER_CONFIRMATION_REQUIRED")
    if (
        os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings"
        or os.getenv("TW_PILOT") != "1"
        or os.getenv("TW_STAGING")
        or not sys.stdin.isatty()
    ):
        raise SystemExit("PILOT_MANAGER_RUNTIME_OR_TERMINAL_GUARD")

    sys.path.insert(0, "/app")
    import django

    django.setup()
    from django.conf import settings
    from django.contrib.auth import get_user_model
    from django.contrib.auth.models import Permission
    from django.contrib.auth.password_validation import validate_password
    from django.core.exceptions import ValidationError
    from django.db import transaction

    db = settings.DATABASES["default"]
    if not (
        db["ENGINE"] == "django.db.backends.postgresql"
        and db["HOST"] == "db"
        and db["NAME"] == "teacher_workbench_pilot"
        and not settings.DEBUG
        and settings.ALLOWED_HOSTS == ["10.0.30.5"]
        and settings.CSRF_TRUSTED_ORIGINS == ["https://10.0.30.5:18443"]
        and settings.SECURE_SSL_REDIRECT
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and not settings.AI_LOCAL_QUEUE
        and not settings.AI_STAGING_MANUAL_QUEUE
        and not settings.AI_MEMBER_TASKS_ENABLED
    ):
        raise SystemExit("PILOT_MANAGER_SETTINGS_GUARD")

    user_model = get_user_model()
    if user_model.objects.exists():
        raise SystemExit("PILOT_MANAGER_USERS_NOT_EMPTY")
    permission = Permission.objects.get(
        codename="manage_members", content_type__app_label="workbench"
    )

    print(f"仅在独立 HTTPS 试点空库创建虚构管理账号 {USERNAME}。请在当前终端设置密码。")
    password = getpass.getpass("试点账号密码（输入不显示）：")
    confirmation = getpass.getpass("再次输入试点账号密码：")
    if password != confirmation:
        raise SystemExit("PILOT_MANAGER_PASSWORDS_DIFFER")
    user = user_model(username=USERNAME, is_active=True, is_staff=False, is_superuser=False)
    try:
        validate_password(password, user=user)
    except ValidationError as error:
        raise SystemExit("PILOT_MANAGER_PASSWORD_REJECTED: " + "；".join(error.messages)) from error
    user.set_password(password)
    password = None
    confirmation = None
    with transaction.atomic():
        if user_model.objects.exists():
            raise SystemExit("PILOT_MANAGER_USERS_CHANGED")
        user.save(force_insert=True)
        user.user_permissions.add(permission)
    print(f"PILOT_FICTIONAL_MANAGER_READY username={USERNAME} staff=False; password hidden")


if __name__ == "__main__":
    main()
