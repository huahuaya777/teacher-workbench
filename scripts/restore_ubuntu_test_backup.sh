#!/usr/bin/env bash
# Restore one fictional test snapshot into new Docker volumes on Ubuntu VM 257.
# The source test stack and source backup are read only; no NAS or production use.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi

backup_dir="$HOME/teacher-workbench-test-backups/backup-NX5wqA1m"
test_dir="$HOME/teacher-workbench-test-9e29fddf"
restore_dir="$HOME/teacher-workbench-restore-nx5wqa1m"
prefix="teacher-workbench-restore-nx5wqa1m"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db_container="$prefix-db"
web_container="$prefix-web"
image="teacher-workbench-test-web"

if [[ -L "$backup_dir" || ! -d "$backup_dir" || "$(stat -c %a "$backup_dir")" != "700" ]]; then
  echo "BACKUP_DIRECTORY_MISSING_OR_UNSAFE"
  exit 1
fi
if [[ "$(cat "$backup_dir/STATE")" != "TEST_BACKUP_COMPLETE" ]]; then
  echo "BACKUP_NOT_COMPLETE"
  exit 1
fi
if [[ -e "$restore_dir" || -L "$restore_dir" ]]; then
  echo "RESTORE_DIRECTORY_ALREADY_EXISTS"
  exit 1
fi
if [[ -L "$test_dir" || ! -d "$test_dir" || "$(stat -c %a "$test_dir")" != "700" ]]; then
  echo "SOURCE_TEST_DIRECTORY_UNSAFE"
  exit 1
fi

(cd "$backup_dir" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$test_dir" && sha256sum -c "$backup_dir/SOURCE_SHA256SUMS" >/dev/null)
python3 - "$backup_dir/private.tar.gz" <<'PY'
import sys
import tarfile
from pathlib import PurePosixPath

with tarfile.open(sys.argv[1], "r:gz") as archive:
    names = []
    for member in archive:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not (member.isfile() or member.isdir()):
            raise SystemExit("RESTORE_ARCHIVE_UNSAFE_MEMBER")
        names.append(str(path))
if not any(name.startswith("materials/") for name in names):
    raise SystemExit("RESTORE_ARCHIVE_MATERIAL_MISSING")
PY
echo "RESTORE_BACKUP_VERIFIED"

cd "$test_dir"
sudo docker compose exec -T db pg_restore --list < "$backup_dir/db.dump" >/dev/null
for service in db redis web worker; do
  if ! sudo docker compose ps --status running --services | grep -Fx "$service" >/dev/null; then
    echo "SOURCE_TEST_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
if [[ "$(sudo docker compose port web 8000)" != "127.0.0.1:18000" ]]; then
  echo "SOURCE_WEB_PORT_CHANGED"
  exit 1
fi
for item in "$db_volume" "$private_volume"; do
  if sudo docker volume inspect "$item" >/dev/null 2>&1; then
    echo "RESTORE_VOLUME_ALREADY_EXISTS"
    exit 1
  fi
done
if sudo docker network inspect "$network" >/dev/null 2>&1; then
  echo "RESTORE_NETWORK_ALREADY_EXISTS"
  exit 1
fi
for item in "$db_container" "$web_container"; do
  if sudo docker container inspect "$item" >/dev/null 2>&1; then
    echo "RESTORE_CONTAINER_ALREADY_EXISTS"
    exit 1
  fi
done
if ss -H -ltn | grep -E ':18001[[:space:]]' >/dev/null; then
  echo "RESTORE_PORT_18001_IN_USE"
  exit 1
fi
sudo docker image inspect postgres:17 redis:7-alpine "$image" >/dev/null
source_image="$(sudo docker inspect -f '{{.Image}}' teacher-workbench-test-web-1)"
available_image="$(sudo docker image inspect -f '{{.Id}}' "$image")"
if [[ "$source_image" != "$available_image" ]]; then
  echo "RESTORE_APP_IMAGE_DIFFERS_FROM_SOURCE"
  exit 1
fi
if [[ ! -f "$HOME/verify_restored_test_probe.py" ]]; then
  echo "RESTORE_VERIFIER_MISSING"
  exit 1
fi
echo "RESTORE_ISOLATION_PREFLIGHT_OK"

sudo -v
mkdir -m 700 "$restore_dir"
env_file="$restore_dir/.env"
python3 - "$env_file" <<'PY'
import os
import secrets
import sys

password = secrets.token_hex(24)
content = "\n".join([
    "DJANGO_DEBUG=1",
    f"DJANGO_SECRET_KEY={secrets.token_hex(32)}",
    "DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1",
    "DB_NAME=teacher_workbench",
    "DB_USER=teacher_workbench",
    f"DB_PASSWORD={password}",
    "POSTGRES_DB=teacher_workbench",
    "POSTGRES_USER=teacher_workbench",
    f"POSTGRES_PASSWORD={password}",
    "AI_ENABLED=0",
    "AI_API_KEY=",
    "AI_LOCAL_QUEUE=0",
    "AI_MODEL=qwen-flash",
    "AI_MAX_OUTPUT_TOKENS=1500",
    "",
])
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as output:
    output.write(content)
PY
python3 scripts/check_test_env.py --env-file "$env_file" >/dev/null
echo "RESTORE_TEST_ENV_READY (random secrets hidden)"

created=1
stop_restore_if_needed() {
  if [[ "$created" == 1 ]]; then
    timeout 30s sudo -n docker stop "$web_container" >/dev/null 2>&1 || true
    timeout 30s sudo -n docker stop "$db_container" >/dev/null 2>&1 || true
  fi
}
trap stop_restore_if_needed EXIT

timeout 30s sudo -n docker network create "$network" >/dev/null
timeout 30s sudo -n docker volume create "$db_volume" >/dev/null
timeout 30s sudo -n docker volume create "$private_volume" >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$db_container" --network "$network" \
  --env-file "$env_file" -v "$db_volume:/var/lib/postgresql/data" postgres:17 >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$db_container" psql -U teacher_workbench -d teacher_workbench -Atqc 'SELECT 1' 2>/dev/null | grep -Fx '1' >/dev/null; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != 1 ]]; then
  echo "RESTORE_DATABASE_NOT_READY"
  exit 1
fi
echo "RESTORE_EMPTY_DATABASE_READY"

echo "RESTORE_POSTGRES_START"
timeout 120s sudo -n docker exec -i "$db_container" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench -d teacher_workbench < "$backup_dir/db.dump"
echo "RESTORE_POSTGRES_READY"
echo "RESTORE_PRIVATE_START"
timeout 120s sudo -n docker run --pull never --rm -i --network none --user 0:0 \
  -v "$private_volume:/data" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -xzf -' < "$backup_dir/private.tar.gz"
echo "RESTORE_PRIVATE_READY"

timeout 60s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$env_file" -e DB_HOST="$db_container" -e PRIVATE_FILE_ROOT=/app/data/private \
  -v "$private_volume:/app/data/private:ro" "$image" python - < "$HOME/verify_restored_test_probe.py"

timeout 60s sudo -n docker run --pull never -d --name "$web_container" --network "$network" \
  --env-file "$env_file" -e DB_HOST="$db_container" -e PRIVATE_FILE_ROOT=/app/data/private \
  -v "$private_volume:/app/data/private:ro" -p 127.0.0.1:18001:8000 "$image" \
  sh -c 'python scripts/check_test_env.py --process-env && python manage.py migrate --check && python manage.py runserver 0.0.0.0:8000' >/dev/null
python3 - <<'PY'
import time
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for _ in range(20):
    try:
        with opener.open("http://127.0.0.1:18001/login/", timeout=2) as response:
            if response.status == 200:
                print("RESTORE_LOGIN_HTTP_200")
                break
    except Exception:
        time.sleep(2)
else:
    raise SystemExit("RESTORE_WEB_NOT_READY")
PY

timeout 60s sudo -n docker stop "$web_container" >/dev/null
timeout 60s sudo -n docker stop "$db_container" >/dev/null
created=0
if ! curl --noproxy '*' --fail --silent -o /dev/null http://127.0.0.1:18000/login/; then
  echo "SOURCE_TEST_WEB_NOT_READY_AFTER_RESTORE"
  exit 1
fi
echo "SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE"
echo "RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED"
echo "INDEPENDENT_RESTORE_VERIFIED"
echo "RESTORE_TEST_DIR=$restore_dir"
