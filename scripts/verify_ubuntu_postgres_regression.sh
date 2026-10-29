#!/usr/bin/env bash
# Run the revised fictional regression suite in a disposable web container.
# The running test web/worker containers and their image files are unchanged.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

test_dir="$HOME/teacher-workbench-test-9e29fddf"
tests_file="$HOME/teacher-workbench-postgres-tests.py"
expected_tests_sha="bfb996d948cc239bd267d6308dbb52832fd9f773996c4813f200a9586d16bd66"
if [[ -L "$test_dir" || ! -d "$test_dir" || -L "$tests_file" || ! -f "$tests_file" ]]; then
  echo "TEST_SOURCE_MISSING_OR_UNSAFE"
  exit 1
fi
if [[ "$(sha256sum "$tests_file" | cut -d ' ' -f 1)" != "$expected_tests_sha" ]]; then
  echo "TEST_SOURCE_HASH_MISMATCH"
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
    exit 1
  fi
done
if [[ "$(sudo docker compose port web 8000)" != "127.0.0.1:18000" ]]; then
  echo "TEST_WEB_PORT_NOT_LOOPBACK"
  exit 1
fi
echo "TEST_STACK_STILL_RUNNING_LOOPBACK_ONLY"

sudo docker compose exec -T web python scripts/check_test_env.py --process-env
sudo docker compose exec -T web python - <<'PY'
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
import django
django.setup()
from django.db import connection

if connection.vendor != "postgresql":
    raise SystemExit("POSTGRES_REQUIRED")
test_name = connection.creation._get_test_db_name()
with connection.cursor() as cursor:
    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", [test_name])
    if cursor.fetchone():
        raise SystemExit("TEST_DATABASE_ALREADY_EXISTS_LEAVE_UNCHANGED")
print("DISPOSABLE_TEST_DATABASE_ABSENT")
PY

# Compose run publishes no web port by default. Only the verified test module
# is mounted read-only; no running container or application source is replaced.
sudo docker compose run --rm --no-deps \
  -v "$tests_file:/app/workbench/tests.py:ro" \
  web python manage.py test workbench --verbosity 1 --noinput
echo "POSTGRES_REGRESSION_SUITE_OK"

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
with opener.open("http://127.0.0.1:18000/login/", timeout=5) as response:
    if response.status != 200 or not response.read():
        raise SystemExit("SOURCE_TEST_LOGIN_UNAVAILABLE")
print("SOURCE_TEST_LOGIN_HTTP_200_AFTER_REGRESSION")
PY
