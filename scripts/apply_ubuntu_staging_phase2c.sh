#!/usr/bin/env bash
# Switch only the fictional staging stack to the prebuilt 2C image, AI off.
# Requires a fresh paired 2B snapshot and independent restore. Keep DB backup.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 1 ]]; then
  echo STAGING_2C_SWITCH_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

backup="$1"
if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-([A-Za-z0-9]{8})$ ]]; then
  echo STAGING_2C_SWITCH_BACKUP_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
[[ "$suffix" != F6yZnxfi ]] || { echo STAGING_2C_SWITCH_NEEDS_FRESH_BACKUP; exit 1; }

old="$HOME/teacher-workbench-staging-phase2b-20261020"
new="$HOME/teacher-workbench-staging-phase2c-20261022"
keyring="$HOME/teacher-workbench-staging-model-keyring"
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-$suffix"
prefix="teacher-workbench-staging-phase2b-keys-restore-$suffix"
restore="$HOME/$prefix"
restore_net="$prefix-net"
restore_db="$prefix-db"
restore_redis="$prefix-redis"
restore_private="$prefix-private"
online_net=teacher-workbench-staging_default
online_private=teacher-workbench-staging_staging_private
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1
old_tag=teacher-workbench-staging-web:credentials-20261020
new_tag=teacher-workbench-staging-web:member-quota-20261022
new_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a
preflight="$HOME/check_ubuntu_staging_phase2c_config_readonly.sh"

for directory in "$old" "$new" "$backup" "$escrow" "$restore" "$keyring"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_2C_SWITCH_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$old/.env.staging" "$new/.env.staging" "$new/APP_IMAGE_ID" \
            "$new/STATE" "$backup/STATE" "$backup/APP_IMAGE_ID" \
            "$backup/SHA256SUMS" "$escrow/STATE" "$escrow/v1.key" \
            "$escrow/SHA256SUMS" "$restore/.env.staging"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_2C_SWITCH_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(cat "$new/STATE")" == STAGING_2C_CONFIG_PREPARED ]]
[[ "$(cat "$new/APP_IMAGE_ID")" == "$new_id" ]]
[[ "$(cat "$backup/STATE")" == STAGING_2B_CREDENTIAL_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == STAGING_2B_KEY_ESCROW_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
cmp -s "$old/.env.staging" "$new/.env.staging"

if [[ -L "$preflight" || ! -f "$preflight" ||
      "$(sha256sum "$preflight" | cut -d ' ' -f 1)" != 92b6c91a914de58540a71c4a9fa807048edcba45f189a7e24646b655b32291e9 ]]; then
  echo STAGING_2C_SWITCH_PREFLIGHT_SCRIPT_UNSAFE
  exit 1
fi
sudo -n -v || { echo STAGING_2C_SWITCH_SUDO_REQUIRED; exit 1; }
bash "$preflight"

old_id="$(cat "$backup/APP_IMAGE_ID")"
[[ "$old_id" =~ ^sha256:[0-9a-f]{64}$ && "$old_id" != "$new_id" ]]
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")" == "$new_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]]
for container in "$restore_db" "$restore_redis"; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$container")" == "$restore_net" ]]
done
for volume in "$restore_db" "$restore_private" "$online_private"; do
  timeout 15s sudo -n docker volume inspect "$volume" >/dev/null
done
timeout 15s sudo -n docker network inspect "$restore_net" "$online_net" >/dev/null
timeout 30s sudo -n docker compose --env-file "$new/.env.staging" \
  -f "$new/compose.staging.yaml" config --quiet

# Limit the gap between this recoverable snapshot and the online migration.
now="$(date +%s)"
backup_time="$(stat -c %Y "$backup/STATE")"
[[ "$backup_time" =~ ^[0-9]+$ && "$now" -ge "$backup_time" &&
   "$((now-backup_time))" -le 3600 ]] || {
  echo STAGING_2C_SWITCH_BACKUP_TOO_OLD
  exit 1
}
echo STAGING_2C_SWITCH_FRESH_BACKUP_AND_CONFIG_VERIFIED

old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
restore_started=0
downtime_started=0
cleanup() {
  local rc=$?
  trap - EXIT
  if [[ "$restore_started" == 1 ]]; then
    timeout 50s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null 2>&1 ||
      echo STAGING_2C_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$downtime_started" == 1 ]]; then
    if timeout 180s "${old_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway >/dev/null; then
      echo STAGING_2C_OLD_WEB_GATEWAY_RESTORED_DATABASE_MAY_BE_MIGRATED >&2
    else
      echo STAGING_2C_ROLLBACK_NEEDS_REVIEW >&2
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

# Prove this fresh snapshot accepts 2C migrations before touching the online DB.
restore_started=1
timeout 60s sudo -n docker start "$restore_db" "$restore_redis" >/dev/null
ready=0
for ((index=0; index<45; index++)); do
  if timeout 8s sudo -n docker exec "$restore_db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_SWITCH_RESTORE_DB_NOT_READY; exit 1; }
run_restored=(sudo -n docker run --pull never --rm -i --network "$restore_net"
  --env-file "$restore/.env.staging" -e DB_HOST="$restore_db"
  -e REDIS_URL="redis://$restore_redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0
  -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0
  -v "$restore_private:/app/data/private:ro" -v "$escrow:/run/model-keyring:ro" "$new_tag")
timeout 150s "${run_restored[@]}" python manage.py migrate --noinput
timeout 60s "${run_restored[@]}" python manage.py migrate --check --noinput
timeout 60s "${run_restored[@]}" python manage.py check
timeout 70s "${run_restored[@]}" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from workbench.credential_vault import unseal_key_for_owner, vault_ready
from workbench.models import CallAllowance, CallAttempt, ModelCredential, WorksheetVersion

assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_API_KEY
assert settings.AI_STAGING_MANUAL_QUEUE and vault_ready()
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
assert not CallAllowance.objects.exists() and not CallAttempt.objects.exists()
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
credentials = list(ModelCredential.objects.filter(owner=owner))
assert len(credentials) >= 2
assert all(unseal_key_for_owner(item, owner.pk).startswith('sk-fictional-') for item in credentials)
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_2C_FRESH_RESTORE_MIGRATION_AND_CONTENT_OK')
PY
timeout 50s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null
restore_started=0
echo STAGING_2C_FRESH_RESTORE_MIGRATION_PROVED

# From this point, old web/gateway are restarted on any failure. The DB backup
# remains untouched; additive migrations are not automatically rolled back.
downtime_started=1
timeout 60s sudo -n docker stop "$gateway" "$web" >/dev/null
echo STAGING_2C_APPLICATION_WRITES_STOPPED
timeout 150s sudo -n docker run --pull never --rm --network "$online_net" \
  --env-file "$new/.env.staging" -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e PRIVATE_FILE_ROOT=/app/data/private -e MODEL_KEYRING_DIR=/run/model-keyring \
  -e MODEL_ACTIVE_KEY_VERSION=1 -e AI_ENABLED=0 -e AI_API_KEY= \
  -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0 \
  -v "$online_private:/app/data/private:ro" -v "$keyring:/run/model-keyring:ro" \
  "$new_tag" python manage.py migrate --noinput
echo STAGING_2C_ONLINE_ADDITIVE_MIGRATIONS_OK

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
  then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_NEW_LOGIN_NOT_READY; exit 1; }
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$new_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$gateway")" == running ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' "$web")" == "$keyring:false" ]]
timeout 60s sudo -n docker exec "$web" python manage.py check
timeout 60s sudo -n docker exec "$web" python manage.py migrate --check --noinput
timeout 70s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.db.migrations.recorder import MigrationRecorder
from workbench.credential_vault import vault_ready
from workbench.models import CallAllowance, CallAttempt, ModelCredential, WorksheetVersion

assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED
assert not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_API_KEY and vault_ready()
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
assert not CallAllowance.objects.exists() and not CallAttempt.objects.exists()
assert ModelCredential.objects.count() >= 2
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_2C_ONLINE_SCHEMA_AI_OFF_AND_OLD_CONTENT_OK')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_NEW_AND_OLD_TEST_LOGIN_HTTP_200')
PY

printf 'STAGING_2C_ONLINE_SWITCH_COMPLETE\n' > "$new/STATE"
downtime_started=0
echo STAGING_2C_DEPLOYED_AI_OFF
echo "STAGING_2C_NEW_DIR=$new"
echo "STAGING_2C_PRE_SWITCH_BACKUP_DIR=$backup"
