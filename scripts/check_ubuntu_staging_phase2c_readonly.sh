#!/usr/bin/env bash
# Read-only inventory for the fictional staging 2B stack before planning 2C.
# Prints no secret, credential value, user row, or private file content.
set -euo pipefail

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage="$HOME/teacher-workbench-staging-phase2b-20261020"
compose="$stage/compose.staging.yaml"
env_file="$stage/.env.staging"
keyring="$HOME/teacher-workbench-staging-model-keyring"
if [[ -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != 700 ||
      -L "$compose" || ! -f "$compose" || -L "$env_file" || ! -f "$env_file" ||
      "$(stat -c %a "$env_file")" != 600 || -L "$keyring" || ! -d "$keyring" ]]; then
  echo STAGING_2C_SOURCE_UNSAFE
  exit 1
fi
grep -Fxq 'name: teacher-workbench-staging' "$compose"
grep -Fxq '    image: teacher-workbench-staging-web:credentials-20261020' "$compose"
grep -Fxq '      AI_ENABLED: "0"' "$compose"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$compose"
grep -Fxq '      MODEL_KEYRING_DIR: /run/model-keyring' "$compose"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$compose"
python3 "$stage/scripts/check_staging_env.py" --env-file "$env_file" >/dev/null
echo STAGING_2C_SOURCE_CONFIG_AI_OFF

timeout 60s sudo -v
for pair in \
  'teacher-workbench-staging-db-1:postgres:17' \
  'teacher-workbench-staging-redis-1:redis:7-alpine' \
  'teacher-workbench-staging-web-1:teacher-workbench-staging-web:credentials-20261020' \
  'teacher-workbench-staging-gateway-1:nginx:stable-alpine'; do
  container="${pair%%:*}"
  image="${pair#*:}"
  status="$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")"
  expected="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$image")"
  actual="$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$container")"
  if [[ "$status" != running || "$actual" != "$expected" ]]; then
    echo "STAGING_2C_CONTAINER_UNEXPECTED=$container"
    exit 1
  fi
done
echo STAGING_2C_FOUR_SERVICES_MATCH_IMAGES

timeout 30s sudo -n docker exec -i teacher-workbench-staging-web-1 python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.db.migrations.recorder import MigrationRecorder

db = settings.DATABASES['default']
assert db['ENGINE'] == 'django.db.backends.postgresql'
assert db['NAME'] == 'teacher_workbench_staging' and db['HOST'] == 'db'
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert settings.MODEL_KEYRING_DIR == '/run/model-keyring'
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert '0005_modelcredential' in applied
assert not any(name.startswith(('0006_', '0007_', '0008_')) for name in applied)
print('STAGING_2C_ONLINE_SCHEMA_2B_AI_OFF')
PY

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_NEW_AND_OLD_LOGIN_HTTP_200')
PY
echo STAGING_2C_READONLY_PREFLIGHT_OK
