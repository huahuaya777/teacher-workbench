#!/usr/bin/env bash
# Ubuntu VM 257: verify only the isolated teacher-workbench-test stack.
# Django tests create and remove a separate synthetic PostgreSQL test database.
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
if [[ "$(stat -c %a .env)" != "600" ]]; then
  echo "TEST_ENV_PERMISSIONS_WRONG"
  exit 1
fi

running_services="$(sudo docker compose ps --status running --services)"
for service in db redis web worker; do
  if ! grep -Fxq "$service" <<< "$running_services"; then
    echo "TEST_SERVICE_NOT_RUNNING: $service"
    sudo docker compose ps
    exit 1
  fi
done
web_port="$(sudo docker compose port web 8000)"
if [[ "$web_port" != "127.0.0.1:18000" ]]; then
  echo "TEST_WEB_PORT_NOT_LOOPBACK: $web_port"
  exit 1
fi
echo "TEST_FOUR_SERVICES_RUNNING_LOOPBACK_ONLY"

sudo docker compose exec -T web python manage.py check
sudo docker compose exec -T web python manage.py migrate --check --noinput
echo "TEST_DJANGO_CHECK_AND_MIGRATIONS_OK"

# These tests use fictional material and mocks for every model request. They
# run against a temporary PostgreSQL test database, not the application DB.
sudo docker compose exec -T web python manage.py test --verbosity 1
echo "TEST_POSTGRES_SUITE_OK"

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for path in ("/login/", "/static/workbench/site.css", "/static/workbench/site.js"):
    with opener.open("http://127.0.0.1:18000" + path, timeout=5) as response:
        body = response.read()
        if response.status != 200 or not body:
            raise SystemExit(f"TEST_HTTP_FAILED: {path}")
print("TEST_LOGIN_AND_STATIC_HTTP_200")
PY

sudo docker compose ps
echo "TEST_STACK_SMOKE_OK"
