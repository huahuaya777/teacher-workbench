#!/usr/bin/env bash
# Snapshot only Ubuntu VM 257's isolated test stack to a private home folder.
# No NAS writes, no production data, no deletion of Docker volumes.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

# The first attempt used this exact process name. Do not race an older run.
if ps -eo args= | grep -E '^bash (\./)?backup_ubuntu_test_stack\.sh$' >/dev/null; then
  echo "OLDER_BACKUP_ATTEMPT_STILL_RUNNING"
  exit 1
fi
echo "OLD_BACKUP_NOT_RUNNING"
test_dir="$HOME/teacher-workbench-test-9e29fddf"
if [[ -L "$test_dir" || ! -d "$test_dir" || "$(stat -c %a "$test_dir")" != "700" ]]; then
  echo "TEST_DIRECTORY_MISSING_OR_UNSAFE"
  exit 1
fi
cd "$test_dir"
grep -Fxq 'name: teacher-workbench-test' compose.yaml
grep -Fxq '      - "127.0.0.1:18000:8000"' compose.yaml
if [[ "$(stat -c %a .env)" != "600" ]]; then
  echo "TEST_ENV_PERMISSIONS_WRONG"
  exit 1
fi
if [[ ! -f "$HOME/teacher-workbench-test-9e29fddf.tar.gz" ]]; then
  echo "TEST_SOURCE_ARCHIVE_MISSING"
  exit 1
fi
python3 scripts/check_test_env.py --env-file .env >/dev/null
running_services="$(sudo docker compose ps --status running --services)"
for service in db redis web worker; do
  if ! grep -Fxq "$service" <<< "$running_services"; then
    echo "TEST_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
if [[ "$(sudo docker compose port web 8000)" != "127.0.0.1:18000" ]]; then
  echo "TEST_WEB_PORT_NOT_LOOPBACK"
  exit 1
fi
sudo docker volume inspect teacher-workbench-test_test_private >/dev/null

# Obtain sudo authorization while the application is still running. Later
# Docker commands must fail promptly if this authorization is lost.
sudo -v

# The probe creates only synthetic data in this isolated test environment.
timeout 60s sudo -n docker compose exec -T web python - < "$HOME/seed_test_backup_probe.py"

# Prove the database export command can finish before pausing the application.
# This reads only schema metadata and discards its output.
echo "TEST_POSTGRES_PREFLIGHT_START"
timeout 30s sudo -n docker compose exec -T db sh -c 'pg_dump -Fc --schema-only -U "$POSTGRES_USER" "$POSTGRES_DB"' >/dev/null
echo "TEST_POSTGRES_PREFLIGHT_OK"
echo "TEST_PRIVATE_PREFLIGHT_START"
timeout 30s sudo -n docker run --rm --network none --user 0:0 \
  -v teacher-workbench-test_test_private:/data:ro \
  --entrypoint sh redis:7-alpine -c 'test -d /data/materials && tar -cf /dev/null -C /data materials'
echo "TEST_PRIVATE_PREFLIGHT_OK"

backup_root="$HOME/teacher-workbench-test-backups"
if [[ -L "$backup_root" ]]; then
  echo "BACKUP_ROOT_IS_SYMLINK"
  exit 1
fi
mkdir -m 700 -p "$backup_root"
if [[ "$(stat -c %a "$backup_root")" != "700" ]]; then
  echo "BACKUP_ROOT_PERMISSIONS_WRONG"
  exit 1
fi
exec 9>"$backup_root/.snapshot.lock"
if ! flock -n 9; then
  echo "BACKUP_ALREADY_RUNNING"
  exit 1
fi
backup_dir="$(mktemp -d "$backup_root/backup-XXXXXXXX")"
printf 'INCOMPLETE\n' > "$backup_dir/STATE"

stopped=0
restart_if_needed() {
  if [[ "$stopped" == 1 ]]; then
    if timeout 60s sudo -n docker compose start web worker >/dev/null; then
      echo "TEST_APPLICATION_RESTARTED_AFTER_ERROR"
    else
      echo "TEST_RESTART_NEEDS_MANUAL_ACTION" >&2
    fi
  fi
}
trap restart_if_needed EXIT

# Freeze application writes before taking both parts of the snapshot.
stopped=1
echo "TEST_APPLICATION_STOP_START"
timeout 60s sudo -n docker compose stop web worker >/dev/null
echo "TEST_APPLICATION_WRITES_STOPPED"
echo "TEST_POSTGRES_DUMP_START"
timeout 120s sudo -n docker compose exec -T db sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$backup_dir/db.dump"
echo "TEST_POSTGRES_DUMP_READY"
echo "TEST_PRIVATE_ARCHIVE_START"
timeout 120s sudo -n docker run --rm --network none \
  --user 0:0 \
  -v teacher-workbench-test_test_private:/data:ro \
  --entrypoint sh redis:7-alpine -c 'cd /data && tar -czf - .' > "$backup_dir/private.tar.gz"
echo "TEST_PRIVATE_ARCHIVE_READY"
test -s "$backup_dir/db.dump"
test -s "$backup_dir/private.tar.gz"
timeout 30s sudo -n docker compose exec -T db pg_restore --list < "$backup_dir/db.dump" >/dev/null
tar -tzf "$backup_dir/private.tar.gz" | grep 'materials/' >/dev/null
(cd "$backup_dir" && sha256sum db.dump private.tar.gz > SHA256SUMS)
(cd "$backup_dir" && sha256sum -c SHA256SUMS >/dev/null)
sha256sum "$HOME/teacher-workbench-test-9e29fddf.tar.gz" Dockerfile compose.yaml > "$backup_dir/SOURCE_SHA256SUMS"

echo "TEST_APPLICATION_RESTART_START"
timeout 60s sudo -n docker compose start web worker >/dev/null
stopped=0
python3 - <<'PY'
import time
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for _ in range(20):
    try:
        with opener.open("http://127.0.0.1:18000/login/", timeout=2) as response:
            if response.status == 200:
                print("TEST_WEB_RESTARTED_HTTP_200")
                break
    except Exception:
        time.sleep(3)
else:
    raise SystemExit("TEST_WEB_NOT_READY_AFTER_BACKUP")
PY

printf 'TEST_BACKUP_COMPLETE\n' > "$backup_dir/STATE"
echo "TEST_BACKUP_FILES_VERIFIED"
echo "TEST_BACKUP_DIR=$backup_dir"
