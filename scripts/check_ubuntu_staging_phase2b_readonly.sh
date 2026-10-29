#!/usr/bin/env bash
# Read-only survey before planning a new paired staging backup and keyring.
# Fixed to the fictional staging stack on VM 257; prints no secrets or rows.
set -euo pipefail

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua || "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_PHASE2B_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
compose="$stage/compose.staging.yaml"
env_file="$stage/.env.staging"
if [[ -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != 700 ||
      -L "$compose" || ! -f "$compose" || -L "$env_file" || ! -f "$env_file" ||
      "$(stat -c %a "$env_file")" != 600 ]]; then
  echo STAGING_PHASE2B_SOURCE_UNSAFE
  exit 1
fi
grep -Fxq 'name: teacher-workbench-staging' "$compose"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$compose"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$compose"
grep -Fxq '    image: teacher-workbench-staging-web:accounts-20261018' "$compose"
python3 "$stage/scripts/check_staging_env.py" --env-file "$env_file" >/dev/null
echo STAGING_PHASE2B_SOURCE_CONFIG_OK

sudo -v
for pair in \
  'teacher-workbench-staging-db-1:postgres:17' \
  'teacher-workbench-staging-redis-1:redis:7-alpine' \
  'teacher-workbench-staging-web-1:teacher-workbench-staging-web:accounts-20261018' \
  'teacher-workbench-staging-gateway-1:nginx:stable-alpine'; do
  container="${pair%%:*}"
  image="${pair#*:}"
  status="$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")"
  [[ "$status" == running ]] || { echo "STAGING_PHASE2B_SERVICE_NOT_RUNNING=$container"; exit 1; }
  expected="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$image")"
  actual="$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$container")"
  [[ "$actual" == "$expected" ]] || { echo "STAGING_PHASE2B_IMAGE_MISMATCH=$container"; exit 1; }
done
echo STAGING_PHASE2B_FOUR_SERVICES_MATCH_IMAGES

for volume in teacher-workbench-staging_staging_db teacher-workbench-staging_staging_private; do
  timeout 10s sudo -n docker volume inspect "$volume" >/dev/null
done
web_mounts="$(timeout 10s sudo -n docker inspect -f '{{range .Mounts}}{{println .Destination}}{{end}}' teacher-workbench-staging-web-1)"
grep -Fxq /app/data/private <<< "$web_mounts"
grep -Fxq /app/staticfiles <<< "$web_mounts"
if grep -Fq /run/model-keyring <<< "$web_mounts"; then
  echo STAGING_PHASE2B_KEYRING_ALREADY_MOUNTED
  exit 1
fi
if [[ -e "$HOME/teacher-workbench-staging-model-keyring" || -L "$HOME/teacher-workbench-staging-model-keyring" ]]; then
  echo STAGING_PHASE2B_KEYRING_ALREADY_EXISTS
  exit 1
fi
echo STAGING_PHASE2B_KEYRING_NOT_CREATED

timeout 20s sudo -n docker exec -i teacher-workbench-staging-web-1 python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from workbench.models import WorksheetVersion
db = settings.DATABASES['default']
assert db['ENGINE'] == 'django.db.backends.postgresql'
assert db['NAME'] == 'teacher_workbench_staging' and db['HOST'] == 'db'
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert not settings.AI_LOCAL_QUEUE
assert get_user_model().objects.filter(username='staging_manager_20261018').exists()
assert get_user_model().objects.filter(username='staging_teacher_a_20261018', is_active=True).exists()
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_PHASE2B_EXISTING_FIXTURES_OK')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_STAGING_AND_OLD_TEST_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_READONLY_PREFLIGHT_OK
