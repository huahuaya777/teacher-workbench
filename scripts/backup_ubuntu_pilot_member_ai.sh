#!/usr/bin/env bash
# Root-run paired snapshot of the member AI HTTPS pilot.
# Private escrow stays local and separate from the data package.
# Check the pilot's own HTTPS endpoint even when the old staging stack is offline.
set -euo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [[ "$(hostname)" != teacher-workbench || "$(id -u)" != 0 ||
      ( "$#" != 0 && ( "$#" != 1 || "$1" != --force ) ) ]]; then
  echo PILOT_BACKUP_WRONG_HOST_OR_USER
  exit 1
fi

pilot=/home/huahua/teacher-workbench-pilot
root=/var/lib/teacher-workbench-pilot-scheduled/backups
escrow_root=/var/lib/teacher-workbench-pilot-scheduled/escrow
[[ ! -L /var/lib/teacher-workbench-pilot-scheduled ]]
[[ ! -L "$pilot" && -d "$pilot" && "$(stat -c %a "$pilot")" == 700 ]]
[[ "$(cat "$pilot/STATE")" == PILOT_STARTED_MEMBER_AI ]]
(cd "$pilot" && sha256sum -c SHA256SUMS >/dev/null)
echo 'eb155bedddaf0ac793c9bf44400ecdb38d27111f21a74b02f177b730881a6cbc  compose.pilot-member-ai.yaml' |
  (cd "$pilot" && sha256sum -c - >/dev/null)
echo '8c5ab852f3545846b44e53750fba3be99c59c87ca942eda494190eae548fe5be  check_pilot_member_ai_env.py' |
  (cd "$pilot" && sha256sum -c - >/dev/null)
python3 "$pilot/check_pilot_env.py" --env-file "$pilot/.env.pilot"
(cd "$pilot" && docker compose --env-file .env.pilot -f compose.pilot.yaml \
  -f compose.pilot-member-ai.yaml config --quiet)
readarray -t values < <(python3 - "$pilot/.env.pilot" <<'PY'
from pathlib import Path
import sys
values = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines() if '=' in line)
for key in ('PILOT_KEYRING_DIR', 'PILOT_APP_IMAGE', 'PILOT_DB_IMAGE',
            'PILOT_REDIS_IMAGE', 'PILOT_CADDY_IMAGE'):
    print(values[key])
PY
)
keyring="${values[0]}"
images=("${values[1]}" "${values[2]}" "${values[3]}" "${values[4]}")
[[ ! -L "$keyring" && -d "$keyring" && "$(stat -c %a "$keyring")" == 700 ]]
[[ ! -L "$keyring/v1.key" && -s "$keyring/v1.key" &&
   "$(stat -c %a "$keyring/v1.key")" == 600 ]]
[[ -s "$pilot/pilot-root-ca.crt" ]]

command -v docker >/dev/null
for service in db redis web gateway worker; do
  [[ "$(timeout 10s docker inspect -f '{{.State.Running}}' "teacher-workbench-pilot-$service-1")" == true ]]
done
for image in "${images[@]}"; do
  [[ "$(timeout 10s docker image inspect -f '{{.Id}}' "$image")" == "$image" ]]
done
for volume in db redis private caddy_data caddy_config; do
  timeout 10s docker volume inspect "teacher-workbench-pilot_pilot_$volume" >/dev/null
done
[[ "$(timeout 10s docker inspect -f '{{.Image}}' teacher-workbench-pilot-web-1)" == "${images[0]}" ]]
[[ "$(timeout 10s docker inspect -f '{{.Image}}' teacher-workbench-pilot-worker-1)" == "${images[0]}" ]]
docker exec teacher-workbench-pilot-web-1 python scripts/check_pilot_member_ai_env.py --process-env
docker exec teacher-workbench-pilot-worker-1 python scripts/check_pilot_member_ai_env.py --process-env
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
  https://10.0.30.5:18443/login/)" == 200 ]]
echo PILOT_BACKUP_PREFLIGHT_OK

for directory in "$root" "$escrow_root"; do
  [[ ! -L "$directory" ]]
  mkdir -m 700 -p "$directory"
  [[ "$(stat -c '%a:%u' "$directory")" == 700:0 ]]
done
available_kib="$(df -Pk "$root" | awk 'END {print $4}')"
[[ "$available_kib" =~ ^[0-9]+$ && "$available_kib" -ge 12582912 ]] || {
  echo PILOT_SCHEDULED_BACKUP_LOW_DISK_SPACE >&2
  exit 1
}
exec 9>"$root/.snapshot.lock"
flock -n 9
if [[ -f "$root/LAST_SUCCESS" && ! -L "$root/LAST_SUCCESS" ]]; then
  read -r last_success < "$root/LAST_SUCCESS"
  last_epoch="$(date -u -d "$last_success" +%s 2>/dev/null || true)"
  now_epoch="$(date -u +%s)"
  if [[ "$#" == 0 && "$last_epoch" =~ ^[0-9]+$ && "$now_epoch" -ge "$last_epoch" &&
        "$((now_epoch - last_epoch))" -lt 64800 ]]; then
    echo PILOT_SCHEDULED_BACKUP_RECENT_SUCCESS_SKIP
    exit 0
  fi
fi
backup="$(mktemp -d "$root/backup-pilot-XXXXXXXX")"
suffix="${backup##*-}"
escrow="$escrow_root/escrow-$suffix"
mkdir -m 700 "$escrow"
printf 'INCOMPLETE\n' > "$backup/STATE"
printf 'INCOMPLETE\n' > "$escrow/STATE"

stopped=0
restart_if_needed() {
  if [[ "$stopped" == 1 ]]; then
    if (cd "$pilot" && timeout 90s docker compose --env-file .env.pilot \
        -f compose.pilot.yaml -f compose.pilot-member-ai.yaml start web gateway worker >/dev/null); then
      echo PILOT_BACKUP_SERVICES_RESTARTED_AFTER_ERROR >&2
    else
      echo PILOT_BACKUP_RESTART_NEEDS_REVIEW >&2
    fi
  fi
}
trap restart_if_needed EXIT

tar -czf "$backup/source.tar.gz" -C "$pilot" \
  compose.pilot.yaml compose.pilot-member-ai.yaml Caddyfile.pilot \
  check_pilot_env.py check_pilot_member_ai_env.py pilot-root-ca.crt
printf '%s\n' "${images[@]}" > "$backup/IMAGE_IDS"
sha256sum "$keyring/v1.key" | cut -d ' ' -f 1 > "$backup/KEY_SHA256"
sha256sum "$pilot/pilot-root-ca.crt" | cut -d ' ' -f 1 > "$backup/CA_SHA256"

echo PILOT_BACKUP_APPLICATION_STOP_START
stopped=1
(cd "$pilot" && timeout 90s docker compose --env-file .env.pilot \
  -f compose.pilot.yaml -f compose.pilot-member-ai.yaml stop worker gateway web >/dev/null)
echo PILOT_BACKUP_APPLICATION_WRITES_STOPPED

timeout 180s docker exec teacher-workbench-pilot-db-1 sh -c \
  'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$backup/db.dump"
timeout 30s docker exec -i teacher-workbench-pilot-db-1 \
  pg_restore --list < "$backup/db.dump" >/dev/null
echo PILOT_BACKUP_POSTGRES_READY

# With Web stopped, Redis has no application writers. Save its AOF/RDB files.
timeout 30s docker exec teacher-workbench-pilot-redis-1 redis-cli SAVE >/dev/null
for volume in private redis; do
  timeout 180s docker run --pull never --rm --network none --user 0:0 \
    -v "teacher-workbench-pilot_pilot_$volume:/data:ro" --entrypoint sh \
    "${images[2]}" -c 'cd /data && tar -czf - .' > "$backup/$volume.tar.gz"
done
echo PILOT_BACKUP_PRIVATE_AND_REDIS_READY

install -m 600 "$pilot/.env.pilot" "$escrow/env.pilot"
install -m 600 "$keyring/v1.key" "$escrow/v1.key"
for volume in caddy_data caddy_config; do
  timeout 180s docker run --pull never --rm --network none --user 0:0 \
    -v "teacher-workbench-pilot_pilot_$volume:/data:ro" --entrypoint sh \
    "${images[2]}" -c 'cd /data && tar -czf - .' > "$escrow/$volume.tar.gz"
done
echo PILOT_BACKUP_SECRET_ESCROW_READY

timeout 900s docker image save "${images[@]}" | gzip -1 > "$backup/images.tar.gz"
echo PILOT_BACKUP_IMAGES_READY

for file in source.tar.gz IMAGE_IDS KEY_SHA256 CA_SHA256 db.dump private.tar.gz redis.tar.gz images.tar.gz; do
  [[ -s "$backup/$file" && "$(stat -c %a "$backup/$file")" == 600 ]]
done
for file in env.pilot v1.key caddy_data.tar.gz caddy_config.tar.gz; do
  [[ -s "$escrow/$file" && "$(stat -c %a "$escrow/$file")" == 600 ]]
done
(cd "$backup" && sha256sum source.tar.gz IMAGE_IDS KEY_SHA256 CA_SHA256 db.dump \
  private.tar.gz redis.tar.gz images.tar.gz > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum env.pilot v1.key caddy_data.tar.gz caddy_config.tar.gz \
  > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(sha256sum "$pilot/pilot-root-ca.crt" | cut -d ' ' -f 1)" == "$(cat "$backup/CA_SHA256")" ]]

(cd "$pilot" && timeout 90s docker compose --env-file .env.pilot \
  -f compose.pilot.yaml -f compose.pilot-member-ai.yaml start web gateway worker >/dev/null)
stopped=0
[[ "$(timeout 10s docker inspect -f '{{.State.Running}}' teacher-workbench-pilot-worker-1)" == true ]]
for attempt in $(seq 1 30); do
  status="$(curl --noproxy '*' --silent --max-time 8 \
    --cacert "$pilot/pilot-root-ca.crt" --output /dev/null --write-out '%{http_code}' \
    https://10.0.30.5:18443/login/ 2>/dev/null || true)"
  [[ "$status" == 200 ]] && break
  sleep 2
done
[[ "$status" == 200 ]]
printf 'PILOT_ESCROW_COMPLETE\n' > "$escrow/STATE"
printf 'PILOT_BACKUP_COMPLETE\n' > "$backup/STATE"
printf '%s\n%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$backup" > "$root/.LAST_SUCCESS.new"
chmod 600 "$root/.LAST_SUCCESS.new"
mv -f "$root/.LAST_SUCCESS.new" "$root/LAST_SUCCESS"
echo PILOT_BACKUP_AND_PAIRED_ESCROW_VERIFIED
echo "PILOT_BACKUP_DIR=$backup"
echo "PILOT_ESCROW_DIR=$escrow"
echo PILOT_SCHEDULED_LOCAL_BACKUP_VERIFIED
