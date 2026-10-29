#!/usr/bin/env bash
# Switch only the fictional staging web after a fresh 2A paired backup and
# independent restore. The 0005 migration adds one table; preserve the backup
# and automatically restore the old web/gateway on a failed switch.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 1 ]]; then
  echo STAGING_PHASE2B_SWITCH_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

old="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
new="$HOME/teacher-workbench-staging-phase2b-20261020"
keyring="$HOME/teacher-workbench-staging-model-keyring"
recovery="$HOME/teacher-workbench-staging-phase2b-fictional-recovery-lESMk1Nj"
backup="$1"
if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-([A-Za-z0-9]{8})$ ]]; then
  echo STAGING_PHASE2B_SWITCH_BACKUP_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
if [[ "$suffix" == lESMk1Nj ]]; then
  echo STAGING_PHASE2B_SWITCH_NEEDS_FRESH_BACKUP
  exit 1
fi
prefix="teacher-workbench-staging-phase2b-pre-restore-$suffix"
restore="$HOME/$prefix"
restore_db="$prefix-db"
restore_redis="$prefix-redis"
restore_net="$prefix-net"
restore_private="$prefix-private"
old_tag=teacher-workbench-staging-web:accounts-20261018
new_tag=teacher-workbench-staging-web:credentials-20261020
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1
online_db=teacher-workbench-staging-db-1
online_private=teacher-workbench-staging_staging_private
online_net=teacher-workbench-staging_default

for directory in "$old" "$new" "$keyring" "$recovery" "$backup" "$restore"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_PHASE2B_SWITCH_INPUT_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$old/.env.staging" "$new/.env.staging" "$restore/.env.staging" \
            "$keyring/v1.key" "$recovery/keyring/v1.key" "$backup/STATE" \
            "$backup/SHA256SUMS" "$backup/APP_IMAGE_ID"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_PHASE2B_SWITCH_INPUT_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(cat "$backup/STATE")" == STAGING_PHASE2B_PRE_BACKUP_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$recovery" && sha256sum -c SHA256SUMS >/dev/null)
cmp -s "$old/.env.staging" "$new/.env.staging"
cmp -s "$keyring/v1.key" "$recovery/keyring/v1.key"
python3 "$new/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
grep -Fxq 'name: teacher-workbench-staging' "$new/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$new/compose.staging.yaml"
grep -Fxq "    image: $new_tag" "$new/compose.staging.yaml"
grep -Fxq '      AI_ENABLED: "0"' "$new/compose.staging.yaml"
grep -Fxq '      AI_API_KEY: ""' "$new/compose.staging.yaml"
grep -Fxq '      AI_LOCAL_QUEUE: "0"' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"
grep -Fxq '      MODEL_KEYRING_DIR: /run/model-keyring' "$new/compose.staging.yaml"
grep -Fxq '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$old/compose.staging.yaml"
grep -Fxq "    image: $old_tag" "$old/compose.staging.yaml"

sudo -v
old_image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")"
new_image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$old_image_id" =~ ^sha256:[0-9a-f]{64}$ && "$new_image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(cat "$backup/APP_IMAGE_ID")" == "$old_image_id" ]]
for container in "$web" "$gateway" "$online_db" teacher-workbench-staging-redis-1; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == running ]]
done
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_image_id" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$web")" == "$online_net" ]]
for container in "$restore_db" "$restore_redis"; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$container")" == "$restore_net" ]]
done
for volume in "$restore_private" "$prefix-db" "$online_private"; do
  timeout 10s sudo -n docker volume inspect "$volume" >/dev/null
done
timeout 10s sudo -n docker network inspect "$restore_net" "$online_net" >/dev/null
timeout 30s sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml" config --quiet

timeout 30s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.db.migrations.recorder import MigrationRecorder
from workbench.models import WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert not MigrationRecorder.Migration.objects.filter(app='workbench', name='0005_modelcredential').exists()
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_PHASE2B_ONLINE_2A_SCHEMA_AND_FIXTURE_OK')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_SWITCH_SOURCE_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_SWITCH_PREFLIGHT_OK

old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
restore_started=0
downtime_started=0
cleanup() {
  if [[ "$restore_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null 2>&1 ||
      echo STAGING_PHASE2B_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$downtime_started" == 1 ]]; then
    if timeout 150s "${old_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway >/dev/null; then
      echo STAGING_PHASE2B_OLD_WEB_GATEWAY_RESTORED >&2
    else
      echo STAGING_PHASE2B_ROLLBACK_NEEDS_REVIEW >&2
    fi
  fi
}
trap cleanup EXIT

restore_started=1
timeout 40s sudo -n docker start "$restore_db" "$restore_redis" >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$restore_db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_PHASE2B_FRESH_RESTORE_DB_NOT_READY; exit 1; }

run_restored=(sudo -n docker run --pull never --rm -i --network "$restore_net"
  --env-file "$restore/.env.staging" -e DB_HOST="$restore_db"
  -e REDIS_URL="redis://$restore_redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1
  -v "$restore_private:/app/data/private:ro" -v "$keyring:/run/model-keyring:ro" "$new_tag")
timeout 120s "${run_restored[@]}" python manage.py migrate --noinput
timeout 45s "${run_restored[@]}" python manage.py check
timeout 180s "${run_restored[@]}" python manage.py test workbench.tests_credentials --verbosity 0
timeout 45s "${run_restored[@]}" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from workbench.credential_vault import vault_ready
from workbench.models import ModelCredential, WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert vault_ready()
assert MigrationRecorder.Migration.objects.filter(app='workbench', name='0005_modelcredential').exists()
assert get_user_model().objects.filter(username='staging_manager_20261018').exists()
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
assert ModelCredential.objects.count() == 0
print('STAGING_PHASE2B_FRESH_RESTORE_MIGRATION_AND_DATA_OK')
PY
timeout 40s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null
restore_started=0
echo STAGING_PHASE2B_FRESH_RESTORE_TESTS_OK

downtime_started=1
timeout 60s sudo -n docker stop "$gateway" "$web" >/dev/null
echo STAGING_PHASE2B_APPLICATION_WRITES_STOPPED

timeout 120s sudo -n docker run --pull never --rm -i --network "$online_net" \
  --env-file "$new/.env.staging" -e DB_HOST=db \
  -e REDIS_URL=redis://redis:6379/0 -e PRIVATE_FILE_ROOT=/app/data/private \
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1 \
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1 \
  -v "$online_private:/app/data/private:ro" -v "$keyring:/run/model-keyring:ro" \
  "$new_tag" python manage.py migrate --noinput
echo STAGING_PHASE2B_ONLINE_ADDITIVE_MIGRATION_OK

timeout 150s "${new_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway
ready=0
for _ in {1..30}; do
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
[[ "$ready" == 1 ]] || { echo STAGING_PHASE2B_NEW_LOGIN_NOT_READY; exit 1; }
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$new_image_id" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$gateway")" == running ]]
key_mount="$(timeout 10s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' "$web")"
[[ "$key_mount" == "$keyring:false" ]]
timeout 45s sudo -n docker exec "$web" python manage.py check
timeout 45s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.db.migrations.recorder import MigrationRecorder
from workbench.credential_vault import vault_ready
from workbench.models import ModelCredential, WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert settings.MODEL_KEYRING_DIR == '/run/model-keyring' and vault_ready()
assert MigrationRecorder.Migration.objects.filter(app='workbench', name='0005_modelcredential').exists()
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
assert ModelCredential.objects.count() == 0
print('STAGING_PHASE2B_ONLINE_SCHEMA_KEYRING_AND_FIXTURE_OK')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_NEW_AND_OLD_TEST_LOGIN_HTTP_200')
PY
downtime_started=0
echo STAGING_PHASE2B_DEPLOYED_FICTIONAL_KEYS_ONLY_AI_OFF
echo "STAGING_PHASE2B_NEW_DIR=$new"
echo "STAGING_PHASE2B_FRESH_BACKUP_DIR=$backup"
