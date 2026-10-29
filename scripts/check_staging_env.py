"""Fail closed on unsafe disposable staging settings; never print secrets."""

import argparse
import os
from pathlib import Path

from check_test_env import read_env, validate as validate_test_env


def validate(values: dict[str, str]) -> list[str]:
    errors = validate_test_env(values)
    if values.get("DB_NAME") != "teacher_workbench_staging":
        errors.append("预发布数据库名称必须独立。")
    if values.get("DB_USER") != "teacher_workbench_staging":
        errors.append("预发布数据库用户必须独立。")
    if values.get("TW_STAGING") != "1":
        errors.append("必须显式设置 TW_STAGING=1。")
    if values.get("REDIS_URL") != "redis://redis:6379/0":
        errors.append("预发布登录计数必须使用独立 Redis 服务。")
    if values.get("DJANGO_SETTINGS_MODULE") != "config.settings_staging":
        errors.append("必须使用预发布设置模块。")
    if "AI_STAGING_MANUAL_QUEUE" in values and values["AI_STAGING_MANUAL_QUEUE"] != "1":
        errors.append("预发布页面必须使用显式手动排队模式；不得自动调用模型。")
    if values.get("DJANGO_SECURE_SSL_REDIRECT", "0") == "1":
        errors.append("回环 HTTP 预发布环境不得强制 HTTPS 重定向。")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="检查独立预发布配置，不输出凭据")
    parser.add_argument("--env-file", type=Path, default=Path(".env.staging"))
    parser.add_argument("--process-env", action="store_true")
    args = parser.parse_args()
    values, errors = (dict(os.environ), []) if args.process_env else read_env(args.env_file)
    if not args.process_env:
        values.update({
            "TW_STAGING": "1",
            "REDIS_URL": "redis://redis:6379/0",
            "DJANGO_SETTINGS_MODULE": "config.settings_staging",
        })
    errors.extend(validate(values))
    if errors:
        for error in errors:
            print("未通过：" + error)
        return 1
    print("独立预发布配置通过离线检查；容器及 HTTP 行为尚未验证。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
