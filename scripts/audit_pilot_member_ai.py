"""Read-only pilot launch audit. Never prints credentials or personal content."""

import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model

from workbench.models import CallAllowance, CallAttempt, GenerationTask, MemberAccess, ModelCredential


assert settings.AI_ENABLED and settings.AI_MEMBER_TASKS_ENABLED
assert not settings.AI_LOCAL_QUEUE and not settings.AI_STAGING_MANUAL_QUEUE
assert not settings.AI_API_KEY
matches = list(get_user_model().objects.filter(username="huahua"))
assert len(matches) == 1
user = matches[0]
assert user.is_active and not user.is_staff and not user.is_superuser
assert user.has_usable_password() and not user.has_perm("workbench.manage_members")
access = MemberAccess.objects.get(user=user)
assert not access.must_change_password
credential_count = ModelCredential.objects.filter(owner=user).count()
allowance = CallAllowance.objects.filter(owner=user).first()
task_count = GenerationTask.objects.filter(owner=user).count()
print("PILOT_REAL_TEACHER_ACCOUNT_READY")
print(f"PILOT_REAL_TEACHER_CREDENTIAL_COUNT={credential_count}")
if allowance is None:
    print("PILOT_REAL_TEACHER_ALLOWANCE=UNSET")
else:
    print(f"PILOT_REAL_TEACHER_ALLOWANCE_MAX={allowance.max_calls}")
    print(f"PILOT_REAL_TEACHER_ALLOWANCE_USED={allowance.used_calls}")
    print(f"PILOT_REAL_TEACHER_ALLOWANCE_RESERVED={allowance.reserved_calls}")
print(f"PILOT_REAL_TEACHER_TASK_COUNT={task_count}")
print("PILOT_REAL_TEACHER_TASK_STATUSES=" + ",".join(
    GenerationTask.objects.filter(owner=user).order_by("pk").values_list("status", flat=True)))
print("PILOT_REAL_TEACHER_ATTEMPT_STATUSES=" + ",".join(
    CallAttempt.objects.filter(owner=user).order_by("pk").values_list("status", flat=True)))
