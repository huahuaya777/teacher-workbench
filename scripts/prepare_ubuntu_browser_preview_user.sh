#!/usr/bin/env bash
# One fictional browser-login account in the existing loopback-only test stack.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

test_dir="$HOME/teacher-workbench-test-9e29fddf"
helper="$HOME/prepare_ubuntu_browser_preview_user.py"
if [[ -L "$test_dir" || ! -d "$test_dir" || -L "$helper" || ! -f "$helper" ]]; then
  echo "PREVIEW_TEST_PATH_MISSING_OR_UNSAFE"
  exit 1
fi

cd "$test_dir"
grep -Fxq 'name: teacher-workbench-test' compose.yaml
grep -Fxq '      - "127.0.0.1:18000:8000"' compose.yaml

running_services="$(sudo docker compose ps --status running --services)"
for service in db redis web worker; do
  if ! grep -Fxq "$service" <<< "$running_services"; then
    echo "PREVIEW_TEST_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
if [[ "$(sudo docker compose port web 8000)" != "127.0.0.1:18000" ]]; then
  echo "PREVIEW_TEST_WEB_NOT_LOOPBACK"
  exit 1
fi

sudo docker compose run --no-deps --rm \
  -v "$helper:/tmp/prepare_ubuntu_browser_preview_user.py:ro" \
  web python -B /tmp/prepare_ubuntu_browser_preview_user.py --confirm-test-account

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

with build_opener(ProxyHandler({})).open("http://127.0.0.1:18000/login/", timeout=5) as response:
    if response.status != 200:
        raise SystemExit("PREVIEW_LOGIN_HTTP_NOT_200")
print("PREVIEW_LOGIN_HTTP_200")
PY
