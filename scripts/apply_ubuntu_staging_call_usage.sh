#!/usr/bin/env bash
# Switch only the fictional staging web image. The schema and AI gates stay unchanged.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_CALL_USAGE_SWITCH_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

suffix=14537acaacc6
old="$HOME/teacher-workbench-staging-phase2c-20261022"
candidate="$HOME/teacher-workbench-staging-call-usage-$suffix"
record="$HOME/teacher-workbench-staging-call-usage-pre-switch-$suffix"
new="$HOME/teacher-workbench-staging-call-usage-online-$suffix"
keyring="$HOME/teacher-workbench-staging-model-keyring"
backup_script="$HOME/backup_ubuntu_staging_phase2c_allowance_v3.sh"
old_tag=teacher-workbench-staging-web:member-quota-20261022
new_tag="teacher-workbench-staging-web:call-usage-$suffix"
old_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a
new_id=sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1

for directory in "$old" "$candidate" "$record" "$keyring"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]] || {
    echo STAGING_CALL_USAGE_SWITCH_DIRECTORY_UNSAFE
    exit 1
  }
done
[[ ! -e "$new" && ! -L "$new" ]] || { echo STAGING_CALL_USAGE_SWITCH_TARGET_EXISTS; exit 1; }
for file in "$old/.env.staging" "$old/compose.staging.yaml" \
            "$old/config/nginx-staging.conf" "$old/APP_IMAGE_ID" "$old/STATE" \
            "$candidate/APP_IMAGE_ID" "$candidate/STATE" "$candidate/SOURCE_SHA256SUMS" \
            "$record/STATE" "$record/SMOKE_STATE" "$record/BACKUP_DIR" \
            "$record/RESTORE_DIR" "$keyring/v1.key"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]] || {
    echo STAGING_CALL_USAGE_SWITCH_FILE_UNSAFE
    exit 1
  }
done
[[ "$(cat "$old/STATE")" == STAGING_2C_ONLINE_SWITCH_COMPLETE ]]
[[ "$(cat "$old/APP_IMAGE_ID")" == "$old_id" ]]
[[ "$(cat "$candidate/STATE")" == STAGING_CALL_USAGE_OFFLINE_IMAGE_COMPLETE ]]
[[ "$(cat "$candidate/APP_IMAGE_ID")" == "$new_id" ]]
[[ "$(cat "$record/STATE")" == STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_COMPLETE ]]
[[ "$(cat "$record/SMOKE_STATE")" == STAGING_CALL_USAGE_RESTORED_SMOKE_COMPLETE ]]
[[ "$(cat "$record/BACKUP_DIR")" == /home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-szRPlLy0 ]]
[[ "$(cat "$record/RESTORE_DIR")" == /home/huahua/teacher-workbench-staging-phase2c-allowance-restore-szRPlLy0 ]]
(cd "$candidate/src" && sha256sum -c ../SOURCE_SHA256SUMS >/dev/null)
[[ ! -L "$backup_script" && -f "$backup_script" &&
   "$(sha256sum "$backup_script" | cut -d ' ' -f 1)" == 2ccf1d8fe99d79107ad350717a2e9e2a31de8236b80887cd4cd310f83a86c531 ]]
bash -n "$backup_script"
for expected in \
  'name: teacher-workbench-staging' \
  '      - "127.0.0.1:18002:8080"' \
  '      AI_ENABLED: "0"' \
  '      AI_API_KEY: ""' \
  '      AI_LOCAL_QUEUE: "0"' \
  '      AI_STAGING_MANUAL_QUEUE: "1"' \
  '      AI_MEMBER_TASKS_ENABLED: "0"' \
  '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro'; do
  grep -Fxq -- "$expected" "$old/compose.staging.yaml"
done
[[ "$(grep -Fxc "    image: $old_tag" "$old/compose.staging.yaml")" == 1 ]]
echo STAGING_CALL_USAGE_SWITCH_FILES_AND_GATES_VERIFIED

sudo -n -v || { echo STAGING_CALL_USAGE_SWITCH_SUDO_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")" == "$new_id" ]]
for service in "$web" "$gateway" teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$service")" == running ]]
done
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' "$web")" == "$keyring:false" ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_SWITCH_OLD_LOGINS_HTTP_200')
PY

# Copy the private configuration. Change exactly one Compose image line.
mkdir -m 700 "$new"
mkdir -m 700 "$new/config"
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
printf '%s\n' "$new_id" > "$new/APP_IMAGE_ID"
printf 'STAGING_CALL_USAGE_CONFIG_PREPARED\n' > "$new/STATE"
timeout 40s sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml" config --quiet
echo STAGING_CALL_USAGE_SWITCH_NEW_CONFIG_READY

# The exact backup/restore method has already passed on the old staging image.
# Make an immediate additional snapshot before changing the running web image.
set +e
bash "$backup_script" 2>&1 | tee "$new/backup.log"
backup_rc=${PIPESTATUS[0]}
set -e
[[ "$backup_rc" == 0 ]] || { echo STAGING_CALL_USAGE_SWITCH_FRESH_BACKUP_FAILED; exit 1; }
grep -Fxq STAGING_2C_PAIRED_FILES_VERIFIED "$new/backup.log"
mapfile -t lines < <(grep '^STAGING_2C_BACKUP_DIR=' "$new/backup.log")
[[ "${#lines[@]}" == 1 ]]
backup="${lines[0]#STAGING_2C_BACKUP_DIR=}"
[[ "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-([A-Za-z0-9]{8})$ ]]
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-${BASH_REMATCH[1]}"
[[ ! -L "$backup" && -d "$backup" && "$(stat -c %a "$backup")" == 700 ]]
[[ ! -L "$escrow" && -d "$escrow" && "$(stat -c %a "$escrow")" == 700 ]]
[[ "$(cat "$backup/STATE")" == STAGING_2C_ALLOWANCE_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == STAGING_2C_KEY_ESCROW_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(cat "$backup/APP_IMAGE_ID")" == "$old_id" ]]
printf '%s\n' "$backup" > "$new/BACKUP_DIR"
printf '%s\n' "$escrow" > "$new/ESCROW_DIR"
echo STAGING_CALL_USAGE_SWITCH_FRESH_BACKUP_VERIFIED

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
        echo STAGING_CALL_USAGE_OLD_WEB_RESTORED >&2
      else
        echo STAGING_CALL_USAGE_ROLLBACK_NEEDS_REVIEW >&2
      fi
    else
      echo STAGING_CALL_USAGE_ROLLBACK_NEEDS_REVIEW >&2
    fi
  fi
  exit "$rc"
}
trap rollback EXIT

switch_started=1
echo STAGING_CALL_USAGE_APPLICATION_SWITCH_START
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
[[ "$ready" == 1 ]] || { echo STAGING_CALL_USAGE_NEW_LOGIN_NOT_READY; exit 1; }
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$new_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$gateway")" == running ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' "$web")" == "$keyring:false" ]]
timeout 60s sudo -n docker exec "$web" python manage.py check
timeout 60s sudo -n docker exec "$web" python manage.py migrate --check --noinput
timeout 60s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.template.loader import get_template
from workbench.models import CallAllowance, ModelCredential, WorksheetVersion
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED
assert not settings.AI_LOCAL_QUEUE and not settings.AI_API_KEY
assert settings.AI_STAGING_MANUAL_QUEUE
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
allowance = CallAllowance.objects.get(owner=owner)
assert (allowance.max_calls, allowance.used_calls, allowance.reserved_calls) == (0, 0, 0)
assert ModelCredential.objects.filter(owner=owner).count() >= 2
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
get_template('workbench/_task_call_usage.html')
print('STAGING_CALL_USAGE_ONLINE_CONTENT_AI_OFF_AND_PAGE_OK')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_NEW_AND_OLD_TEST_LOGIN_HTTP_200')
PY
printf 'STAGING_CALL_USAGE_ONLINE_SWITCH_COMPLETE\n' > "$new/STATE"
switch_started=0
echo STAGING_CALL_USAGE_DEPLOYED_AI_OFF
echo "STAGING_CALL_USAGE_NEW_DIR=$new"
echo "STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_DIR=$backup"
