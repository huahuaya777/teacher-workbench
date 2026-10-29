"""Fail-closed offline preflight for the separate production draft.

This checks configuration shape only. It cannot prove HTTPS, account security,
backup recovery, or authorize a release. Never print secret values.
"""

import argparse
import os
import re
from ipaddress import ip_address
from pathlib import Path
from urllib.parse import urlsplit

from check_test_env import read_env


PLACEHOLDER = ("replace", "example", "change-me", "development-only", "placeholder")


def valid_hostname(host: str) -> bool:
    if len(host) > 253 or host.startswith(".") or host.endswith("."):
        return False
    try:
        ip_address(host)
    except ValueError:
        pass
    else:
        return False
    labels = host.split(".")
    return len(labels) >= 2 and all(
        re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", part)
        for part in labels
    )


def valid_origin(origin: str, hosts: list[str]) -> bool:
    try:
        parsed = urlsplit(origin)
        return (
            parsed.scheme == "https"
            and parsed.hostname in hosts
            and parsed.port is None
            and parsed.path in ("", "/")
            and not (parsed.query or parsed.fragment or parsed.username or parsed.password)
        )
    except ValueError:
        return False


def validate(values: dict[str, str]) -> list[str]:
    errors: list[str] = []
    if values.get("DJANGO_DEBUG") != "0":
        errors.append("正式配置必须明确设置 DJANGO_DEBUG=0。")
    secret = values.get("DJANGO_SECRET_KEY", "")
    if len(secret) < 50 or any(word in secret.lower() for word in PLACEHOLDER):
        errors.append("DJANGO_SECRET_KEY 缺失、过短或仍是示例值。")
    password = values.get("DB_PASSWORD", "")
    if len(password) < 24 or any(word in password.lower() for word in PLACEHOLDER):
        errors.append("DB_PASSWORD 缺失、过短或仍是示例值。")
    for key in ("DB_NAME", "DB_USER"):
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", values.get(key, "")):
            errors.append(f"{key} 缺失或格式不正确。")
    if values.get("DB_HOST") != "db":
        errors.append("DB_HOST 必须是独立 Compose 数据库服务 db。")

    hosts = [part.strip().lower() for part in values.get("DJANGO_ALLOWED_HOSTS", "").split(",") if part.strip()]
    if not hosts or any(not valid_hostname(host) or host.endswith(".invalid") for host in hosts):
        errors.append("DJANGO_ALLOWED_HOSTS 必须填写实际的完整域名，不能用 IP、通配符或示例域名。")
    origins = [part.strip() for part in values.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if part.strip()]
    if not origins or any(not valid_origin(origin, hosts) for origin in origins):
        errors.append("DJANGO_CSRF_TRUSTED_ORIGINS 必须是与允许域名对应的 HTTPS 根地址。")

    if values.get("DJANGO_SECURE_SSL_REDIRECT") != "1":
        errors.append("必须明确启用 DJANGO_SECURE_SSL_REDIRECT=1。")
    if values.get("DJANGO_TRUST_PROXY_SSL_HEADER") != "1":
        errors.append("必须在确认本项目网关仅接受可信 HTTPS 入口后设置 DJANGO_TRUST_PROXY_SSL_HEADER=1。")
    try:
        hsts_seconds = int(values.get("DJANGO_HSTS_SECONDS", ""))
    except ValueError:
        hsts_seconds = 0
    if hsts_seconds < 3600:
        errors.append("DJANGO_HSTS_SECONDS 至少为 3600，且必须先验证 HTTPS 入口。")
    if values.get("TW_HTTPS_INGRESS_VERIFIED") != "1":
        errors.append("HTTPS 入口尚未现场核验；TW_HTTPS_INGRESS_VERIFIED 不得提前设置为 1。")
    if values.get("AI_ENABLED") != "0" or values.get("AI_API_KEY", ""):
        errors.append("首轮正式配置草案必须关闭 AI，且不保存 API Key。")
    if values.get("AI_LOCAL_QUEUE") != "0":
        errors.append("AI_LOCAL_QUEUE 必须为 0。")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="离线核对正式配置草案；不显示密钥内容")
    parser.add_argument("--env-file", type=Path, default=Path(".env.production"))
    parser.add_argument("--process-env", action="store_true")
    args = parser.parse_args()
    values, errors = (dict(os.environ), []) if args.process_env else read_env(args.env_file)
    errors.extend(validate(values))
    if errors:
        for error in errors:
            print(f"未通过：{error}")
        return 1
    print("正式配置字段通过离线检查；HTTPS、备份、登录限速和发布授权仍需单独验证。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
