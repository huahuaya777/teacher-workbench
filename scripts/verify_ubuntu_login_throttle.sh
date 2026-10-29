#!/usr/bin/env bash
# Disposable PostgreSQL regression and Redis cache probe for the new login code.
# Does not replace running web/worker containers or clear persistent volumes.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

test_dir="$HOME/teacher-workbench-test-9e29fddf"
bundle="$HOME/teacher-workbench-login-throttle-bundle.tar.gz"
expected_bundle_sha="dae312864834705a2dddd6698a1b539ba893f6c820375f080173709c95161d91"
if [[ -L "$test_dir" || ! -d "$test_dir" || -L "$bundle" || ! -f "$bundle" ]]; then
  echo "LOGIN_BUNDLE_OR_TEST_SOURCE_MISSING"
  exit 1
fi
if [[ "$(sha256sum "$bundle" | cut -d ' ' -f 1)" != "$expected_bundle_sha" ]]; then
  echo "LOGIN_BUNDLE_HASH_MISMATCH"
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
sudo docker compose exec -T web python scripts/check_test_env.py --process-env
echo "TEST_STACK_STILL_RUNNING_LOOPBACK_ONLY"

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

stage="$(mktemp -d "$HOME/teacher-workbench-login-throttle-regression.XXXXXXXX")"
chmod 700 "$stage"
python3 - "$bundle" "$stage" <<'PY'
from pathlib import Path
import sys
import tarfile

archive = Path(sys.argv[1])
target = Path(sys.argv[2])
expected = {
    "config/settings.py", "config/urls.py", "config/admin_app.py",
    "config/admin_site.py", "workbench/auth_views.py", "workbench/tests.py",
    "templates/registration/login.html",
}
with tarfile.open(archive, "r:gz") as handle:
    members = handle.getmembers()
    if len(members) != len(expected) or {item.name for item in members} != expected:
        raise SystemExit("LOGIN_BUNDLE_MEMBERS_UNEXPECTED")
    if any(not item.isfile() for item in members):
        raise SystemExit("LOGIN_BUNDLE_NONFILE_REJECTED")
    for item in members:
        output = target / item.name
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(handle.extractfile(item).read())
        output.chmod(0o600)
print("LOGIN_BUNDLE_EXTRACTED_PRIVATE")
PY

mounts=(
  -v "$stage/config/settings.py:/app/config/settings.py:ro"
  -v "$stage/config/urls.py:/app/config/urls.py:ro"
  -v "$stage/config/admin_app.py:/app/config/admin_app.py:ro"
  -v "$stage/config/admin_site.py:/app/config/admin_site.py:ro"
  -v "$stage/workbench/auth_views.py:/app/workbench/auth_views.py:ro"
  -v "$stage/workbench/tests.py:/app/workbench/tests.py:ro"
  -v "$stage/templates/registration/login.html:/app/templates/registration/login.html:ro"
)
# Temporary Django test database only; existing app containers and files unchanged.
sudo docker compose run --rm --no-deps "${mounts[@]}" web \
  python manage.py test workbench --verbosity 1 --noinput
echo "LOGIN_THROTTLE_POSTGRES_REGRESSION_OK"

# Two distinct one-off Python processes use the same Redis cache. The key/value
# are fictional and short-lived; this does not open a user session or call AI.
probe_key="tw-login-cache-probe-$(date +%s)-$$"
sudo docker compose run --rm --no-deps -e DJANGO_DEBUG=0 \
  -v "$stage/config/settings.py:/app/config/settings.py:ro" \
  web python -c 'import os,sys;os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings");from django.core.cache import cache;cache.set(sys.argv[1],"fictional",60)' "$probe_key"
sudo docker compose run --rm --no-deps -e DJANGO_DEBUG=0 \
  -v "$stage/config/settings.py:/app/config/settings.py:ro" \
  web python -c 'import os,sys;os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings");from django.core.cache import cache;key=sys.argv[1];assert cache.get(key)=="fictional","REDIS_SHARED_COUNTER_MISSING";cache.delete(key);print("REDIS_SHARED_COUNTER_OK")' "$probe_key"

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
with opener.open("http://127.0.0.1:18000/login/", timeout=5) as response:
    if response.status != 200 or not response.read():
        raise SystemExit("SOURCE_TEST_LOGIN_UNAVAILABLE")
print("SOURCE_TEST_LOGIN_HTTP_200_AFTER_LOGIN_THROTTLE")
PY
