#!/usr/bin/env bash
# Restore NAS-imported fictional 2B data with a key recovered from USB.
# Never mount the online keyring or same-host escrow.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 2 ]]; then
  echo STAGING_2B_RESTORE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
backup="$1"
if [[ "$backup" != /home/huahua/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b ]]; then
  echo STAGING_2B_RESTORE_BACKUP_PATH_UNSAFE
  exit 1
fi
recovered="$2"
if [[ ! "$recovered" =~ ^/home/huahua/teacher-workbench-staging-offline-key-restore-([0-9a-f]{12})$ ]]; then
  echo STAGING_2B_RESTORE_RECOVERED_KEY_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
prefix="teacher-workbench-staging-phase2b-usb-restore-$suffix"
restore="$HOME/$prefix"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db="$prefix-db"
redis="$prefix-redis"

for directory in "$backup" "$recovered"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_2B_RESTORE_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
[[ ! -e "$restore" && ! -L "$restore" ]] || { echo STAGING_2B_RESTORE_TARGET_EXISTS; exit 1; }
for file in db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID KEY_SHA256 SHA256SUMS STATE NAS_SHA256SUMS NAS_TRANSFER_STATE; do
  if [[ -L "$backup/$file" || ! -f "$backup/$file" || "$(stat -c %a "$backup/$file")" != 600 ]]; then
    echo "STAGING_2B_RESTORE_BACKUP_FILE_UNSAFE=$file"
    exit 1
  fi
done
for file in v1.key; do
  if [[ -L "$recovered/$file" || ! -f "$recovered/$file" || "$(stat -c %a "$recovered/$file")" != 600 ]]; then
    echo "STAGING_2B_RESTORE_KEY_FILE_UNSAFE=$file"
    exit 1
  fi
done
[[ "$(cat "$backup/STATE")" == STAGING_2B_CREDENTIAL_BACKUP_COMPLETE ]]
[[ "$(cat "$backup/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$backup" && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ "$(sha256sum "$recovered/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
gzip -t "$backup/app-image.tar.gz"
python3 - "$backup/source.tar.gz" "$backup/private.tar.gz" <<'PY'
from pathlib import PurePosixPath
import sys
import tarfile
for index, path in enumerate(sys.argv[1:]):
    with tarfile.open(path, 'r:gz') as archive:
        names = set()
        for member in archive:
            name = PurePosixPath(member.name)
            if name.is_absolute() or '..' in name.parts or not (member.isfile() or member.isdir()) or str(name) in names:
                raise SystemExit('STAGING_2B_RESTORE_UNSAFE_ARCHIVE')
            names.add(str(name))
        if index == 0 and not {'manage.py', 'compose.staging.yaml'}.issubset(names):
            raise SystemExit('STAGING_2B_RESTORE_SOURCE_INCOMPLETE')
        if index == 1 and not any(name.startswith('materials/') or name.startswith('./materials/') for name in names):
            raise SystemExit('STAGING_2B_RESTORE_PRIVATE_INCOMPLETE')
PY
echo STAGING_2B_RESTORE_BACKUP_AND_KEY_VERIFIED

sudo -v
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
timeout 10s sudo -n docker image inspect postgres:17 redis:7-alpine "$image" >/dev/null
for name in "$db_volume" "$private_volume"; do
  if sudo -n docker volume inspect "$name" >/dev/null 2>&1; then
    echo STAGING_2B_RESTORE_VOLUME_EXISTS
    exit 1
  fi
done
if sudo -n docker network inspect "$network" >/dev/null 2>&1; then
  echo STAGING_2B_RESTORE_NETWORK_EXISTS
  exit 1
fi
for name in "$db" "$redis"; do
  if sudo -n docker container inspect "$name" >/dev/null 2>&1; then
    echo STAGING_2B_RESTORE_CONTAINER_EXISTS
    exit 1
  fi
done
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002,):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2B_RESTORE_SOURCE_LOGIN_HTTP_200')
PY
echo STAGING_2B_RESTORE_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$restore"
python3 - "$restore/.env.staging" <<'PY'
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
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as output:
    output.write('\n'.join(values) + '\n')
PY
started=0
stop_if_needed() {
  if [[ "$started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo STAGING_2B_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_if_needed EXIT
timeout 30s sudo -n docker network create "$network" >/dev/null
timeout 30s sudo -n docker volume create "$db_volume" >/dev/null
timeout 30s sudo -n docker volume create "$private_volume" >/dev/null
started=1
timeout 60s sudo -n docker run --pull never -d --name "$db" --network "$network" \
  --env-file "$restore/.env.staging" -v "$db_volume:/var/lib/postgresql/data" postgres:17 >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$redis" --network "$network" redis:7-alpine >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_2B_RESTORE_DB_NOT_READY; exit 1; }
timeout 180s sudo -n docker exec -i "$db" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench_staging -d teacher_workbench_staging < "$backup/db.dump"
echo STAGING_2B_RESTORE_POSTGRES_READY
timeout 180s sudo -n docker run --pull never --rm -i --network none --user 0:0 \
  -v "$private_volume:/data" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -xzf -' < "$backup/private.tar.gz"
echo STAGING_2B_RESTORE_PRIVATE_READY
timeout 90s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$restore/.env.staging" -e DB_HOST="$db" \
  -e REDIS_URL="redis://$redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private \
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1 \
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0 -e AI_STAGING_MANUAL_QUEUE=1 \
  -v "$private_volume:/app/data/private:ro" -v "$recovered:/run/model-keyring:ro" \
  "$image" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, override_settings
from django.urls import reverse
from workbench.credential_vault import unseal_key_for_owner, vault_ready
from workbench.models import Material, ModelCredential, Worksheet, WorksheetVersion

assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.DATABASES['default']['HOST'].startswith('teacher-workbench-staging-phase2b-usb-restore-')
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert vault_ready()
users = get_user_model().objects
owner = users.get(username='staging_teacher_a_20261018', is_active=True)
manager = users.get(username='staging_manager_20261018', is_active=True)
credentials = list(ModelCredential.objects.filter(owner=owner).order_by('pk'))
assert len(credentials) >= 2
assert all(item.key_version == 1 and unseal_key_for_owner(item, owner.pk).startswith('sk-fictional-')
           for item in credentials)
preview_owner = users.get(username='staging_preview_20261017')
material = Material.objects.get(owner=preview_owner, pk=1)
worksheet = Worksheet.objects.get(owner=preview_owner, pk=1)
assert WorksheetVersion.objects.filter(worksheet=worksheet, number=2).exists()
with override_settings(ALLOWED_HOSTS=['testserver']):
    browser = Client()
    browser.force_login(preview_owner)
    response = browser.get(reverse('download_material', args=[material.pk]))
    assert response.status_code == 200
    response.close()
    browser.force_login(owner)
    listing = browser.get(reverse('credential_list'))
    assert all(item.label in listing.content.decode() for item in credentials)
    assert browser.get(reverse('download_material', args=[material.pk])).status_code == 404
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 404
    browser.force_login(manager)
    manager_list = browser.get(reverse('credential_list'))
    assert all(item.label not in manager_list.content.decode() for item in credentials)
    assert browser.post(reverse('credential_replace', args=[credentials[0].pk]),
                        {'api_key': 'sk-fictional-denied-123456'}).status_code == 404
    assert browser.post(reverse('credential_delete', args=[credentials[0].pk])).status_code == 404
print('STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK')
PY
timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null
started=0
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002,):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2B_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE')
PY
echo STAGING_2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED
echo STAGING_2B_USB_KEY_NAS_DATA_RESTORE_VERIFIED
echo "STAGING_2B_USB_RESTORE_DIR=$restore"
