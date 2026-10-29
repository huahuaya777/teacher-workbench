#!/usr/bin/env bash
# Only fictional credentials: migrate the stopped 2A restore, back up its
# encrypted test row with a separate key copy, then restore into fresh volumes.
# The online staging database, web and gateway remain untouched; AI stays off.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua || "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_PHASE2B_KEY_TEST_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
old="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
new="$HOME/teacher-workbench-staging-phase2b-20261020"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2b-pre-lESMk1Nj"
restore="$HOME/teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj"
keyring="$HOME/teacher-workbench-staging-model-keyring"
key_helper="$HOME/prepare_ubuntu_staging_model_keyring.py"
recovery="$HOME/teacher-workbench-staging-phase2b-fictional-recovery-lESMk1Nj"
src_prefix=teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj
dst_prefix=teacher-workbench-staging-phase2b-key-restore-lESMk1Nj
src_db="$src_prefix-db"
src_redis="$src_prefix-redis"
src_net="$src_prefix-net"
src_private="$src_prefix-private"
dst_db="$dst_prefix-db"
dst_redis="$dst_prefix-redis"
dst_net="$dst_prefix-net"
dst_private="$dst_prefix-private"
dst_db_volume="$dst_prefix-db"
new_tag=teacher-workbench-staging-web:credentials-20261020
old_tag=teacher-workbench-staging-web:accounts-20261018
fake_key=sk-fictional-phase2b-recovery-123456

for directory in "$old" "$new" "$backup" "$restore"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_PHASE2B_KEY_TEST_INPUT_DIRECTORY_UNSAFE
    exit 1
  fi
done
if [[ -e "$keyring" || -L "$keyring" || -e "$recovery" || -L "$recovery" ]]; then
  echo STAGING_PHASE2B_KEY_TEST_TARGET_EXISTS
  exit 1
fi
for file in "$key_helper" "$restore/.env.staging" "$backup/SHA256SUMS" "$backup/STATE"; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    echo STAGING_PHASE2B_KEY_TEST_INPUT_MISSING_OR_LINK
    exit 1
  fi
done
[[ "$(sha256sum "$key_helper" | cut -d ' ' -f 1)" == 9c1d1f1af67fb03d880e1dbf826e8bf998289bcf46f202277de696f6bcf946d0 ]]
[[ "$(stat -c %a "$restore/.env.staging")" == 600 ]]
[[ "$(cat "$backup/STATE")" == STAGING_PHASE2B_PRE_BACKUP_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
grep -Fxq '      MODEL_KEYRING_DIR: /run/model-keyring' "$new/compose.staging.yaml"
grep -Fxq '      AI_ENABLED: "0"' "$new/compose.staging.yaml"
grep -Fxq '      AI_API_KEY: ""' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"

sudo -v
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == \
   "$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" ]]
new_image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$new_image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
for container in "$src_db" "$src_redis"; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
done
timeout 10s sudo -n docker network inspect "$src_net" >/dev/null
timeout 10s sudo -n docker volume inspect "$src_private" >/dev/null
for name in "$dst_db_volume" "$dst_private"; do
  if sudo -n docker volume inspect "$name" >/dev/null 2>&1; then
    echo STAGING_PHASE2B_KEY_TEST_TARGET_VOLUME_EXISTS
    exit 1
  fi
done
if sudo -n docker network inspect "$dst_net" >/dev/null 2>&1; then
  echo STAGING_PHASE2B_KEY_TEST_TARGET_NETWORK_EXISTS
  exit 1
fi
for name in "$dst_db" "$dst_redis"; do
  if sudo -n docker container inspect "$name" >/dev/null 2>&1; then
    echo STAGING_PHASE2B_KEY_TEST_TARGET_CONTAINER_EXISTS
    exit 1
  fi
done
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_KEY_TEST_SOURCE_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_KEY_TEST_PREFLIGHT_OK

python3 "$key_helper"
[[ "$(stat -c %a "$keyring")" == 700 ]]
[[ "$(stat -c %a "$keyring/v1.key")" == 600 ]]
echo STAGING_PHASE2B_KEYRING_PERMISSIONS_OK

src_started=0
dst_started=0
stop_if_needed() {
  if [[ "$dst_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$dst_redis" "$dst_db" >/dev/null 2>&1 || echo STAGING_PHASE2B_KEY_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$src_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$src_redis" "$src_db" >/dev/null 2>&1 || echo STAGING_PHASE2B_SOURCE_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_if_needed EXIT

src_started=1
timeout 40s sudo -n docker start "$src_db" "$src_redis" >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$src_db" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_PHASE2B_KEY_TEST_SOURCE_DB_NOT_READY; exit 1; }

run_source=(sudo -n docker run --pull never --rm -i --network "$src_net"
  --env-file "$restore/.env.staging" -e DB_HOST="$src_db"
  -e REDIS_URL="redis://$src_redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1
  -v "$src_private:/app/data/private:ro" -v "$keyring:/run/model-keyring:ro" "$new_tag")
timeout 120s "${run_source[@]}" python manage.py migrate --noinput
timeout 45s "${run_source[@]}" python manage.py check
timeout 180s "${run_source[@]}" python manage.py test workbench.tests_credentials --verbosity 0
echo STAGING_PHASE2B_ISOLATED_MIGRATION_AND_TESTS_OK

timeout 45s "${run_source[@]}" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from workbench.credential_vault import seal_key, unseal_key_for_owner, vault_ready
from workbench.models import ModelCredential, WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert settings.MODEL_KEYRING_DIR == '/run/model-keyring' and vault_ready()
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
assert not ModelCredential.objects.exists()
credential = ModelCredential(owner=owner, label='隔离恢复虚构配置', provider='qwen',
    api_base_url='https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
    model_name='qwen-flash')
seal_key(credential, 'sk-fictional-phase2b-recovery-123456')
credential.save(force_insert=True)
assert credential.key_version == 1
assert unseal_key_for_owner(credential, owner.pk) == 'sk-fictional-phase2b-recovery-123456'
print('STAGING_PHASE2B_FICTIONAL_CREDENTIAL_ENCRYPTED')
PY

mkdir -m 700 "$recovery"
mkdir -m 700 "$recovery/keyring" "$recovery/wrong-keyring"
install -m 600 "$keyring/v1.key" "$recovery/keyring/v1.key"
python3 - "$recovery/wrong-keyring/v1.key" <<'PY'
import base64
import os
import sys
fd = os.open(sys.argv[1], os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
with os.fdopen(fd, 'wb') as output:
    output.write(base64.b64encode(os.urandom(32)) + b'\n')
PY
echo STAGING_PHASE2B_FICTIONAL_KEY_COPIED_PRIVATELY
timeout 180s sudo -n docker exec "$src_db" sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$recovery/db.dump"
install -m 600 "$backup/private.tar.gz" "$recovery/private.tar.gz"
printf '%s\n' "$new_image_id" > "$recovery/APP_IMAGE_ID"
if grep -aFq "$fake_key" "$recovery/db.dump"; then
  echo STAGING_PHASE2B_PLAINTEXT_FOUND_IN_DATABASE_DUMP
  exit 1
fi
(cd "$recovery" && sha256sum db.dump private.tar.gz keyring/v1.key APP_IMAGE_ID > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
timeout 20s sudo -n docker exec -i "$src_db" pg_restore --list < "$recovery/db.dump" >/dev/null
echo STAGING_PHASE2B_FICTIONAL_ENCRYPTED_BACKUP_VERIFIED

python3 - "$recovery/.env.staging" <<'PY'
import os
import secrets
import sys
password = secrets.token_hex(24)
values = [
    'DJANGO_DEBUG=1', f'DJANGO_SECRET_KEY={secrets.token_hex(32)}',
    'DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver',
    'DB_NAME=teacher_workbench_staging', 'DB_USER=teacher_workbench_staging',
    f'DB_PASSWORD={password}', 'TW_STAGING=1',
    'POSTGRES_DB=teacher_workbench_staging', 'POSTGRES_USER=teacher_workbench_staging',
    f'POSTGRES_PASSWORD={password}', 'DJANGO_SETTINGS_MODULE=config.settings_staging',
    'AI_ENABLED=0', 'AI_API_KEY=', 'AI_LOCAL_QUEUE=0', 'AI_STAGING_MANUAL_QUEUE=1',
]
fd = os.open(sys.argv[1], os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as output:
    output.write('\n'.join(values) + '\n')
PY
timeout 30s sudo -n docker network create "$dst_net" >/dev/null
timeout 30s sudo -n docker volume create "$dst_db_volume" >/dev/null
timeout 30s sudo -n docker volume create "$dst_private" >/dev/null
dst_started=1
timeout 60s sudo -n docker run --pull never -d --name "$dst_db" --network "$dst_net" \
  --env-file "$recovery/.env.staging" -v "$dst_db_volume:/var/lib/postgresql/data" postgres:17 >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$dst_redis" --network "$dst_net" redis:7-alpine >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$dst_db" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_PHASE2B_KEY_RESTORE_DB_NOT_READY; exit 1; }
timeout 180s sudo -n docker exec -i "$dst_db" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench_staging -d teacher_workbench_staging < "$recovery/db.dump"
timeout 180s sudo -n docker run --pull never --rm -i --network none --user 0:0 \
  -v "$dst_private:/data" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -xzf -' < "$recovery/private.tar.gz"
echo STAGING_PHASE2B_FICTIONAL_RESTORE_DB_AND_PRIVATE_READY

run_target=(sudo -n docker run --pull never --rm -i --network "$dst_net"
  --env-file "$recovery/.env.staging" -e DB_HOST="$dst_db"
  -e REDIS_URL="redis://$dst_redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1
  -v "$dst_private:/app/data/private:ro")
timeout 45s "${run_target[@]}" -v "$recovery/keyring:/run/model-keyring:ro" "$new_tag" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from workbench.credential_vault import unseal_key_for_owner
from workbench.models import ModelCredential, WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
credential = ModelCredential.objects.get(label='隔离恢复虚构配置')
assert unseal_key_for_owner(credential, credential.owner_id) == 'sk-fictional-phase2b-recovery-123456'
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_PHASE2B_CORRECT_KEY_RESTORE_OK')
PY
timeout 45s "${run_target[@]}" -v "$recovery/wrong-keyring:/run/model-keyring:ro" "$new_tag" python - <<'PY'
import django
django.setup()
from workbench.credential_vault import VaultIntegrityError, unseal_key_for_owner
from workbench.models import ModelCredential
credential = ModelCredential.objects.get(label='隔离恢复虚构配置')
try:
    unseal_key_for_owner(credential, credential.owner_id)
except VaultIntegrityError:
    print('STAGING_PHASE2B_WRONG_KEY_FAILS_CLOSED')
else:
    raise SystemExit('STAGING_PHASE2B_WRONG_KEY_ACCEPTED')
PY
timeout 45s "${run_target[@]}" "$new_tag" python - <<'PY'
import django
django.setup()
from workbench.credential_vault import VaultUnavailable, unseal_key_for_owner
from workbench.models import ModelCredential
credential = ModelCredential.objects.get(label='隔离恢复虚构配置')
try:
    unseal_key_for_owner(credential, credential.owner_id)
except VaultUnavailable:
    print('STAGING_PHASE2B_MISSING_KEY_FAILS_CLOSED')
else:
    raise SystemExit('STAGING_PHASE2B_MISSING_KEY_ACCEPTED')
PY
timeout 40s sudo -n docker stop "$dst_redis" "$dst_db" >/dev/null
dst_started=0
timeout 40s sudo -n docker stop "$src_redis" "$src_db" >/dev/null
src_started=0
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_ONLINE_AND_OLD_TEST_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_FICTIONAL_KEY_RESTORE_VERIFIED_NO_ONLINE_SWITCH
echo "STAGING_PHASE2B_FICTIONAL_RECOVERY_DIR=$recovery"
