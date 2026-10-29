"""Fail-closed shape check for the isolated EasyTier HTTPS pilot.

This does not prove client trust, network reachability, backup recovery, or
authorize real accounts. Never print secret values.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re


PILOT_HOST = "10.0.30.5"
PILOT_ORIGIN = "https://10.0.30.5:18443"
PLACEHOLDERS = ("replace", "example", "change-me", "development-only", "placeholder")


def validate(values: dict[str, str]) -> list[str]:
    errors: list[str] = []
    if values.get("TW_PILOT") != "1" or values.get("TW_STAGING"):
        errors.append("必须使用独立试运行标记，不能使用预发布设置。")
    if values.get("DJANGO_SETTINGS_MODULE") != "config.settings" or values.get("DJANGO_DEBUG") != "0":
        errors.append("必须使用关闭调试的正式 Django 设置模块。")
    for name, minimum in (("DJANGO_SECRET_KEY", 50), ("DB_PASSWORD", 24)):
        value = values.get(name, "")
        if (len(value) < minimum or len(set(value)) < 6
                or any(word in value.lower() for word in PLACEHOLDERS)):
            errors.append(f"{name} 缺失、强度不足或仍是示例值。")
    if values.get("DB_NAME") != "teacher_workbench_pilot" or values.get("DB_USER") != "teacher_workbench_pilot":
        errors.append("数据库名和用户必须属于独立试运行栈。")
    if values.get("DB_HOST") != "db" or values.get("REDIS_URL") != "redis://redis:6379/0":
        errors.append("数据库与登录限速必须使用独立内部服务。")
    if values.get("DJANGO_ALLOWED_HOSTS") != PILOT_HOST:
        errors.append("只允许指定的 EasyTier 私网入口 IP。")
    if values.get("DJANGO_CSRF_TRUSTED_ORIGINS") != PILOT_ORIGIN:
        errors.append("CSRF 来源必须是试运行 HTTPS 地址及端口。")
    if values.get("DJANGO_SECURE_SSL_REDIRECT") != "1" or values.get("DJANGO_TRUST_PROXY_SSL_HEADER") != "1":
        errors.append("必须在独占 HTTPS 网关后启用安全跳转及受控代理头。")
    if values.get("DJANGO_HSTS_SECONDS") != "3600":
        errors.append("试运行 HSTS 时长必须固定为 3600 秒。")
    if values.get("MODEL_KEYRING_DIR") != "/run/model-keyring" or values.get("MODEL_ACTIVE_KEY_VERSION") != "1":
        errors.append("模型密钥必须使用独立只读密钥目录。")
    keyring = values.get("PILOT_KEYRING_DIR", "")
    if not re.fullmatch(r"/home/huahua/teacher-workbench-pilot-keyring-[A-Za-z0-9]{8}", keyring):
        errors.append("宿主机密钥目录必须是独立的私有绝对路径。")
    for name in ("PILOT_APP_IMAGE", "PILOT_DB_IMAGE", "PILOT_REDIS_IMAGE", "PILOT_CADDY_IMAGE"):
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", values.get(name, "")):
            errors.append(f"{name} 必须锁定到已核对的镜像 ID。")
    if any(values.get(name, "") != "0" for name in (
        "AI_ENABLED", "AI_LOCAL_QUEUE", "AI_STAGING_MANUAL_QUEUE", "AI_MEMBER_TASKS_ENABLED",
    )) or values.get("AI_API_KEY", ""):
        errors.append("试运行必须关闭所有模型调用模式且不含进程级 API Key。")
    return errors


def read_env(path: Path) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}, ["试运行环境文件不可读取。"]
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in line:
            errors.append("试运行环境文件存在无效行。")
            continue
        name, value = line.split("=", 1)
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", name) or name in values:
            errors.append("试运行环境文件存在重复或无效字段。")
        else:
            values[name] = value
    return values, errors


def main() -> int:
    parser = argparse.ArgumentParser(description="只检查独立私网试运行配置，不输出密钥")
    parser.add_argument("--env-file", type=Path, default=Path(".env.pilot"))
    parser.add_argument("--process-env", action="store_true")
    args = parser.parse_args()
    values, errors = (dict(os.environ), []) if args.process_env else read_env(args.env_file)
    errors.extend(validate(values))
    if errors:
        for error in errors:
            print("未通过：" + error)
        return 1
    print("PILOT_ENV_FIELDS_OK; HTTPS 信任、备份与访问仍待现场验证。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
