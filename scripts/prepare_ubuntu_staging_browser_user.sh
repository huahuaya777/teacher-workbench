#!/usr/bin/env bash
# One fictional ordinary account in the new staging DB; no existing accounts changed.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
stage="$HOME/teacher-workbench-staging-74586f82"
helper="$HOME/prepare_ubuntu_staging_browser_user.py"
expected_helper_sha="80d55ca1afd582a4c345b8a231c2312486f2ee8320ec9795d2317a66cb71e0a0"
if [[ -L "$stage" || ! -d "$stage" || -L "$helper" || ! -f "$helper" ]]; then
  echo "STAGING_ACCOUNT_PATH_MISSING_OR_UNSAFE"
  exit 1
fi
if [[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" != "$expected_helper_sha" ]]; then
  echo "STAGING_ACCOUNT_HELPER_HASH_MISMATCH"
  exit 1
fi
cd "$stage"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '      - "127.0.0.1:18002:8080"' compose.staging.yaml
if [[ "$(stat -c %a .env.staging)" != "600" ]]; then
  echo "STAGING_ENV_PERMISSIONS_WRONG"
  exit 1
fi
python3 scripts/check_staging_env.py --env-file .env.staging
services="$(sudo docker compose --env-file .env.staging -f compose.staging.yaml ps --status running --services)"
for service in db redis web gateway; do
  if ! grep -Fxq "$service" <<< "$services"; then
    echo "STAGING_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
if [[ "$(sudo docker compose --env-file .env.staging -f compose.staging.yaml port gateway 8080)" != "127.0.0.1:18002" ]]; then
  echo "STAGING_GATEWAY_NOT_LOOPBACK"
  exit 1
fi
sudo docker compose --env-file .env.staging -f compose.staging.yaml run --no-deps --rm \
  -v "$helper:/tmp/prepare_ubuntu_staging_browser_user.py:ro" \
  web python -B /tmp/prepare_ubuntu_staging_browser_user.py --confirm-staging-account
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_OR_SOURCE_LOGIN_NOT_READY")
print("STAGING_AND_SOURCE_LOGIN_HTTP_200")
PY
