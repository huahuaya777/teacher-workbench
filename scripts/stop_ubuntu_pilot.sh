#!/usr/bin/env bash
# Stop only the separate pilot; retain its volumes, keyring, and CA.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_STOP_WRONG_HOST_OR_USER
  exit 1
fi

target="$HOME/teacher-workbench-pilot"
[[ ! -L "$target" && -d "$target" && "$(stat -c %a "$target")" == 700 ]]
[[ -f "$target/.env.pilot" && -f "$target/compose.pilot.yaml" ]]
[[ "$(cat "$target/STATE")" == PILOT_STARTED_AI_OFF ||
   "$(cat "$target/STATE")" == PILOT_STARTING ]]

sudo -v
cd "$target"
timeout 20s sudo -n docker compose --env-file .env.pilot -f compose.pilot.yaml config --quiet
sudo -n docker compose --env-file .env.pilot -f compose.pilot.yaml stop gateway web db redis
[[ "$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
printf 'PILOT_STOPPED_VOLUMES_PRESERVED\n' > STATE
echo PILOT_STOPPED_ONLY_PILOT_VOLUMES_PRESERVED
echo PILOT_STAGING_LOGIN_STILL_HTTP_200
