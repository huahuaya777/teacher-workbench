#!/usr/bin/env bash
# Hide technical Django errors on the SSH-only fictional staging site.
# Base HTTP cookies and manual queue remain unchanged; no schema migration.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_ERRORS_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

old="$HOME/teacher-workbench-staging-call-usage-online-14537acaacc6"
candidate="$HOME/teacher-workbench-staging-call-usage-14537acaacc6"
new="$HOME/teacher-workbench-staging-errors-20261022"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2c-allowance-DgfGf130"
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-DgfGf130"
settings_file="$HOME/settings_staging_generic_errors.py"
command_file="$HOME/run_staging_task_generic_errors.py"
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1
old_tag=teacher-workbench-staging-web:call-usage-14537acaacc6
new_tag=teacher-workbench-staging-web:generic-errors-20261022
old_id=sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26
settings_sha=ea646093d5c44b8c8f9065e245ab920deaffacefddeec61616d77302c8906b5b
command_sha=2359750301f4343fc30948c64f599d9c04903b42976b5d7c4e1ff8cf4887d02b

for directory in "$old" "$candidate" "$backup" "$escrow"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]] || {
    echo STAGING_ERRORS_DIRECTORY_UNSAFE
    exit 1
  }
done
[[ ! -e "$new" && ! -L "$new" ]] || { echo STAGING_ERRORS_TARGET_EXISTS; exit 1; }
for file in "$old/.env.staging" "$old/compose.staging.yaml" \
            "$old/config/nginx-staging.conf" "$old/APP_IMAGE_ID" "$old/STATE" \
            "$candidate/APP_IMAGE_ID" "$backup/SHA256SUMS" "$backup/STATE" \
            "$backup/KEY_SHA256" "$backup/APP_IMAGE_ID" "$escrow/STATE" \
            "$escrow/SHA256SUMS" "$escrow/v1.key"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]] || {
    echo STAGING_ERRORS_FILE_UNSAFE
    exit 1
  }
done
[[ ! -L "$settings_file" && -f "$settings_file" &&
   "$(sha256sum "$settings_file" | cut -d ' ' -f 1)" == "$settings_sha" ]] || {
  echo STAGING_ERRORS_SETTINGS_SOURCE_UNSAFE
  exit 1
}
[[ ! -L "$command_file" && -f "$command_file" &&
   "$(sha256sum "$command_file" | cut -d ' ' -f 1)" == "$command_sha" ]] || {
  echo STAGING_ERRORS_STAGING_COMMAND_UNSAFE
  exit 1
}
[[ "$(cat "$old/STATE")" == STAGING_CALL_USAGE_ONLINE_SWITCH_COMPLETE ]]
[[ "$(cat "$old/APP_IMAGE_ID")" == "$old_id" ]]
[[ "$(cat "$candidate/APP_IMAGE_ID")" == "$old_id" ]]
[[ "$(cat "$backup/STATE")" == STAGING_2C_ALLOWANCE_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == STAGING_2C_KEY_ESCROW_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(cat "$backup/APP_IMAGE_ID")" == sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a ]]
[[ "$(grep -Fxc "    image: $old_tag" "$old/compose.staging.yaml")" == 1 ]]
for expected in \
  'name: teacher-workbench-staging' \
  '      - "127.0.0.1:18002:8080"' \
  '      AI_ENABLED: "0"' \
  '      AI_API_KEY: ""' \
  '      AI_LOCAL_QUEUE: "0"' \
  '      AI_STAGING_MANUAL_QUEUE: "1"' \
  '      AI_MEMBER_TASKS_ENABLED: "0"'; do
  grep -Fxq -- "$expected" "$old/compose.staging.yaml"
done
echo STAGING_ERRORS_SOURCE_BACKUP_AND_GATES_VERIFIED

sudo -n -v || { echo STAGING_ERRORS_SUDO_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]]
for service in "$web" "$gateway" teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$service")" == running ]]
done
timeout 60s sudo -n docker exec "$web" python manage.py migrate --check --noinput
if timeout 15s sudo -n docker image inspect "$new_tag" >/dev/null 2>&1; then
  echo STAGING_ERRORS_IMAGE_TAG_EXISTS
  exit 1
fi
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_ERRORS_OLD_LOGINS_HTTP_200')
PY

# A separate offline image changes the staging settings and keeps its strict
# one-task manual runner guard compatible with the hidden-error setting.
mkdir -m 700 "$new"
mkdir -m 700 "$new/config" "$new/build"
mkdir -m 700 -p "$new/build/workbench/management/commands"
install -m 600 "$settings_file" "$new/build/settings_staging.py"
install -m 600 "$command_file" "$new/build/workbench/management/commands/run_staging_task.py"
cat > "$new/build/Dockerfile" <<'DOCKERFILE'
FROM teacher-workbench-staging-web:call-usage-14537acaacc6
COPY settings_staging.py /app/config/settings_staging.py
COPY workbench/management/commands/run_staging_task.py /app/workbench/management/commands/run_staging_task.py
DOCKERFILE
chmod 600 "$new/build/Dockerfile"
echo STAGING_ERRORS_OFFLINE_BUILD_START
timeout 1200s sudo -n docker build --pull=false --no-cache --network none \
  -f "$new/build/Dockerfile" -t "$new_tag" "$new/build"
new_id="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$new_id" =~ ^sha256:[0-9a-f]{64}$ && "$new_id" != "$old_id" ]]
printf '%s\n' "$new_id" > "$new/APP_IMAGE_ID"
[[ "$(timeout 15s sudo -n docker run --pull never --rm --network none --read-only \
    "$new_tag" sha256sum /app/config/settings_staging.py | cut -d ' ' -f 1)" == "$settings_sha" ]]
[[ "$(timeout 15s sudo -n docker run --pull never --rm --network none --read-only \
    "$new_tag" sha256sum /app/workbench/management/commands/run_staging_task.py | cut -d ' ' -f 1)" == "$command_sha" ]]

# No database or external network is used in this settings and generic-404 check.
timeout 90s sudo -n docker run --pull never --rm --network none --read-only -i \
  --env-file "$old/.env.staging" -e DJANGO_SETTINGS_MODULE=config.settings_staging \
  -e TW_STAGING=1 -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 \
  -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0 \
  "$new_tag" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.test import Client
from workbench.management.commands.run_staging_task import staging_guard
assert settings.DEBUG is False
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED
assert not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_LOCAL_QUEUE
assert not settings.SESSION_COOKIE_SECURE and not settings.CSRF_COOKIE_SECURE
assert not settings.SECURE_SSL_REDIRECT and settings.SECURE_HSTS_SECONDS == 0
assert staging_guard()
response = Client().get('/staging-error-page-check-nonexistent/', HTTP_HOST='127.0.0.1')
assert response.status_code == 404
assert b'Using the URLconf' not in response.content
assert b'DJANGO_SETTINGS_MODULE' not in response.content
print('STAGING_ERRORS_OFFLINE_GENERIC_404_AI_OFF_OK')
PY
echo STAGING_ERRORS_OFFLINE_IMAGE_VERIFIED

# Keep the original loopback HTTP env, cookies, database and Compose settings.
install -m 600 "$old/.env.staging" "$new/.env.staging"
install -m 600 "$old/config/nginx-staging.conf" "$new/config/nginx-staging.conf"
python3 - "$old/compose.staging.yaml" "$new/compose.staging.yaml" "$old_tag" "$new_tag" <<'PY'
from pathlib import Path
import sys
old, new = map(Path, sys.argv[1:3])
old_line, new_line = (f'    image: {tag}' for tag in sys.argv[3:5])
source = old.read_text()
assert source.splitlines().count(old_line) == 1
result = source.replace(old_line, new_line, 1)
assert result.replace(new_line, old_line, 1) == source
new.write_text(result)
new.chmod(0o600)
PY
cmp -s "$old/.env.staging" "$new/.env.staging"
cmp -s "$old/config/nginx-staging.conf" "$new/config/nginx-staging.conf"
printf 'STAGING_ERRORS_CONFIG_PREPARED\n' > "$new/STATE"
timeout 40s sudo -n docker compose --env-file "$new/.env.staging" \
  -f "$new/compose.staging.yaml" config --quiet
echo STAGING_ERRORS_NEW_CONFIG_READY

old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
switch_started=0
rollback() {
  rc=$?
  trap - EXIT
  if [[ "$rc" != 0 && "$switch_started" == 1 ]]; then
    if timeout 180s "${old_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway; then
      if [[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]] &&
         python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
from time import sleep
opener = build_opener(ProxyHandler({}))
for _ in range(30):
    try:
        with opener.open('http://127.0.0.1:18002/login/', timeout=3) as response:
            if response.status == 200:
                raise SystemExit(0)
    except Exception:
        sleep(2)
raise SystemExit(1)
PY
      then
        echo STAGING_ERRORS_OLD_WEB_RESTORED >&2
      else
        echo STAGING_ERRORS_ROLLBACK_NEEDS_REVIEW >&2
      fi
    else
      echo STAGING_ERRORS_ROLLBACK_NEEDS_REVIEW >&2
    fi
  fi
  exit "$rc"
}
trap rollback EXIT

switch_started=1
echo STAGING_ERRORS_APPLICATION_SWITCH_START
timeout 180s "${new_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway
ready=0
for ((index=0; index<35; index++)); do
  if python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
try:
    with build_opener(ProxyHandler({})).open('http://127.0.0.1:18002/login/', timeout=3) as response:
        assert response.status == 200
except Exception:
    raise SystemExit(1)
PY
  then ready=1; break; fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_ERRORS_NEW_LOGIN_NOT_READY; exit 1; }
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$new_id" ]]
timeout 60s sudo -n docker exec "$web" python manage.py check
timeout 60s sudo -n docker exec "$web" python manage.py migrate --check --noinput
timeout 60s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.template.loader import get_template
from workbench.management.commands.run_staging_task import staging_guard
from workbench.models import CallAllowance, ModelCredential, WorksheetVersion
assert settings.DEBUG is False and settings.AI_STAGING_MANUAL_QUEUE
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED
assert not settings.SESSION_COOKIE_SECURE and not settings.CSRF_COOKIE_SECURE
assert staging_guard()
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
allowance = CallAllowance.objects.get(owner=owner)
assert (allowance.max_calls, allowance.used_calls, allowance.reserved_calls) == (0, 0, 0)
assert ModelCredential.objects.filter(owner=owner).count() >= 2
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
get_template('workbench/_task_call_usage.html')
print('STAGING_ERRORS_ONLINE_CONTENT_AI_OFF_OK')
PY
python3 - <<'PY'
from urllib.error import HTTPError
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
with opener.open('http://127.0.0.1:18002/static/workbench/site.css', timeout=5) as response:
    assert response.status == 200 and response.read()
try:
    opener.open('http://127.0.0.1:18002/staging-error-page-check-nonexistent/', timeout=5)
except HTTPError as error:
    body = error.read()
    assert error.code == 404 and b'Using the URLconf' not in body
    assert b'No URL patterns matched' not in body
else:
    raise AssertionError('unknown URL did not return 404')
print('STAGING_ERRORS_GENERIC_404_STATIC_AND_LOGINS_HTTP_OK')
PY
printf 'STAGING_ERRORS_ONLINE_SWITCH_COMPLETE\n' > "$new/STATE"
switch_started=0
echo STAGING_ERRORS_DEPLOYED_AI_OFF
echo "STAGING_ERRORS_NEW_DIR=$new"
echo "STAGING_ERRORS_ROLLBACK_BACKUP_DIR=$backup"
