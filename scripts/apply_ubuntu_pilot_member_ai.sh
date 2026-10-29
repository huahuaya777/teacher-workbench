#!/usr/bin/env bash
# Switch only the existing EasyTier pilot to guarded member-owned AI.
set -Eeuo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(hostname)" == teacher-workbench && "$(id -u)" == 0 && "$#" == 0 ]]
pilot=/home/huahua/teacher-workbench-pilot
backup_root=/var/lib/teacher-workbench-pilot-scheduled/backups
old_backup=/usr/local/libexec/teacher-workbench-pilot-backup.pre-member-ai-20261028
new_backup=/usr/local/libexec/teacher-workbench-pilot-backup.member-ai.new
cd "$pilot"
[[ "$(cat STATE)" == PILOT_STARTED_AI_OFF ]]
sha256sum -c SHA256SUMS >/dev/null
echo 'eb155bedddaf0ac793c9bf44400ecdb38d27111f21a74b02f177b730881a6cbc  compose.pilot-member-ai.yaml' | sha256sum -c - >/dev/null
echo '8c5ab852f3545846b44e53750fba3be99c59c87ca942eda494190eae548fe5be  check_pilot_member_ai_env.py' | sha256sum -c - >/dev/null
echo '43103641d10e27d11ce7e975360e29e71c1f7f1c7edd52e64df10b5c8c31acd3  backup_ubuntu_pilot_member_ai.sh' | sha256sum -c - >/dev/null
bash -n backup_ubuntu_pilot_member_ai.sh
docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml config --quiet
[[ ! -e "$old_backup" && ! -e "$new_backup" ]]
[[ "$(docker exec teacher-workbench-pilot-redis-1 redis-cli LLEN rq:queue:generation)" == 0 ]]
[[ "$(cat "$backup_root/backup-pilot-VSvbzq8S/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ -s /var/lib/teacher-workbench-pilot-scheduled/escrow/escrow-VSvbzq8S/v1.key ]]
[[ "$(curl --noproxy '*' -sS --max-time 8 --cacert pilot-root-ca.crt -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
exec 9>"$backup_root/.snapshot.lock"
flock -n 9
install -m 700 /usr/local/libexec/teacher-workbench-pilot-backup "$old_backup"
install -m 700 backup_ubuntu_pilot_member_ai.sh "$new_backup"
echo PILOT_MEMBER_AI_SWITCH_PREFLIGHT_OK

rollback() {
  trap - ERR
  echo PILOT_MEMBER_AI_SWITCH_ROLLBACK_START >&2
  if [[ -f "$old_backup" ]]; then
    install -m 700 "$old_backup" /usr/local/libexec/teacher-workbench-pilot-backup
  fi
  printf 'PILOT_STARTED_AI_OFF\n' > STATE
  docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml stop worker >/dev/null 2>&1 || true
  docker compose --env-file .env.pilot -f compose.pilot.yaml up -d --no-deps web gateway >/dev/null 2>&1 || true
  echo PILOT_MEMBER_AI_SWITCH_ROLLBACK_REQUESTED >&2
}
trap rollback ERR

docker compose --env-file .env.pilot -f compose.pilot.yaml -f compose.pilot-member-ai.yaml \
  up -d --no-deps web worker gateway
for attempt in $(seq 1 30); do
  status="$(curl --noproxy '*' -s --max-time 8 --cacert pilot-root-ca.crt \
    -o /dev/null -w '%{http_code}' https://10.0.30.5:18443/login/ || true)"
  [[ "$status" == 200 ]] && break
  sleep 2
done
[[ "$status" == 200 ]]
[[ "$(docker inspect -f '{{.State.Running}}' teacher-workbench-pilot-worker-1)" == true ]]
docker exec teacher-workbench-pilot-web-1 python scripts/check_pilot_member_ai_env.py --process-env
docker exec teacher-workbench-pilot-worker-1 python scripts/check_pilot_member_ai_env.py --process-env
[[ "$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
install -m 700 "$new_backup" /usr/local/libexec/teacher-workbench-pilot-backup
printf 'PILOT_STARTED_MEMBER_AI\n' > STATE
trap - ERR
echo PILOT_MEMBER_AI_DEPLOYED_NO_REAL_KEY_OR_CALL
