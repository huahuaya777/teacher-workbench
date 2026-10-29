#!/usr/bin/env bash
# Migrate only the fixed fictional 2B restore copy to 2C, never the online DB.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_RESTORE_MIGRATION_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

suffix=F6yZnxfi
source_sha=36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303
bundle="$HOME/teacher-workbench-stage2c-pg-source.tar.gz"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2b-keys-$suffix"
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-$suffix"
restore="$HOME/teacher-workbench-staging-phase2b-keys-restore-$suffix"
stage="$HOME/teacher-workbench-staging-phase2c-migration-$suffix"
prefix="teacher-workbench-staging-phase2b-keys-restore-$suffix"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db="$prefix-db"
redis="$prefix-redis"
probe="teacher-workbench-staging-phase2c-migration-$suffix-probe"
online_web=teacher-workbench-staging-web-1

for directory in "$HOME/teacher-workbench-staging-backups" "$backup" \
                 "$HOME/teacher-workbench-staging-key-escrow" "$escrow" "$restore"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_2C_RESTORE_MIGRATION_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$restore/.env.staging" "$escrow/v1.key" "$backup/APP_IMAGE_ID" \
            "$backup/KEY_SHA256" "$backup/SHA256SUMS" "$backup/STATE" "$escrow/SHA256SUMS"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_2C_RESTORE_MIGRATION_SOURCE_FILE_UNSAFE
    exit 1
  fi
done
if [[ -L "$bundle" || ! -f "$bundle" || -e "$stage" || -L "$stage" ]]; then
  echo STAGING_2C_RESTORE_MIGRATION_TARGET_OR_BUNDLE_UNSAFE
  exit 1
fi
[[ "$(sha256sum "$bundle" | cut -d ' ' -f 1)" == "$source_sha" ]]
[[ "$(cat "$backup/STATE")" == STAGING_2B_CREDENTIAL_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == STAGING_2B_KEY_ESCROW_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
python3 - "$bundle" <<'PY'
from pathlib import PurePosixPath
import sys
import tarfile

with tarfile.open(sys.argv[1], 'r:gz') as archive:
    members = archive.getmembers()
    names = [member.name for member in members]
    assert len(names) == 74 and len(set(names)) == len(names)
    for member in members:
        path = PurePosixPath(member.name)
        assert member.isfile() and not member.issym() and not member.islnk()
        assert not path.is_absolute() and '..' not in path.parts
        assert path.parts[0] in ('config', 'workbench', 'templates') or member.name in ('manage.py', 'requirements.txt')
    assert {'workbench/migrations/0006_callallowance_callattempt.py',
            'workbench/migrations/0007_alter_memberaudit_action.py',
            'workbench/migrations/0008_generationtask_member_credential_and_more.py'} <= set(names)
print('STAGING_2C_RESTORE_MIGRATION_SOURCE_VERIFIED')
PY

# The interactive SSH shell must already have authenticated sudo.
sudo -n -v || { echo STAGING_2C_RESTORE_MIGRATION_SUDO_AUTH_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$db")" == "$network" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$redis")" == "$network" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$db")" == "$db_volume" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$db")" == \
   "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' postgres:17)" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$redis")" == \
   "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' redis:7-alpine)" ]]
for container in "$db" "$redis"; do
  ports="$(timeout 15s sudo -n docker inspect -f '{{json .HostConfig.PortBindings}}' "$container")"
  [[ "$ports" == null || "$ports" == '{}' ]] || {
    echo STAGING_2C_RESTORE_MIGRATION_UNEXPECTED_PUBLISHED_PORT
    exit 1
  }
done
timeout 15s sudo -n docker network inspect "$network" >/dev/null
timeout 15s sudo -n docker volume inspect "$private_volume" >/dev/null
timeout 15s sudo -n docker image inspect "$image" >/dev/null
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$online_web")" == "$image" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$online_web")" == running ]]
if timeout 15s sudo -n docker container inspect "$probe" >/dev/null 2>&1; then
  echo STAGING_2C_RESTORE_MIGRATION_PROBE_EXISTS
  exit 1
fi
echo STAGING_2C_RESTORE_MIGRATION_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$stage"
mkdir -m 700 "$stage/src"
tar -xzf "$bundle" -C "$stage/src" --no-same-owner --no-same-permissions
printf 'INCOMPLETE\n' > "$stage/STATE"
echo STAGING_2C_RESTORE_MIGRATION_SOURCE_READY

services_started=0
probe_started=0
cleanup() {
  rc=$?
  if [[ "$probe_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$probe" >/dev/null 2>&1 || true
  fi
  if [[ "$services_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo STAGING_2C_RESTORE_MIGRATION_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$rc" != 0 ]]; then echo STAGING_2C_RESTORE_MIGRATION_FAILED; fi
}
trap cleanup EXIT

services_started=1
timeout 60s sudo -n docker start "$db" "$redis" >/dev/null
ready=0
for ((index=0; index<45; index++)); do
  if timeout 8s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_RESTORE_MIGRATION_DB_NOT_READY; exit 1; }
ready=0
for ((index=0; index<20; index++)); do
  if timeout 8s sudo -n docker exec "$redis" redis-cli ping 2>/dev/null | grep -Fxq PONG; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_RESTORE_MIGRATION_REDIS_NOT_READY; exit 1; }
old_count="$(timeout 15s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
  -d teacher_workbench_staging -Atqc "SELECT count(*) FROM django_migrations WHERE app='workbench' AND name='0005_modelcredential'")"
new_count="$(timeout 15s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
  -d teacher_workbench_staging -Atqc "SELECT count(*) FROM django_migrations WHERE app='workbench' AND name IN ('0006_callallowance_callattempt','0007_alter_memberaudit_action','0008_generationtask_member_credential_and_more')")"
[[ "$old_count" == 1 && "$new_count" == 0 ]] || {
  echo STAGING_2C_RESTORE_MIGRATION_SCHEMA_NOT_2B
  exit 1
}
echo STAGING_2C_RESTORE_MIGRATION_OLD_SCHEMA_VERIFIED

common_args=(--pull never --rm --name "$probe" --network "$network"
  --env-file "$restore/.env.staging" -e DB_HOST="$db"
  -e REDIS_URL="redis://$redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0
  -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0
  -v "$stage/src/manage.py:/app/manage.py:ro"
  -v "$stage/src/config:/app/config:ro"
  -v "$stage/src/workbench:/app/workbench:ro"
  -v "$stage/src/templates:/app/templates:ro"
  -v "$private_volume:/app/data/private:ro"
  -v "$escrow:/run/model-keyring:ro")
probe_started=1
timeout 180s sudo -n docker run "${common_args[@]}" "$image" python manage.py migrate --noinput
probe_started=0
echo STAGING_2C_RESTORE_MIGRATIONS_APPLIED

probe_started=1
timeout 90s sudo -n docker run -i "${common_args[@]}" "$image" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from django.test import Client, override_settings
from django.urls import reverse
from workbench.credential_vault import unseal_key_for_owner, vault_ready
from workbench.models import (CallAllowance, CallAttempt, GenerationTask,
                              Material, ModelCredential, Worksheet, WorksheetVersion)

assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.DATABASES['default']['HOST'] == 'teacher-workbench-staging-phase2b-keys-restore-F6yZnxfi-db'
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED
assert not settings.AI_API_KEY and settings.AI_STAGING_MANUAL_QUEUE and vault_ready()
applied = MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True)
assert {'0005_modelcredential', '0006_callallowance_callattempt',
        '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= set(applied)
assert not CallAllowance.objects.exists() and not CallAttempt.objects.exists()
assert not GenerationTask.objects.filter(member_mode=True).exists()
assert not GenerationTask.objects.filter(member_credential__isnull=False).exists()
users = get_user_model().objects
owner = users.get(username='staging_teacher_a_20261018', is_active=True)
manager = users.get(username='staging_manager_20261018', is_active=True)
preview_owner = users.get(username='staging_preview_20261017')
credentials = list(ModelCredential.objects.filter(owner=owner).order_by('pk'))
assert len(credentials) >= 2
assert all(item.key_version == 1 and unseal_key_for_owner(item, owner.pk).startswith('sk-fictional-')
           for item in credentials)
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
    assert browser.get(reverse('download_material', args=[material.pk])).status_code == 404
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 404
    browser.force_login(manager)
    assert browser.post(reverse('credential_replace', args=[credentials[0].pk]),
                        {'api_key': 'sk-fictional-denied-123456'}).status_code == 404
    assert browser.post(reverse('credential_delete', args=[credentials[0].pk])).status_code == 404
print('STAGING_2C_RESTORE_OLD_CONTENT_KEYS_AND_ACCESS_OK')
PY
probe_started=0
probe_started=1
timeout 60s sudo -n docker run "${common_args[@]}" "$image" python manage.py migrate --check --noinput
probe_started=0
echo STAGING_2C_RESTORE_MIGRATIONS_COMPLETE

timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null
services_started=0
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_RESTORE_ONLINE_LOGINS_STILL_HTTP_200')
PY
printf 'STAGING_2C_RESTORE_MIGRATION_COMPLETE\n' > "$stage/STATE"
echo STAGING_2C_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED
echo "STAGING_2C_RESTORE_MIGRATION_DIR=$stage"
echo STAGING_2C_RESTORE_MIGRATION_VERIFIED
