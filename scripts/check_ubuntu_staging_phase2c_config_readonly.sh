#!/usr/bin/env bash
# Read-only preflight for the prepared 2C Compose configuration. No switch.
set -euo pipefail

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_CONFIG_PREFLIGHT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

old="$HOME/teacher-workbench-staging-phase2b-20261020"
new="$HOME/teacher-workbench-staging-phase2c-20261022"
build="$HOME/teacher-workbench-staging-phase2c-migration-F6yZnxfi"
keyring="$HOME/teacher-workbench-staging-model-keyring"
old_tag=teacher-workbench-staging-web:credentials-20261020
new_tag=teacher-workbench-staging-web:member-quota-20261022
expected_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a

for directory in "$old" "$new" "$new/config" "$build" "$keyring"; do
  if [[ -L "$directory" || ! -d "$directory" ]]; then
    echo STAGING_2C_CONFIG_PREFLIGHT_DIRECTORY_UNSAFE
    exit 1
  fi
done
[[ "$(stat -c %a "$old")" == 700 && "$(stat -c %a "$new")" == 700 &&
   "$(stat -c %a "$build")" == 700 && "$(stat -c %a "$keyring")" == 700 ]]
for file in "$new/compose.staging.yaml" "$new/.env.staging" \
            "$new/config/nginx-staging.conf" "$new/APP_IMAGE_ID" "$new/STATE" \
            "$build/APP_IMAGE_ID" "$build/IMAGE_BUILD_STATE"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_2C_CONFIG_PREFLIGHT_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(cat "$new/STATE")" == STAGING_2C_CONFIG_PREPARED ]]
[[ "$(cat "$build/IMAGE_BUILD_STATE")" == STAGING_2C_OFFLINE_IMAGE_COMPLETE ]]
[[ "$(cat "$new/APP_IMAGE_ID")" == "$expected_id" &&
   "$(cat "$build/APP_IMAGE_ID")" == "$expected_id" ]]
cmp -s "$old/.env.staging" "$new/.env.staging"
cmp -s "$old/config/nginx-staging.conf" "$new/config/nginx-staging.conf"

python3 - "$old/compose.staging.yaml" "$new/compose.staging.yaml" <<'PY'
from pathlib import Path
import sys

old = Path(sys.argv[1]).read_text(encoding='utf-8')
new = Path(sys.argv[2]).read_text(encoding='utf-8')
assert old.count('    image: teacher-workbench-staging-web:credentials-20261020\n') == 1
assert old.count('    build:\n      context: .\n      dockerfile: Dockerfile.phase2b-paired\n') == 1
assert old.count('      AI_STAGING_MANUAL_QUEUE: "1"\n') == 1
expected = old.replace(
    '    image: teacher-workbench-staging-web:credentials-20261020\n',
    '    image: teacher-workbench-staging-web:member-quota-20261022\n', 1)
expected = expected.replace(
    '    build:\n      context: .\n      dockerfile: Dockerfile.phase2b-paired\n', '', 1)
expected = expected.replace(
    '      AI_STAGING_MANUAL_QUEUE: "1"\n',
    '      AI_STAGING_MANUAL_QUEUE: "1"\n'
    '      AI_MEMBER_TASKS_ENABLED: "0"\n', 1)
assert new == expected
assert '      AI_ENABLED: "0"\n' in new
assert '      AI_API_KEY: ""\n' in new
assert '      - "127.0.0.1:18002:8080"\n' in new
assert '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro\n' in new
print('STAGING_2C_CONFIG_CONTENT_MATCH_OK')
PY

python3 "$old/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
sudo -n -v || { echo STAGING_2C_CONFIG_PREFLIGHT_SUDO_REQUIRED; exit 1; }
[[ "$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")" == "$expected_id" ]]
old_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")"
[[ "$old_id" =~ ^sha256:[0-9a-f]{64}$ && "$old_id" != "$expected_id" ]]
for container in teacher-workbench-staging-web-1 teacher-workbench-staging-gateway-1 \
                 teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == running ]]
done
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_id" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' teacher-workbench-staging-web-1)" == teacher-workbench-staging_default ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' teacher-workbench-staging-web-1)" == "$keyring:false" ]]
timeout 30s sudo -n docker compose --env-file "$new/.env.staging" \
  -f "$new/compose.staging.yaml" config --quiet
echo STAGING_2C_CONFIG_COMPOSE_VALID

timeout 30s sudo -n docker exec -i teacher-workbench-staging-web-1 python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.db.migrations.recorder import MigrationRecorder

assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert settings.MODEL_KEYRING_DIR == '/run/model-keyring'
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert '0005_modelcredential' in applied
assert not any(item.startswith(('0006_', '0007_', '0008_')) for item in applied)
print('STAGING_2C_CONFIG_ONLINE_STILL_2B_AI_OFF')
PY

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_CONFIG_BOTH_LOGINS_HTTP_200')
PY

echo STAGING_2C_CONFIG_READONLY_PREFLIGHT_OK
