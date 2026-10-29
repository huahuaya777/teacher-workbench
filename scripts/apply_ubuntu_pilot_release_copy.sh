#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 && "$#" == 2 ]]
[[ "$1" =~ ^backup-pilot-[A-Za-z0-9]{8}$ && "$2" =~ ^sha256:[a-f0-9]{64}$ ]]
pilot=/home/huahua/teacher-workbench-pilot
root=/var/lib/teacher-workbench-pilot-scheduled
backup="$root/backups/$1"
escrow="$root/escrow/escrow-${1##*-}"
old=sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64
new="$2"

cd "$pilot"
sha256sum -c SHA256SUMS >/dev/null
[[ "$(sed -n 's/^PILOT_APP_IMAGE=//p' .env.pilot)" == "$old" ]]
[[ "$(cat "$backup/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == PILOT_ESCROW_COMPLETE ]]
[[ "$(tail -n 1 "$root/backups/LAST_SUCCESS")" == "$backup" ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(docker image inspect -f '{{.Id}}' teacher-workbench-pilot-web:release-copy-20261029)" == "$new" ]]
for service in web worker; do
  [[ "$(docker inspect -f '{{.Image}}' "teacher-workbench-pilot-$service-1")" == "$old" ]]
done
[[ "$(docker exec teacher-workbench-pilot-redis-1 redis-cli LLEN rq:queue:generation)" == 0 ]]
[[ "$(docker exec teacher-workbench-pilot-redis-1 redis-cli ZCARD rq:wip:generation)" == 0 ]]
[[ "$(curl --noproxy '*' -sS --max-time 8 --cacert pilot-root-ca.crt -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/)" == 200 ]]
exec 9>"$root/backups/.snapshot.lock"
flock -n 9
echo PILOT_RELEASE_COPY_SWITCH_PREFLIGHT_OK

write_image_pin() {
  python3 - "$pilot/.env.pilot" "$1" <<'PY'
from pathlib import Path
import os, stat, sys, tempfile
path = Path(sys.argv[1]); pin = sys.argv[2]
lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
matches = [i for i, line in enumerate(lines) if line.startswith('PILOT_APP_IMAGE=')]
assert len(matches) == 1
lines[matches[0]] = 'PILOT_APP_IMAGE=' + pin + '\n'
info = path.stat()
fd, name = tempfile.mkstemp(prefix='.env.pilot.pin-', dir=path.parent)
try:
    with os.fdopen(fd, 'w', encoding='utf-8') as output:
        output.writelines(lines)
    os.chown(name, info.st_uid, info.st_gid)
    os.chmod(name, stat.S_IMODE(info.st_mode))
    os.replace(name, path)
finally:
    if os.path.exists(name): os.unlink(name)
PY
  sha256sum compose.pilot.yaml Caddyfile.pilot check_pilot_env.py .env.pilot > SHA256SUMS.new
  chown --reference=SHA256SUMS SHA256SUMS.new
  chmod --reference=SHA256SUMS SHA256SUMS.new
  mv -f SHA256SUMS.new SHA256SUMS
  sha256sum -c SHA256SUMS >/dev/null
}

rollback() {
  trap - ERR
  echo PILOT_RELEASE_COPY_ROLLBACK_START >&2
  write_image_pin "$old" || true
  docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml up -d --no-deps web worker >/dev/null 2>&1 || true
  echo PILOT_RELEASE_COPY_ROLLBACK_REQUESTED >&2
}
trap rollback ERR
write_image_pin "$new"
docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml config --quiet
docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml up -d --no-deps web worker
for attempt in $(seq 1 30); do
  status="$(curl --noproxy '*' -s --max-time 8 --cacert pilot-root-ca.crt -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/ || true)"
  [[ "$status" == 200 ]] && break
  sleep 2
done
[[ "$status" == 200 ]]
for service in web worker; do
  [[ "$(docker inspect -f '{{.Image}}' "teacher-workbench-pilot-$service-1")" == "$new" ]]
  [[ "$(docker inspect -f '{{.State.Running}}' "teacher-workbench-pilot-$service-1")" == true ]]
  docker exec "teacher-workbench-pilot-$service-1" python scripts/check_pilot_member_ai_env.py --process-env
done
[[ "$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
page="$(curl --noproxy '*' -fSs --max-time 8 --cacert pilot-root-ca.crt https://10.0.30.5:18443/login/)"
[[ "$page" == *'通过 EasyTier 私网访问。账号由管理员创建。'* ]]
[[ "$page" == *'教师AI工作平台 · EasyTier 私网'* ]]
[[ "$page" != *'功能验证环境'* ]]
trap - ERR
echo PILOT_RELEASE_COPY_DEPLOYED_HTTPS_AND_OLD_STAGING_HTTP_200
