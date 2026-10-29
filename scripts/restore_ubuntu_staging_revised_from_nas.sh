#!/usr/bin/env bash
# Restore both fictional worksheet versions from a NAS-imported copy to new volumes.
# The active staging site uses a newer renderer; the paired old image stays pinned.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 1 ]]; then
  echo "USAGE: restore_ubuntu_staging_revised_from_nas.sh /home/huahua/teacher-workbench-nas-import-staging-revised-X7Bv9cfE-<12 lowercase hex>"
  exit 1
fi
backup_dir="$1"
stage="$HOME/teacher-workbench-staging-1d3ed18b"
helper="$HOME/verify_staging_revised_nas_snapshot.py"
prefix="teacher-workbench-staging-revised-nas-restore-20261017"
restore_dir="$HOME/$prefix"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db_container="$prefix-db"
redis_container="$prefix-redis"

if [[ ! "$backup_dir" =~ ^/home/huahua/teacher-workbench-nas-import-staging-revised-X7Bv9cfE-[0-9a-f]{12}$ ]] || [[ -L "$backup_dir" || ! -d "$backup_dir" || "$(stat -c %a "$backup_dir")" != 700 ]]; then
  echo "STAGING_RESTORE_BACKUP_PATH_UNSAFE"
  exit 1
fi
if [[ -e "$restore_dir" || -L "$restore_dir" || -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != 700 || -L "$helper" || ! -f "$helper" ]]; then
  echo "STAGING_RESTORE_SOURCE_OR_TARGET_UNSAFE"
  exit 1
fi
if [[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" != "4b3afde68284266c9f3b3937b27252b93485d31486c8d2220d17e4b7b834b682" ]]; then
  echo "STAGING_REVISED_NAS_RESTORE_HELPER_HASH_MISMATCH"
  exit 1
fi
if [[ "$(cat "$backup_dir/STATE")" != STAGING_REVISED_BACKUP_COMPLETE ]]; then
  echo "STAGING_RESTORE_BACKUP_INCOMPLETE"
  exit 1
fi
if [[ "$(cat "$backup_dir/NAS_TRANSFER_STATE")" != NAS_TRANSFER_COMPLETE ]]; then
  echo "STAGING_NAS_RESTORE_TRANSFER_INCOMPLETE"
  exit 1
fi
for file in db.dump private.tar.gz teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz teacher-workbench-staging-linebreak-fix-7198283e.tar.gz apply_ubuntu_staging_linebreak_fix.sh SHA256SUMS SOURCE_SHA256SUMS APP_IMAGE_ID STATE NAS_SHA256SUMS NAS_TRANSFER_STATE; do
  if [[ -L "$backup_dir/$file" || ! -f "$backup_dir/$file" || "$(stat -c %a "$backup_dir/$file")" != 600 ]]; then
    echo "STAGING_RESTORE_BACKUP_FILE_UNSAFE: $file"
    exit 1
  fi
done
(cd "$backup_dir" && sha256sum -c NAS_SHA256SUMS >/dev/null && sha256sum -c SHA256SUMS >/dev/null)
(cd "$backup_dir" && test "$(sha256sum teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz | cut -d ' ' -f 1)" = '1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb')
(cd "$backup_dir" && test "$(sha256sum teacher-workbench-staging-linebreak-fix-7198283e.tar.gz | cut -d ' ' -f 1)" = '7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d')
(cd "$backup_dir" && test "$(sha256sum apply_ubuntu_staging_linebreak_fix.sh | cut -d ' ' -f 1)" = '11c86b65650f29b4edd21f27c44f766e62cb1e269d6a7f68e9b0b1398fb0019c')
(cd "$stage" && sha256sum -c "$backup_dir/SOURCE_SHA256SUMS" >/dev/null)
python3 - "$backup_dir/private.tar.gz" <<'PY'
import sys
import tarfile
from pathlib import PurePosixPath
with tarfile.open(sys.argv[1], "r:gz") as archive:
    names = []
    for member in archive:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not (member.isfile() or member.isdir()):
            raise SystemExit("STAGING_RESTORE_UNSAFE_ARCHIVE_MEMBER")
        names.append(str(path))
if not any(name.startswith("materials/") or name.startswith("./materials/") for name in names):
    raise SystemExit("STAGING_RESTORE_MATERIAL_MISSING")
PY

cd "$stage"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '      - "127.0.0.1:18002:8080"' compose.staging.yaml
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' compose.staging.yaml
test "$(stat -c %a .env.staging)" = 600
python3 scripts/check_staging_env.py --env-file .env.staging >/dev/null
sudo -v
compose=(sudo -n docker compose --env-file .env.staging -f compose.staging.yaml)
for service in db redis web gateway; do
  if ! "${compose[@]}" ps --status running --services | grep -Fxq "$service"; then
    echo "STAGING_RESTORE_SOURCE_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
test "$("${compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
"${compose[@]}" exec -T db pg_restore --list < "$backup_dir/db.dump" >/dev/null
image="$(cat "$backup_dir/APP_IMAGE_ID")"
paired_image="$(sudo -n docker image inspect -f '{{.Id}}' teacher-workbench-staging-web:manual-queue-20261017)"
if [[ ! "$image" =~ ^sha256:[0-9a-f]{64}$ || "$image" != "$paired_image" ]]; then
  echo "STAGING_RESTORE_PAIRED_IMAGE_MISMATCH"
  exit 1
fi
sudo -n docker image inspect postgres:17 redis:7-alpine "$image" >/dev/null
for item in "$db_volume" "$private_volume"; do
  if sudo -n docker volume inspect "$item" >/dev/null 2>&1; then
    echo "STAGING_RESTORE_VOLUME_EXISTS"
    exit 1
  fi
done
if sudo -n docker network inspect "$network" >/dev/null 2>&1; then
  echo "STAGING_RESTORE_NETWORK_EXISTS"
  exit 1
fi
for item in "$db_container" "$redis_container"; do
  if sudo -n docker container inspect "$item" >/dev/null 2>&1; then
    echo "STAGING_RESTORE_CONTAINER_EXISTS"
    exit 1
  fi
done
echo "STAGING_REVISED_NAS_RESTORE_ISOLATION_PREFLIGHT_OK"

mkdir -m 700 "$restore_dir"
env_file="$restore_dir/.env.staging"
python3 - "$env_file" <<'PY'
import os
import secrets
import sys
password = secrets.token_hex(24)
values = [
    "DJANGO_DEBUG=1", f"DJANGO_SECRET_KEY={secrets.token_hex(32)}",
    "DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1",
    "DB_NAME=teacher_workbench_staging", "DB_USER=teacher_workbench_staging",
    f"DB_PASSWORD={password}", "TW_STAGING=1",
    "POSTGRES_DB=teacher_workbench_staging", "POSTGRES_USER=teacher_workbench_staging",
    f"POSTGRES_PASSWORD={password}",
    "DJANGO_SETTINGS_MODULE=config.settings_staging",
    "AI_ENABLED=0", "AI_API_KEY=", "AI_LOCAL_QUEUE=0", "AI_STAGING_MANUAL_QUEUE=1",
]
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as output:
    output.write("\n".join(values) + "\n")
PY
echo "STAGING_RESTORE_TEST_ENV_READY (random secrets hidden)"

created=1
stop_if_needed() {
  if [[ "$created" == 1 ]]; then
    timeout 30s sudo -n docker stop "$redis_container" "$db_container" >/dev/null 2>&1 || true
  fi
}
trap stop_if_needed EXIT
timeout 30s sudo -n docker network create "$network" >/dev/null
timeout 30s sudo -n docker volume create "$db_volume" >/dev/null
timeout 30s sudo -n docker volume create "$private_volume" >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$db_container" --network "$network" \
  --env-file "$env_file" \
  -v "$db_volume:/var/lib/postgresql/data" postgres:17 >/dev/null
timeout 60s sudo -n docker run --pull never -d --name "$redis_container" --network "$network" \
  redis:7-alpine >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$db_container" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != 1 ]]; then
  echo "STAGING_RESTORE_DATABASE_NOT_READY"
  exit 1
fi
echo "STAGING_RESTORE_EMPTY_DATABASE_READY"
timeout 120s sudo -n docker exec -i "$db_container" pg_restore --exit-on-error --no-owner --no-privileges \
  -U teacher_workbench_staging -d teacher_workbench_staging < "$backup_dir/db.dump"
echo "STAGING_RESTORE_POSTGRES_READY"
timeout 120s sudo -n docker run --pull never --rm -i --network none --user 0:0 \
  -v "$private_volume:/data" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -xzf -' < "$backup_dir/private.tar.gz"
echo "STAGING_RESTORE_PRIVATE_READY"
timeout 60s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$env_file" -e DB_HOST="$db_container" \
  -e REDIS_URL="redis://$redis_container:6379/0" \
  -e PRIVATE_FILE_ROOT=/app/data/private \
  -e STAGING_REVISED_VERIFY_RESTORED=1 \
  -v "$private_volume:/app/data/private:ro" "$image" python - < "$helper"
timeout 30s sudo -n docker stop "$redis_container" "$db_container" >/dev/null
created=0
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_RESTORE_SOURCE_LOGIN_FAILED")
print("STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE")
PY
echo "STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED"
echo "STAGING_REVISED_NAS_SOURCE_RESTORE_VERIFIED"
echo "STAGING_REVISED_NAS_RESTORE_DIR=$restore_dir"
