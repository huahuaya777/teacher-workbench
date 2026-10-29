#!/usr/bin/env bash
# One-time recovery drill for the 2026-10-28 NAS-imported fictional pilot data
# paired with the previously returned USB escrow.
# No online pilot or staging volume is mounted or modified.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -u)" != 0 || "$#" != 1 ]]; then
  echo PILOT_RESTORE_WRONG_HOST_OR_USER
  exit 1
fi

if [[ "$1" != pilot-scheduled-data-VSvbzq8S-629eb6f5a62a ]]; then
  echo PILOT_SCHEDULED_NAS_NAME_UNEXPECTED
  exit 1
fi

nas_name="$1"
nas_suffix="${nas_name##*-}"
pilot=/home/huahua/teacher-workbench-pilot
scheduled_root=/var/lib/teacher-workbench-pilot-scheduled
backup="$scheduled_root/nas-import-$nas_name"
escrow=/home/huahua/teacher-workbench-pilot-offline-escrow-restore-b2f424c27b5a
restore="$scheduled_root/nas-restore-$nas_suffix"
keyring="$scheduled_root/nas-restore-keyring-$nas_suffix"
network="tw-pilot-snas-$nas_suffix"
db="tw-pilot-snas-db-$nas_suffix"
redis="tw-pilot-snas-redis-$nas_suffix"
volume_prefix="tw-pilot-snas-$nas_suffix"

[[ ! -L "$pilot" && -d "$pilot" && "$(cat "$pilot/STATE")" == PILOT_STARTED_AI_OFF ]]
[[ ! -L "$scheduled_root" && "$(stat -c '%a:%u' "$scheduled_root")" == 700:0 ]]
[[ ! -L "$backup" && -d "$backup" && "$(cat "$backup/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(stat -c '%a:%u' "$backup")" == 700:0 ]]
[[ "$(cat "$backup/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
[[ ! -L "$escrow" && -d "$escrow" && "$(cat "$escrow/STATE")" == PILOT_ESCROW_COMPLETE ]]
[[ "$(stat -c '%a' "$escrow")" == 700 ]]
[[ ! -e "$restore" && ! -L "$restore" && ! -e "$keyring" && ! -L "$keyring" ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$backup" && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ "$(sha256sum "$backup/SHA256SUMS" | cut -d ' ' -f 1)" == 3d2047b572e6ad081d47b8c88d93afe7fe8d94b7fb4e8ec556c9279b4e657805 ]]
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(sha256sum "$pilot/pilot-root-ca.crt" | cut -d ' ' -f 1)" == "$(cat "$backup/CA_SHA256")" ]]
tar -tzf "$backup/source.tar.gz" >/dev/null
tar -tzf "$backup/private.tar.gz" >/dev/null
tar -tzf "$backup/redis.tar.gz" >/dev/null
tar -tzf "$escrow/caddy_data.tar.gz" >/dev/null
tar -tzf "$escrow/caddy_config.tar.gz" >/dev/null
gzip -t "$backup/images.tar.gz"
readarray -t images < "$backup/IMAGE_IDS"
[[ "${#images[@]}" == 4 ]]
for image in "${images[@]}"; do [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]; done

for image in "${images[@]}"; do
  [[ "$(timeout 10s docker image inspect -f '{{.Id}}' "$image")" == "$image" ]]
done
for name in "$db" "$redis"; do
  [[ -z "$(timeout 10s docker ps -a --filter "name=^${name}$" --format '{{.Names}}')" ]]
done
[[ -z "$(timeout 10s docker network ls --filter "name=^${network}$" --format '{{.Name}}')" ]]
for part in db redis private caddy_data caddy_config; do
  [[ -z "$(timeout 10s docker volume ls --filter "name=^${volume_prefix}-${part}$" --format '{{.Name}}')" ]]
done
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
  https://10.0.30.5:18443/login/)" == 200 ]]
echo PILOT_RESTORE_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$restore" "$keyring"
install -m 600 "$escrow/v1.key" "$keyring/v1.key"
python3 - "$escrow/env.pilot" "$restore/db.env" <<'PY'
from pathlib import Path
import os
import sys
values = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines() if '=' in line)
payload = '\n'.join((
    'POSTGRES_DB=' + values['DB_NAME'],
    'POSTGRES_USER=' + values['DB_USER'],
    'POSTGRES_PASSWORD=' + values['DB_PASSWORD'],
)) + '\n'
fd = os.open(sys.argv[2], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8') as output:
    output.write(payload)
PY

started=0
stop_if_needed() {
  if [[ "$started" == 1 ]]; then
    timeout 60s docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo PILOT_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_if_needed EXIT

timeout 30s docker network create --internal --subnet 10.251.36.0/28 \
  --gateway 10.251.36.1 "$network" >/dev/null
for part in db redis private caddy_data caddy_config; do
  timeout 30s docker volume create "${volume_prefix}-${part}" >/dev/null
done
for part in private redis; do
  timeout 180s docker run --pull never --rm -i --network none --user 0:0 \
    -v "${volume_prefix}-${part}:/data" --entrypoint sh "${images[2]}" \
    -c 'cd /data && tar -xzf -' < "$backup/$part.tar.gz"
done
for part in caddy_data caddy_config; do
  timeout 180s docker run --pull never --rm -i --network none --user 0:0 \
    -v "${volume_prefix}-${part}:/data" --entrypoint sh "${images[2]}" \
    -c 'cd /data && tar -xzf -' < "$escrow/$part.tar.gz"
done
recovered_ca_hash="$(timeout 20s docker run --pull never --rm --network none \
  -v "${volume_prefix}-caddy_data:/data:ro" --entrypoint cat "${images[2]}" \
  /data/caddy/pki/authorities/local/root.crt | sha256sum | cut -d ' ' -f 1)"
[[ "$recovered_ca_hash" == "$(cat "$backup/CA_SHA256")" ]]
echo PILOT_RESTORE_PRIVATE_REDIS_AND_CA_READY

started=1
timeout 60s docker run --pull never -d --name "$db" --network "$network" \
  --network-alias db --env-file "$restore/db.env" \
  -v "${volume_prefix}-db:/var/lib/postgresql/data" "${images[1]}" >/dev/null
timeout 60s docker run --pull never -d --name "$redis" --network "$network" \
  --network-alias redis -v "${volume_prefix}-redis:/data" \
  "${images[2]}" redis-server --appendonly yes >/dev/null
ready=0
for attempt in $(seq 1 30); do
  if timeout 5s docker exec "$db" psql -U teacher_workbench_pilot \
      -d teacher_workbench_pilot -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]]
timeout 180s docker exec -i "$db" pg_restore --exit-on-error \
  --no-owner --no-privileges -U teacher_workbench_pilot \
  -d teacher_workbench_pilot < "$backup/db.dump"
echo PILOT_RESTORE_POSTGRES_READY

timeout 90s docker run --pull never --rm -i --network "$network" \
  --env-file "$escrow/env.pilot" -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e "PILOT_KEYRING_DIR=$keyring" -e PRIVATE_FILE_ROOT=/app/data/private \
  -e MODEL_KEYRING_DIR=/run/model-keyring \
  -v "${volume_prefix}-private:/app/data/private:ro" \
  -v "$keyring:/run/model-keyring:ro" \
  -v "$pilot/check_pilot_env.py:/app/scripts/check_pilot_env.py:ro" \
  "${images[0]}" python - <<'PY'
import django
django.setup()
import hashlib
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from django.test import Client
from workbench.credential_vault import vault_ready
from workbench.models import Material, Worksheet, ModelCredential, CallAllowance

assert settings.DEBUG is False and not settings.AI_ENABLED
assert not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_LOCAL_QUEUE
assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.DATABASES['default']['HOST'] == 'db'
assert vault_ready()
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
user_model = get_user_model()
assert user_model.objects.count() == 2
manager = user_model.objects.get(username='pilot_manager_20261026')
assert manager.is_active and not manager.is_staff and not manager.is_superuser
assert manager.has_usable_password() and manager.has_perm('workbench.manage_members')
assert list(manager.user_permissions.values_list('codename', flat=True)) == ['manage_members']
member = user_model.objects.exclude(pk=manager.pk).get()
assert member.is_active and not member.is_staff and not member.is_superuser
assert member.has_usable_password() and not member.has_perm('workbench.manage_members')
assert Worksheet.objects.count() == 0
assert Material.objects.count() == 1
material = Material.objects.get(owner=manager, original_name='离线排版样例-学生卷.docx')
assert material.pk == 1
assert material.size_bytes == 36991 and bool(material.extracted_text)
with material.file.open('rb') as source:
    assert hashlib.sha256(source.read()).hexdigest() == '8eceaa539c91797cdb742ad4d0be9f207ecfc1ed9cb9895e7bd90470221d29d5'
assert ModelCredential.objects.count() == 0 and CallAllowance.objects.count() == 0
assert Client().get('/login/', secure=True, HTTP_HOST='10.0.30.5').status_code == 200
browser = Client()
browser.force_login(manager)
assert browser.get('/members/', secure=True, HTTP_HOST='10.0.30.5').status_code == 200
assert browser.get('/materials/', secure=True, HTTP_HOST='10.0.30.5').status_code == 200
download = browser.get(f'/materials/{material.pk}/download/', secure=True, HTTP_HOST='10.0.30.5')
assert download.status_code == 200
assert hashlib.sha256(b''.join(download.streaming_content)).hexdigest() == '8eceaa539c91797cdb742ad4d0be9f207ecfc1ed9cb9895e7bd90470221d29d5'
other_browser = Client()
other_browser.force_login(member)
other_materials = other_browser.get('/materials/', secure=True, HTTP_HOST='10.0.30.5')
assert other_materials.status_code == 200
assert material.original_name.encode('utf-8') not in other_materials.content
assert other_browser.get(f'/materials/{material.pk}/download/', secure=True,
                         HTTP_HOST='10.0.30.5').status_code == 404
assert other_browser.get('/members/', secure=True, HTTP_HOST='10.0.30.5').status_code == 403
print('PILOT_SCHEDULED_FIRST_NAS_RESTORE_CONTENT_AND_ACCESS_OK')
PY
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
  https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' \
  http://127.0.0.1:18002/login/)" == 200 ]]
timeout 60s docker stop "$redis" "$db" >/dev/null
started=0
printf 'PILOT_SCHEDULED_FIRST_NAS_RESTORE_COMPLETE_CONTAINERS_STOPPED_VOLUMES_PRESERVED\n' > "$restore/STATE"
echo PILOT_RESTORE_ONLINE_PILOT_AND_STAGING_STILL_HTTP_200
echo "PILOT_RESTORE_DIR=$restore"
echo PILOT_SCHEDULED_20261028_NAS_USB_INDEPENDENT_RESTORE_VERIFIED
