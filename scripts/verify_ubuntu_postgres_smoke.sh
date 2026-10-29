#!/usr/bin/env bash
# Follow-up after the SQLite-specific 35-test suite failed on PostgreSQL.
# Leaves the running stack and its persistent volumes unchanged.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
test_dir="$HOME/teacher-workbench-test-9e29fddf"
if [[ -L "$test_dir" || ! -d "$test_dir" ]]; then
  echo "TEST_DIRECTORY_MISSING_OR_UNSAFE"
  exit 1
fi
cd "$test_dir"
grep -Fxq 'name: teacher-workbench-test' compose.yaml
grep -Fxq '      - "127.0.0.1:18000:8000"' compose.yaml

running_services="$(sudo docker compose ps --status running --services)"
for service in db redis web worker; do
  if ! grep -Fxq "$service" <<< "$running_services"; then
    echo "TEST_SERVICE_NOT_RUNNING: $service"
    sudo docker compose ps
    exit 1
  fi
done
if [[ "$(sudo docker compose port web 8000)" != "127.0.0.1:18000" ]]; then
  echo "TEST_WEB_PORT_NOT_LOOPBACK"
  exit 1
fi
echo "TEST_STACK_STILL_RUNNING"

sudo docker compose exec -T web python - < "$HOME/postgres_smoke.py"

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for path in ("/login/", "/static/workbench/site.css", "/static/workbench/site.js"):
    with opener.open("http://127.0.0.1:18000" + path, timeout=5) as response:
        if response.status != 200 or not response.read():
            raise SystemExit(f"TEST_HTTP_FAILED: {path}")
print("TEST_LOGIN_AND_STATIC_HTTP_200")
PY

echo "TEST_POSTGRES_SMOKE_OK"
