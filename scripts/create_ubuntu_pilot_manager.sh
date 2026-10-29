#!/usr/bin/env bash
# One-time account bootstrap for the independent HTTPS pilot.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 || ! -t 0 ]]; then
  echo PILOT_MANAGER_WRONG_HOST_USER_OR_TERMINAL
  exit 1
fi

pilot="$HOME/teacher-workbench-pilot"
python_script="$HOME/prepare_ubuntu_pilot_manager.py"
if [[ -L "$pilot" || ! -d "$pilot" || "$(stat -c %a "$pilot")" != 700 ||
      -L "$python_script" || ! -f "$python_script" ]]; then
  echo PILOT_MANAGER_FILES_UNSAFE
  exit 1
fi
[[ "$(cat "$pilot/STATE")" == PILOT_STARTED_AI_OFF ]]
cd "$pilot"
python3 check_pilot_env.py --env-file .env.pilot >/dev/null
echo PILOT_MANAGER_ENV_GUARD_OK

sudo -v
for container in teacher-workbench-pilot-db-1 teacher-workbench-pilot-redis-1 \
                 teacher-workbench-pilot-web-1 teacher-workbench-pilot-gateway-1; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == running ]]
done
image="$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-pilot-web-1)"
expected_image="$(python3 - <<'PY'
from pathlib import Path
values = dict(line.split('=', 1) for line in Path('.env.pilot').read_text().splitlines() if '=' in line)
print(values['PILOT_APP_IMAGE'])
PY
)"
[[ "$image" == "$expected_image" ]]
[[ "$(curl --noproxy '*' --silent --show-error --max-time 10 \
    --cacert pilot-root-ca.crt --output /dev/null --write-out '%{http_code}' \
    https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl --silent --show-error --max-time 10 --output /dev/null \
    --write-out '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
echo PILOT_MANAGER_ONLINE_PREFLIGHT_OK

sudo -n docker cp "$python_script" teacher-workbench-pilot-web-1:/tmp/prepare_ubuntu_pilot_manager.py
sudo -n docker exec -it teacher-workbench-pilot-web-1 \
  python /tmp/prepare_ubuntu_pilot_manager.py --create-fictional-pilot-manager

[[ "$(curl --noproxy '*' --silent --show-error --max-time 10 \
    --cacert pilot-root-ca.crt --output /dev/null --write-out '%{http_code}' \
    https://10.0.30.5:18443/login/)" == 200 ]]
echo PILOT_MANAGER_HTTPS_LOGIN_STILL_200
