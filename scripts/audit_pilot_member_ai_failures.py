"""Read-only, fixed-label classification of pilot member failures."""

import os
import re

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.contrib.auth import get_user_model
from workbench.models import CallAttempt, GenerationTask

owner = get_user_model().objects.get(username="huahua")
tasks = list(GenerationTask.objects.filter(owner=owner).order_by("pk"))
attempts = list(CallAttempt.objects.filter(owner=owner).order_by("pk"))
assert len(tasks) == len(attempts)
for index, (task, attempt) in enumerate(zip(tasks, attempts), start=1):
    message = task.error_message or ""
    status = "UNKNOWN"
    if re.search(r"HTTP (\d{3})", message):
        status = "HTTP_" + re.search(r"HTTP (\d{3})", message).group(1)
    elif "不是有效 JSON" in message:
        status = "INVALID_JSON"
    elif "返回结构不符合要求" in message:
        status = "RESPONSE_SHAPE"
    elif any(word in message for word in ("题目", "题干", "答案", "标题", "格式不符合要求")):
        status = "CONTENT_VALIDATION"
    elif "超时" in message:
        status = "TIMEOUT"
    elif "无法连接模型服务" in message:
        status = "CONNECTIVITY"
    elif "模型请求或结果处理失败" in message:
        status = "GENERIC"
    print(f"PILOT_FAILURE_{index}_TASK={task.status}")
    print(f"PILOT_FAILURE_{index}_ATTEMPT={attempt.status}")
    print(f"PILOT_FAILURE_{index}_CLASS={status}")
