"""Create one fictional non-staff manager in the isolated staging database."""

import getpass
import os
import sys
from pathlib import Path


USERNAME = "staging_manager_20261018"


def main():
    if sys.argv[1:] != ["--confirm-staging-manager"]:
        raise SystemExit("STAGING_PHASE2A_MANAGER_CONFIRMATION_REQUIRED")
    if os.getenv("DJANGO_SETTINGS_MODULE") != "config.settings_staging" or os.getenv("TW_STAGING") != "1":
        raise SystemExit("STAGING_PHASE2A_SETTINGS_GUARD")
    if not sys.stdin.isatty():
        raise SystemExit("STAGING_PHASE2A_INTERACTIVE_TERMINAL_REQUIRED")

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
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
        and db["NAME"] == "teacher_workbench_staging"
        and settings.AI_STAGING_MANUAL_QUEUE
        and not settings.AI_ENABLED
        and not settings.AI_API_KEY
        and not settings.AI_LOCAL_QUEUE
    ):
        raise SystemExit("STAGING_PHASE2A_RUNTIME_GUARD")

    user_model = get_user_model()
    if user_model.objects.filter(username__iexact=USERNAME).exists():
        raise SystemExit("STAGING_PHASE2A_MANAGER_ALREADY_EXISTS")
    permission = Permission.objects.get(
        codename="manage_members", content_type__app_label="workbench",
    )
    print(f"只在隔离预发布库创建虚构管理账号 {USERNAME}；请在当前终端设置测试密码。")
    password = getpass.getpass("测试密码（输入不显示）：")
    confirmation = getpass.getpass("再次输入测试密码：")
    if password != confirmation:
        raise SystemExit("STAGING_PHASE2A_PASSWORDS_DIFFER")
    user = user_model(username=USERNAME, is_active=True, is_staff=False, is_superuser=False)
    try:
        validate_password(password, user=user)
    except ValidationError as error:
        raise SystemExit("STAGING_PHASE2A_PASSWORD_REJECTED: " + "；".join(error.messages)) from error
    user.set_password(password)
    password = None
    confirmation = None
    with transaction.atomic():
        user.save(force_insert=True)
        user.user_permissions.add(permission)
    print(f"STAGING_PHASE2A_MANAGER_READY username={USERNAME} staff=False; password hidden")


if __name__ == "__main__":
    main()
