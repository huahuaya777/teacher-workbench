#!/usr/bin/env bash
# Build the 2B image from the paired 2A image and reviewed offline bundle.
# Does not migrate databases, create a master key, or switch online services.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua || "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_PHASE2B_BUILD_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
old="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
new="$HOME/teacher-workbench-staging-phase2b-20261020"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2b-pre-lESMk1Nj"
restore="$HOME/teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj"
bundle="$HOME/teacher-workbench-staging-phase2b.tar.gz"
helper="$HOME/prepare_ubuntu_staging_phase2b_source.py"
old_tag=teacher-workbench-staging-web:accounts-20261018
new_tag=teacher-workbench-staging-web:credentials-20261020

for directory in "$old" "$backup" "$restore"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_PHASE2B_BUILD_INPUT_DIRECTORY_UNSAFE
    exit 1
  fi
done
if [[ -e "$new" || -L "$new" || -e "$HOME/teacher-workbench-staging-model-keyring" ||
      -L "$HOME/teacher-workbench-staging-model-keyring" ]]; then
  echo STAGING_PHASE2B_BUILD_TARGET_OR_KEYRING_EXISTS
  exit 1
fi
for file in "$bundle" "$helper" "$old/.env.staging" "$backup/SHA256SUMS" "$backup/STATE"; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    echo STAGING_PHASE2B_BUILD_INPUT_MISSING_OR_LINK
    exit 1
  fi
done
[[ "$(stat -c %a "$old/.env.staging")" == 600 ]]
[[ "$(cat "$backup/STATE")" == STAGING_PHASE2B_PRE_BACKUP_COMPLETE ]]
[[ "$(sha256sum "$bundle" | cut -d ' ' -f 1)" == b3558bd2cee54bc508772f065596b88aa3579f171b931ff7a711b04f0e18f0a8 ]]
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == 8726004b745144b21ca4dbe990584999d70ece431d9bae354fba7849261eac29 ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
python3 "$old/scripts/check_staging_env.py" --env-file "$old/.env.staging" >/dev/null
grep -Fxq 'name: teacher-workbench-staging' "$old/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$old/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$old/compose.staging.yaml"
grep -Fxq "    image: $old_tag" "$old/compose.staging.yaml"

sudo -v
for container in teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1 \
                 teacher-workbench-staging-web-1 teacher-workbench-staging-gateway-1; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == running ]]
done
old_image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")"
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_image_id" ]]
[[ "$(cat "$backup/APP_IMAGE_ID")" == "$old_image_id" ]]
for container in teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj-db \
                 teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj-redis; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
done
for volume in teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj-db \
              teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj-private; do
  timeout 10s sudo -n docker volume inspect "$volume" >/dev/null
done
if sudo -n docker image inspect "$new_tag" >/dev/null 2>&1; then
  echo STAGING_PHASE2B_NEW_IMAGE_TAG_EXISTS
  exit 1
fi
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_BUILD_SOURCE_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_BUILD_PREFLIGHT_OK

python3 "$helper"
python3 "$new/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
grep -Fxq '      MODEL_KEYRING_DIR: /run/model-keyring' "$new/compose.staging.yaml"
grep -Fxq '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro' "$new/compose.staging.yaml"
grep -Fxq '      AI_ENABLED: "0"' "$new/compose.staging.yaml"
grep -Fxq '      AI_API_KEY: ""' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$new/compose.staging.yaml"
echo STAGING_PHASE2B_NEW_COMPOSE_GUARDS_OK

echo STAGING_PHASE2B_OFFLINE_IMAGE_BUILD_START
timeout 1200s sudo -n docker build --pull=false --no-cache --network none \
  -f "$new/Dockerfile.phase2b-paired" -t "$new_tag" "$new"
new_image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$new_image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
timeout 45s sudo -n docker run --pull never --rm --network none \
  --env-file "$new/.env.staging" \
  -e DJANGO_SETTINGS_MODULE=config.settings_staging -e TW_STAGING=1 \
  -e REDIS_URL=redis://redis:6379/0 -e DB_HOST=db \
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1 \
  "$new_tag" python -c 'import cryptography; print("STAGING_PHASE2B_CRYPTOGRAPHY_IMPORT_OK")'
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_OLD_SITES_UNCHANGED_HTTP_200')
PY
echo STAGING_PHASE2B_OFFLINE_IMAGE_BUILT_NO_SWITCH
echo "STAGING_PHASE2B_NEW_DIR=$new"
