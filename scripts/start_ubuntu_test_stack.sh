#!/usr/bin/env bash
# First start of the isolated test stack on Ubuntu VM 257 only.
# No production publish, no AI call, no removal of existing Docker data.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

test_dir="$HOME/teacher-workbench-test-9e29fddf"
if [[ -L "$test_dir" || ! -d "$test_dir" ]]; then
  echo "TEST_DIRECTORY_MISSING_OR_UNSAFE"
  exit 1
fi
cd "$test_dir"

if [[ "$(stat -c %a .)" != "700" || "$(stat -c %a .env)" != "600" ]]; then
  echo "TEST_DIRECTORY_OR_ENV_PERMISSIONS_WRONG"
  exit 1
fi
grep -Fxq 'name: teacher-workbench-test' compose.yaml
grep -Fxq '      - "127.0.0.1:18000:8000"' compose.yaml
python3 scripts/check_test_env.py --env-file .env
docker compose config --quiet

listeners="$(ss -H -ltn)"
if grep -q ':18000' <<< "$listeners"; then
  echo "PORT_18000_BUSY"
  exit 1
fi

existing_containers="$(sudo docker ps -aq --filter label=com.docker.compose.project=teacher-workbench-test)"
if [[ -n "$existing_containers" ]]; then
  echo "TEST_CONTAINERS_ALREADY_EXIST"
  exit 1
fi
existing_volumes="$(sudo docker volume ls --format '{{.Name}}')"
for volume in teacher-workbench-test_test_db teacher-workbench-test_test_redis teacher-workbench-test_test_private; do
  if grep -Fxq "$volume" <<< "$existing_volumes"; then
    echo "TEST_VOLUME_ALREADY_EXISTS: $volume"
    exit 1
  fi
done

echo "TEST_FIRST_START_PREFLIGHT_OK"
sudo docker compose up -d --build
sudo docker compose ps

ready=0
for _ in {1..20}; do
  if python3 -c 'from urllib.request import build_opener, ProxyHandler; response = build_opener(ProxyHandler({})).open("http://127.0.0.1:18000/login/", timeout=2); assert response.status == 200' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 3
done
if [[ "$ready" != 1 ]]; then
  echo "TEST_LOGIN_NOT_READY"
  exit 1
fi
echo "TEST_LOGIN_HTTP_200"
