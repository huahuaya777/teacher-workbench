#!/usr/bin/env bash
# Independently restore the fictional 2A staging snapshot to fresh Docker
# volumes with no public ports. The source stack is only read.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua || "$HOME" != /home/huahua || "$#" != 1 ]]; then
  echo STAGING_PHASE2B_RESTORE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
backup="$1"
root="$HOME/teacher-workbench-staging-backups"
stage="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-([A-Za-z0-9]{8})$ ]]; then
  echo STAGING_PHASE2B_RESTORE_BACKUP_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
prefix="teacher-workbench-staging-phase2b-pre-restore-$suffix"
restore="$HOME/$prefix"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db="$prefix-db"
redis="$prefix-redis"
if [[ -L "$root" || -L "$backup" || ! -d "$backup" ||
      "$(stat -c %a "$root")" != 700 || "$(stat -c %a "$backup")" != 700 ||
      -e "$restore" || -L "$restore" || -L "$stage" || ! -d "$stage" ||
      "$(stat -c %a "$stage")" != 700 ]]; then
  echo STAGING_PHASE2B_RESTORE_SOURCE_OR_TARGET_UNSAFE
  exit 1
fi
[[ "$(cat "$backup/STATE")" == STAGING_PHASE2B_PRE_BACKUP_COMPLETE ]]
for file in db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID SHA256SUMS STATE; do
  if [[ -L "$backup/$file" || ! -f "$backup/$file" || "$(stat -c %a "$backup/$file")" != 600 ]]; then
    echo "STAGING_PHASE2B_RESTORE_BACKUP_FILE_UNSAFE=$file"
    exit 1
  fi
done
echo STAGING_PHASE2B_RESTORE_BACKUP_VERIFY_START
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
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
                raise SystemExit('STAGING_PHASE2B_RESTORE_UNSAFE_ARCHIVE')
            names.add(str(name))
        required = {'manage.py', 'compose.staging.yaml'} if index == 0 else {'materials'}
        if index == 0 and not required.issubset(names):
            raise SystemExit('STAGING_PHASE2B_RESTORE_SOURCE_INCOMPLETE')
        if index == 1 and not any(name.startswith('materials/') or name.startswith('./materials/') for name in names):
            raise SystemExit('STAGING_PHASE2B_RESTORE_PRIVATE_INCOMPLETE')
PY
echo STAGING_PHASE2B_RESTORE_BACKUP_VERIFIED
sudo -v
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$image" ]]
timeout 10s sudo -n docker image inspect postgres:17 redis:7-alpine "$image" >/dev/null
for name in "$db_volume" "$private_volume"; do
  if sudo -n docker volume inspect "$name" >/dev/null 2>&1; then
    echo STAGING_PHASE2B_RESTORE_VOLUME_EXISTS
    exit 1
  fi
done
if sudo -n docker network inspect "$network" >/dev/null 2>&1; then
  echo STAGING_PHASE2B_RESTORE_NETWORK_EXISTS
  exit 1
fi
for name in "$db" "$redis"; do
  if sudo -n docker container inspect "$name" >/dev/null 2>&1; then
    echo STAGING_PHASE2B_RESTORE_CONTAINER_EXISTS
    exit 1
  fi
done
echo STAGING_PHASE2B_RESTORE_ISOLATION_PREFLIGHT_OK

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
echo STAGING_PHASE2B_RESTORE_TEST_ENV_READY

started=1
stop_if_needed() {
  if [[ "$started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 || echo STAGING_PHASE2B_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_if_needed EXIT
timeout 30s sudo -n docker network create "$network" >/dev/null
timeout 30s sudo -n docker volume create "$db_volume" >/dev/null
timeout 30s sudo -n docker volume create "$private_volume" >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$db" --network "$network" \
  --env-file "$restore/.env.staging" -v "$db_volume:/var/lib/postgresql/data" postgres:17 >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$redis" --network "$network" redis:7-alpine >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$db" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_PHASE2B_RESTORE_DB_NOT_READY; exit 1; }
echo STAGING_PHASE2B_RESTORE_EMPTY_DATABASE_READY
timeout 180s sudo -n docker exec -i "$db" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench_staging -d teacher_workbench_staging < "$backup/db.dump"
echo STAGING_PHASE2B_RESTORE_POSTGRES_READY
timeout 180s sudo -n docker run --pull never --rm -i --network none --user 0:0 \
  -v "$private_volume:/data" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -xzf -' < "$backup/private.tar.gz"
echo STAGING_PHASE2B_RESTORE_PRIVATE_READY
timeout 90s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$restore/.env.staging" -e DB_HOST="$db" \
  -e REDIS_URL="redis://$redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private \
  -v "$private_volume:/app/data/private:ro" "$image" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, override_settings
from django.urls import reverse
from workbench.models import Material, Worksheet, WorksheetVersion

assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.DATABASES['default']['HOST'].startswith('teacher-workbench-staging-phase2b-pre-restore-')
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
users = get_user_model().objects
assert users.filter(username='staging_manager_20261018').exists()
assert users.filter(username='staging_teacher_a_20261018', is_active=True).exists()
owner = users.get(username='staging_preview_20261017')
material = Material.objects.get(owner=owner, pk=1)
worksheet = Worksheet.objects.get(owner=owner, pk=1)
assert WorksheetVersion.objects.filter(worksheet=worksheet, number=2).exists()
with override_settings(ALLOWED_HOSTS=['testserver']):
    browser = Client()
    browser.force_login(owner)
    response = browser.get(reverse('download_material', args=[material.pk]))
    assert response.status_code == 200
    response.close()
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 200
    other = users.get(username='staging_teacher_a_20261018')
    browser.force_login(other)
    assert browser.get(reverse('download_material', args=[material.pk])).status_code == 404
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 404
print('STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK')
PY
timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null
started=0
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_PHASE2B_SOURCE_AND_OLD_TEST_LOGIN_HTTP_200')
PY
echo STAGING_PHASE2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED
echo STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED
echo "STAGING_PHASE2B_PRE_RESTORE_DIR=$restore"
