#!/usr/bin/env bash
# Resume the first Ubuntu 257 test start after the PyPI read timeout.
# The bundle is verified before extraction by the Windows-side SSH command.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

test_dir="$HOME/teacher-workbench-test-9e29fddf"
retry_dir="$HOME/teacher-workbench-test-offline-retry"
if [[ -L "$test_dir" || ! -d "$test_dir" || -L "$retry_dir" || ! -d "$retry_dir" ]]; then
  echo "TEST_OR_RETRY_DIRECTORY_MISSING_OR_UNSAFE"
  exit 1
fi
if [[ "$(stat -c %a "$test_dir")" != "700" || "$(stat -c %a "$test_dir/.env")" != "600" ]]; then
  echo "TEST_DIRECTORY_OR_ENV_PERMISSIONS_WRONG"
  exit 1
fi
if [[ -e "$test_dir/wheelhouse" ]]; then
  echo "TEST_WHEELHOUSE_ALREADY_EXISTS"
  exit 1
fi
if [[ "$(sha256sum "$test_dir/Dockerfile" | cut -d ' ' -f 1)" != "bdce7c94f6d1c995cacf51c5c3ad904826ef8d127b7b223212f463e9ffee8d37" ]]; then
  echo "TEST_DOCKERFILE_CHANGED"
  exit 1
fi
if [[ "$(find "$retry_dir/wheelhouse" -maxdepth 1 -type f -name '*.whl' | wc -l)" -ne 18 ]]; then
  echo "OFFLINE_WHEEL_COUNT_WRONG"
  exit 1
fi

cd "$test_dir"
python3 scripts/check_test_env.py --env-file .env
docker compose config --quiet
if ss -H -ltn | grep -q ':18000'; then
  echo "PORT_18000_BUSY"
  exit 1
fi
if [[ -n "$(sudo docker ps -aq --filter label=com.docker.compose.project=teacher-workbench-test)" ]]; then
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

cp -r "$retry_dir/wheelhouse" ./wheelhouse
cp "$retry_dir/Dockerfile.test-offline" ./Dockerfile
echo "TEST_OFFLINE_DEPENDENCIES_READY"
bash "$HOME/start_ubuntu_test_stack_9e29fddf.sh"
