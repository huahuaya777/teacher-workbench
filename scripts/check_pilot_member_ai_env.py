"""Fail closed for the EasyTier HTTPS pilot's member-only AI runtime.

This permits member-owned encrypted Qwen credentials and a guarded worker.
There must be no process-wide provider API key or legacy task mode.
"""

import argparse
import os
from pathlib import Path

from check_pilot_env import read_env, validate as validate_pilot


def validate(values: dict[str, str]) -> list[str]:
    baseline = dict(values)
    baseline.update(AI_ENABLED="0", AI_MEMBER_TASKS_ENABLED="0")
    errors = validate_pilot(baseline)
    if values.get("AI_ENABLED") != "1" or values.get("AI_MEMBER_TASKS_ENABLED") != "1":
        errors.append("成员模型任务必须同时明确启用两个开关。")
    if values.get("AI_LOCAL_QUEUE") != "0" or values.get("AI_STAGING_MANUAL_QUEUE") != "0":
        errors.append("正式成员任务不得使用本机或预发布手动队列。")
    if values.get("AI_API_KEY", ""):
        errors.append("不得使用进程级 API Key。")
    if values.get("AI_PROVIDER", "") not in ("", "qwen", "openai-compatible"):
        errors.append("模型供应商设置不符合成员模式。")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="检查私网 HTTPS 成员 AI 设置，不打印密钥")
    parser.add_argument("--env-file", type=Path, default=Path(".env.pilot"))
    parser.add_argument("--process-env", action="store_true")
    args = parser.parse_args()
    values, errors = (dict(os.environ), []) if args.process_env else read_env(args.env_file)
    errors.extend(validate(values))
    if errors:
        for error in errors:
            print("未通过：" + error)
        return 1
    print("PILOT_MEMBER_AI_ENV_FIELDS_OK; 真实 Key 与额度须由账号所有者在页面设置。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
