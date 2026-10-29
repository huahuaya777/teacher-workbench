#!/usr/bin/env bash
# One-time access check on the already restored, stopped NAS/USB pilot copy.
# The online pilot and staging volumes are never mounted here.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_ACCESS_WRONG_HOST_OR_USER
  exit 1
fi

suffix=08582087b8f1
restore="$HOME/teacher-workbench-pilot-material-nas-restore-$suffix"
escrow="$HOME/teacher-workbench-pilot-offline-escrow-restore-b2f424c27b5a"
backup="$HOME/teacher-workbench-nas-import-pilot-material-data-6A76GMeO-$suffix"
keyring="$HOME/teacher-workbench-pilot-material-nas-keyring-$suffix"
pilot="$HOME/teacher-workbench-pilot"
network="tw-pilot-material-nas-$suffix"
db="tw-pilot-material-nas-db-$suffix"
redis="tw-pilot-material-nas-redis-$suffix"
private="tw-pilot-material-nas-$suffix-private"

[[ ! -L "$restore" && -d "$restore" &&
   "$(cat "$restore/STATE")" == PILOT_MATERIAL_NAS_RESTORE_COMPLETE_CONTAINERS_STOPPED_VOLUMES_PRESERVED ]]
[[ ! -L "$escrow" && -d "$escrow" && ! -L "$backup" && -d "$backup" ]]
[[ ! -L "$keyring" && -d "$keyring" ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ "$(sha256sum "$keyring/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
readarray -t images < "$backup/IMAGE_IDS"
[[ "${#images[@]}" == 4 ]]
for image in "${images[@]}"; do [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]; done

sudo -v
for container in "$db" "$redis"; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$container")" == "$network" ]]
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
done
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$db")" == "${images[1]}" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$redis")" == "${images[2]}" ]]
[[ "$(timeout 10s sudo -n docker network inspect -f '{{.Internal}}' "$network")" == true ]]
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
  https://10.0.30.5:18443/login/)" == 200 ]]
echo PILOT_MATERIAL_ACCESS_ISOLATION_PREFLIGHT_OK

started=0
stop_if_needed() {
  if [[ "$started" == 1 ]]; then
    timeout 60s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo PILOT_MATERIAL_ACCESS_STOP_NEEDS_REVIEW >&2
  fi
}
trap stop_if_needed EXIT
started=1
timeout 30s sudo -n docker start "$db" "$redis" >/dev/null
ready=0
for attempt in $(seq 1 30); do
  if timeout 5s sudo -n docker exec "$db" psql -U teacher_workbench_pilot \
      -d teacher_workbench_pilot -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]]

timeout 90s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$escrow/env.pilot" -e DB_HOST=db -e REDIS_URL=redis://redis:6379/0 \
  -e PRIVATE_FILE_ROOT=/app/data/private -e MODEL_KEYRING_DIR=/run/model-keyring \
  -v "$private:/app/data/private:ro" -v "$keyring:/run/model-keyring:ro" \
  "${images[0]}" python - <<'PY'
import django
django.setup()

from django.contrib.auth import get_user_model
from django.db import transaction
from django.test import Client
from workbench.models import Material

users = get_user_model()
assert users.objects.count() == 1
manager = users.objects.get(username='pilot_manager_20261026')
material = Material.objects.get(owner=manager, original_name='离线排版样例-学生卷.docx')
assert Material.objects.count() == 1

with transaction.atomic():
    outsider = users.objects.create_user('pilot_access_check_20261027')
    outsider.set_unusable_password()
    outsider.save(update_fields=['password'])
    client = Client()
    client.force_login(outsider)
    library = client.get('/materials/', secure=True, HTTP_HOST='10.0.30.5')
    assert library.status_code == 200
    assert material.original_name.encode('utf-8') not in library.content
    download = client.get(f'/materials/{material.pk}/download/',
                          secure=True, HTTP_HOST='10.0.30.5')
    assert download.status_code == 404
    assert client.get('/members/', secure=True, HTTP_HOST='10.0.30.5').status_code == 403
    transaction.set_rollback(True)

assert users.objects.count() == 1 and Material.objects.count() == 1
print('PILOT_MATERIAL_RECOVERED_CROSS_ACCOUNT_DENIAL_OK')
PY

timeout 60s sudo -n docker stop "$redis" "$db" >/dev/null
started=0
[[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
  https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' \
  http://127.0.0.1:18002/login/)" == 200 ]]
echo PILOT_MATERIAL_ACCESS_ONLINE_LOGINS_STILL_HTTP_200
echo PILOT_MATERIAL_RECOVERED_ACCESS_VERIFIED
