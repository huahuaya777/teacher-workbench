#!/usr/bin/env bash
# Read-only Ubuntu 257 preflight for a separate EasyTier HTTPS pilot.
set -euo pipefail

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_PREFLIGHT_WRONG_HOST_OR_USER
  exit 1
fi

backup="$HOME/teacher-workbench-staging-backups/backup-staging-errors-CLQ37z6Q"
[[ ! -L "$backup" && -d "$backup" && "$(stat -c %a "$backup")" == 700 ]]
[[ "$(cat "$backup/STATE")" == STAGING_ERRORS_BACKUP_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
echo PILOT_PREFLIGHT_SOURCE_BACKUP_OK

sudo -v
timeout 15s sudo -n docker image inspect "$image" postgres:17 redis:7-alpine >/dev/null
online_image="$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)"
[[ "$online_image" == "$image" ]] || {
  echo PILOT_PREFLIGHT_ONLINE_IMAGE_CHANGED
  exit 1
}
echo PILOT_PREFLIGHT_APP_IMAGE_PINNED

if timeout 10s sudo -n docker image inspect caddy:2-alpine >/dev/null 2>&1; then
  echo PILOT_PREFLIGHT_CADDY_IMAGE_PRESENT
else
  echo PILOT_PREFLIGHT_CADDY_IMAGE_MISSING
fi

ip -4 -o addr show | awk '{print $4}' | grep -Fxq '10.0.30.5/24' || {
  echo PILOT_PREFLIGHT_EXPECTED_IP_MISSING
  exit 1
}
if ss -H -ltn | awk '{print $4}' | grep -Eq '(^|:)18443$'; then
  echo PILOT_PREFLIGHT_PORT_IN_USE
  exit 1
fi
echo PILOT_PREFLIGHT_PRIVATE_PORT_AVAILABLE

if timeout 10s sudo -n docker container ls -a --format '{{.Names}}' |
    grep -Eq '^teacher-workbench-pilot-'; then
  echo PILOT_PREFLIGHT_PILOT_CONTAINER_EXISTS
  exit 1
fi
if timeout 10s sudo -n docker volume ls --format '{{.Name}}' |
    grep -Eq '^teacher-workbench-pilot_'; then
  echo PILOT_PREFLIGHT_PILOT_VOLUME_EXISTS
  exit 1
fi
[[ ! -e "$HOME/teacher-workbench-pilot" && ! -L "$HOME/teacher-workbench-pilot" ]] || {
  echo PILOT_PREFLIGHT_PILOT_DIRECTORY_EXISTS
  exit 1
}
echo PILOT_PREFLIGHT_SEPARATE_TARGET_CLEAR

status="$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18002/login/)"
[[ "$status" == 200 ]] || {
  echo PILOT_PREFLIGHT_STAGING_LOGIN_NOT_READY
  exit 1
}
echo PILOT_PREFLIGHT_STAGING_LOGIN_HTTP_200
echo PILOT_READONLY_PREFLIGHT_OK
