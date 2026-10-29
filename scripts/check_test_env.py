"""Validate the isolated Compose test environment before starting containers.

This is a local preflight check. It never prints secret values or connects to a
server, and it does not make the Compose configuration production-ready.
"""

import argparse
import os
import re
from pathlib import Path


def read_env(path: Path) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except OSError:
        return values, ["环境文件不存在或无法读取。"]

    for number, raw in enumerate(lines, start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            errors.append(f"第 {number} 行不是 KEY=VALUE 格式。")
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            errors.append(f"第 {number} 行的变量名格式不正确。")
            continue
        if key in values:
            errors.append(f"{key} 重复设置。")
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values, errors


def validate(values: dict[str, str]) -> list[str]:
    errors: list[str] = []
    if values.get("DJANGO_DEBUG") != "1":
        errors.append("隔离测试配置必须为 DJANGO_DEBUG=1；正式部署需另建配置。")
    secret = values.get("DJANGO_SECRET_KEY", "")
    if len(secret) < 32 or "replace" in secret.lower() or "development-only" in secret.lower():
        errors.append("DJANGO_SECRET_KEY 缺失、过短或仍为示例值。")
    password = values.get("DB_PASSWORD", "")
    if len(password) < 20 or "replace" in password.lower():
        errors.append("DB_PASSWORD 缺失、过短或仍为示例值。")
    for key in ("DB_NAME", "DB_USER"):
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", values.get(key, "")):
            errors.append(f"{key} 缺失或含不适合测试配置的字符。")
    hosts = {item.strip() for item in values.get("DJANGO_ALLOWED_HOSTS", "").split(",")}
    if hosts != {"localhost", "127.0.0.1"}:
        errors.append("DJANGO_ALLOWED_HOSTS 仅可包含 localhost 和 127.0.0.1。")
    if values.get("AI_ENABLED") != "0":
        errors.append("隔离测试栈必须保持 AI_ENABLED=0。")
    if values.get("AI_API_KEY", ""):
        errors.append("隔离测试栈的 AI_API_KEY 必须为空，不能在 .env 保存真实 Key。")
    if values.get("AI_LOCAL_QUEUE") != "0":
        errors.append("Docker 测试栈必须保持 AI_LOCAL_QUEUE=0。")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="离线核对 Compose 测试环境；不显示密钥内容")
    parser.add_argument("--env-file", type=Path, default=Path(".env"))
    parser.add_argument("--process-env", action="store_true", help="检查当前进程环境，供测试容器启动时使用")
    args = parser.parse_args()
    values, errors = (dict(os.environ), []) if args.process_env else read_env(args.env_file)
    errors.extend(validate(values))
    if errors:
        for error in errors:
            print(f"未通过：{error}")
        return 1
    print("隔离测试环境的必需设置通过离线检查；容器运行、备份和恢复仍待验证。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
