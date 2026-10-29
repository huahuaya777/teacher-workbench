#!/usr/bin/env bash
# Restore the fixed post-formula pilot snapshot from the read-only NAS import.
# All restored services use new Docker names, an internal network, and new volumes.
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 && "$#" == 0 ]]
root=/var/lib/teacher-workbench-pilot-scheduled
pilot=/home/huahua/teacher-workbench-pilot
name=pilot-scheduled-data-kfA4vmDj-8885b673fb19
source="$root/backups/backup-pilot-kfA4vmDj"
backup="$root/nas-import-$name"
escrow="$root/escrow/escrow-kfA4vmDj"
restore="$root/release-restore-8885b673fb19"
keyring="$restore/keyring"
network=tw-pilot-release-8885b673fb19
db=tw-pilot-release-db-8885b673fb19
redis=tw-pilot-release-redis-8885b673fb19
volume=tw-pilot-release-8885b673fb19
app=sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64
audit=/home/huahua/audit_pilot_teacher_math_export.py

[[ -d "$pilot" && ! -L "$pilot" && "$(cat "$pilot/STATE")" == PILOT_STARTED_MEMBER_AI ]]
[[ -d "$backup" && ! -L "$backup" && "$(stat -c '%u:%a' "$backup")" == 0:700 ]]
[[ -d "$escrow" && ! -L "$escrow" && "$(stat -c '%u:%a' "$escrow")" == 0:700 ]]
[[ "$(cat "$backup/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(cat "$backup/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == PILOT_ESCROW_COMPLETE ]]
[[ ! -e "$restore" && ! -L "$restore" ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
(cd "$source" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
cmp -s "$source/SHA256SUMS" "$backup/SHA256SUMS"
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(sha256sum "$pilot/pilot-root-ca.crt" | cut -d ' ' -f 1)" == "$(cat "$backup/CA_SHA256")" ]]
tar -tzf "$backup/source.tar.gz" >/dev/null
tar -tzf "$backup/private.tar.gz" >/dev/null
tar -tzf "$backup/redis.tar.gz" >/dev/null
tar -tzf "$escrow/caddy_data.tar.gz" >/dev/null
tar -tzf "$escrow/caddy_config.tar.gz" >/dev/null
gzip -t "$backup/images.tar.gz"
readarray -t images < "$backup/IMAGE_IDS"
[[ "${#images[@]}" == 4 && "${images[0]}" == "$app" ]]
for image in "${images[@]}"; do
  [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
  [[ "$(timeout 10s docker image inspect -f '{{.Id}}' "$image")" == "$image" ]]
done
for item in "$db" "$redis"; do
  [[ -z "$(docker ps -a --filter "name=^${item}$" --format '{{.Names}}')" ]]
done
[[ -z "$(docker network ls --filter "name=^${network}$" --format '{{.Name}}')" ]]
for part in db redis private caddy_data caddy_config; do
  [[ -z "$(docker volume ls --filter "name=^${volume}-${part}$" --format '{{.Name}}')" ]]
done
[[ "$(curl --noproxy '*' -fsS --max-time 8 --cacert "$pilot/pilot-root-ca.crt" \
  -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/)" == 200 ]]
echo PILOT_RELEASE_RESTORE_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$restore" "$keyring"
install -m 600 "$escrow/v1.key" "$keyring/v1.key"
python3 - "$escrow/env.pilot" "$restore/db.env" <<'PY'
from pathlib import Path
import os, sys
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
stop_restored() {
  if [[ "$started" == 1 ]]; then
    timeout 60s docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo PILOT_RELEASE_RESTORE_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_restored EXIT
timeout 30s docker network create --internal --subnet 10.251.39.0/28 \
  --gateway 10.251.39.1 "$network" >/dev/null
for part in db redis private caddy_data caddy_config; do
  timeout 30s docker volume create "${volume}-${part}" >/dev/null
done
for part in private redis; do
  timeout 180s docker run --pull never --rm -i --network none --user 0:0 \
    -v "${volume}-${part}:/data" --entrypoint sh "${images[2]}" \
    -c 'cd /data && tar -xzf -' < "$backup/$part.tar.gz"
done
for part in caddy_data caddy_config; do
  timeout 180s docker run --pull never --rm -i --network none --user 0:0 \
    -v "${volume}-${part}:/data" --entrypoint sh "${images[2]}" \
    -c 'cd /data && tar -xzf -' < "$escrow/$part.tar.gz"
done
ca_hash="$(timeout 20s docker run --pull never --rm --network none \
  -v "${volume}-caddy_data:/data:ro" --entrypoint cat "${images[2]}" \
  /data/caddy/pki/authorities/local/root.crt | sha256sum | cut -d ' ' -f 1)"
[[ "$ca_hash" == "$(cat "$backup/CA_SHA256")" ]]
echo PILOT_RELEASE_RESTORE_PRIVATE_REDIS_CA_READY

started=1
timeout 60s docker run --pull never -d --name "$db" --network "$network" \
  --network-alias db --env-file "$restore/db.env" \
  -v "${volume}-db:/var/lib/postgresql/data" "${images[1]}" >/dev/null
timeout 60s docker run --pull never -d --name "$redis" --network "$network" \
  --network-alias redis -v "${volume}-redis:/data" \
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
timeout 180s docker exec -i "$db" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench_pilot -d teacher_workbench_pilot < "$backup/db.dump"
echo PILOT_RELEASE_RESTORE_POSTGRES_READY

timeout 90s docker run --pull never --rm -i --network "$network" \
  --env-file "$escrow/env.pilot" -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e AI_ENABLED=1 -e AI_MEMBER_TASKS_ENABLED=1 \
  -e "PILOT_KEYRING_DIR=$keyring" -e PRIVATE_FILE_ROOT=/app/data/private \
  -e MODEL_KEYRING_DIR=/run/model-keyring \
  -v "${volume}-private:/app/data/private:ro" \
  -v "$keyring:/run/model-keyring:ro" \
  "$app" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from django.test import Client
from workbench.credential_vault import vault_ready, unseal_key_for_owner
from workbench.models import CallAllowance, CallAttempt, GenerationTask, Material, ModelCredential, WorksheetVersion

assert not settings.DEBUG and settings.AI_ENABLED and settings.AI_MEMBER_TASKS_ENABLED
assert not settings.AI_LOCAL_QUEUE and not settings.AI_API_KEY
assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert vault_ready()
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
users = get_user_model()
manager = users.objects.get(username='pilot_manager_20261026')
teacher = users.objects.get(username='huahua')
assert manager.is_active and manager.has_perm('workbench.manage_members')
assert teacher.is_active and not teacher.is_staff and not teacher.has_perm('workbench.manage_members')
assert users.objects.count() == 3
credential = ModelCredential.objects.get(owner=teacher)
assert credential.provider == 'qwen' and credential.model_name == 'qwen-flash'
assert len(unseal_key_for_owner(credential, teacher.pk)) >= 8
allowance = CallAllowance.objects.get(owner=teacher)
assert allowance.max_calls == 10 and allowance.used_calls >= 4 and allowance.reserved_calls == 0
assert GenerationTask.objects.filter(owner=teacher, status='done').exists()
assert CallAttempt.objects.filter(owner=teacher, status='completed').exists()
assert WorksheetVersion.objects.filter(worksheet__owner=teacher).exists()
material = Material.objects.get(owner=manager, original_name='离线排版样例-学生卷.docx')
browser = Client()
browser.force_login(teacher)
assert browser.get('/materials/', secure=True, HTTP_HOST='10.0.30.5').status_code == 200
assert browser.get(f'/materials/{material.pk}/download/', secure=True,
                   HTTP_HOST='10.0.30.5').status_code == 404
assert browser.get('/members/', secure=True, HTTP_HOST='10.0.30.5').status_code == 403
assert Client().get('/login/', secure=True, HTTP_HOST='10.0.30.5').status_code == 200
print('PILOT_RELEASE_RESTORE_ACCOUNTS_KEY_DRAFT_AND_ACCESS_OK')
PY

[[ "$(sha256sum "$audit" | cut -d ' ' -f 1)" == \
  688cb6b6e36cd1fc65cf430d040bdf90111691569522a7ceae7d32948f45e658 ]]
timeout 90s docker run --pull never --rm -i --network "$network" \
  --env-file "$escrow/env.pilot" -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e AI_ENABLED=1 -e AI_MEMBER_TASKS_ENABLED=1 \
  -e "PILOT_KEYRING_DIR=$keyring" -e PRIVATE_FILE_ROOT=/app/data/private \
  -e MODEL_KEYRING_DIR=/run/model-keyring \
  -v "${volume}-private:/app/data/private:ro" \
  -v "$keyring:/run/model-keyring:ro" \
  "$app" python - < "$audit"
[[ "$(curl --noproxy '*' -fsS --max-time 8 --cacert "$pilot/pilot-root-ca.crt" \
  -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl -fsS --max-time 8 -o /dev/null -w '%{http_code}' \
  http://127.0.0.1:18002/login/)" == 200 ]]
timeout 60s docker stop "$redis" "$db" >/dev/null
started=0
printf 'PILOT_RELEASE_RESTORE_COMPLETE_CONTAINERS_STOPPED_VOLUMES_PRESERVED\n' > "$restore/STATE"
echo PILOT_RELEASE_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED
echo "PILOT_RELEASE_RESTORE_DIR=$restore"
