#!/usr/bin/env bash
# Start only the new staging Compose project; preserve volumes on failure.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$(basename "$PWD")" != teacher-workbench-staging-* || -L "$PWD" ]]; then
  echo "WRONG_STAGING_DIRECTORY"
  exit 1
fi
if [[ ! -f .env.staging || "$(stat -c %a .env.staging)" != "600" ]]; then
  echo "STAGING_ENV_MISSING_OR_UNSAFE"
  exit 1
fi
python3 scripts/check_staging_env.py --env-file .env.staging
sudo docker compose --env-file .env.staging -f compose.staging.yaml config --quiet
if ! python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
with build_opener(ProxyHandler({})).open("http://127.0.0.1:18000/login/", timeout=5) as response:
    assert response.status == 200
PY
then
  echo "SOURCE_TEST_LOGIN_NOT_READY"
  exit 1
fi
echo "STAGING_START_BEGIN"
if ! sudo docker compose --env-file .env.staging -f compose.staging.yaml up -d --build; then
  sudo docker compose --env-file .env.staging -f compose.staging.yaml stop || true
  echo "STAGING_START_FAILED_STOPPED_VOLUMES_PRESERVED"
  exit 1
fi
ready=0
for _ in $(seq 1 30); do
  if python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
try:
    with build_opener(ProxyHandler({})).open("http://127.0.0.1:18002/login/", timeout=3) as response:
        assert response.status == 200
except Exception:
    raise SystemExit(1)
PY
  then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != "1" ]] || ! python3 scripts/verify_staging_http.py; then
  sudo docker compose --env-file .env.staging -f compose.staging.yaml stop || true
  echo "STAGING_HTTP_FAILED_STOPPED_VOLUMES_PRESERVED"
  exit 1
fi
sudo docker compose --env-file .env.staging -f compose.staging.yaml ps --format table
echo "STAGING_HTTP_TECHNICAL_VERIFICATION_OK"
echo "SOURCE_TEST_LOGIN_STILL_HTTP_200"
