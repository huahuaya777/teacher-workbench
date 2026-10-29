#!/usr/bin/env bash
# Pair the completed fictional worksheet database dump with its private files.
# No NAS write, no volume deletion, no production access.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
stage="$HOME/teacher-workbench-staging-1d3ed18b"
helper="$HOME/verify_staging_generated_snapshot.py"
source_archive="$HOME/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
if [[ -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != "700" || -L "$helper" || ! -f "$helper" || -L "$source_archive" || ! -f "$source_archive" ]]; then
  echo "STAGING_BACKUP_SOURCE_UNSAFE"
  exit 1
fi
if [[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" != "56c3ecfc58dba52ed7765a22606978c1aa6db7514291849f4021f89dce6e42cb" ]]; then
  echo "STAGING_GENERATED_BACKUP_HELPER_HASH_MISMATCH"
  exit 1
fi
if [[ "$(sha256sum "$source_archive" | cut -d ' ' -f 1)" != "1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb" ]]; then
  echo "STAGING_GENERATED_BACKUP_ARCHIVE_HASH_MISMATCH"
  exit 1
fi
cd "$stage"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '      - "127.0.0.1:18002:8080"' compose.staging.yaml
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' compose.staging.yaml
grep -Fxq '    image: teacher-workbench-staging-web:manual-queue-20261017' compose.staging.yaml
for source_file in compose.staging.yaml Dockerfile.staging-offline config/nginx-staging.conf; do
  expected="$(tar -xOzf "$source_archive" "$source_file" | sha256sum | cut -d ' ' -f 1)"
  actual="$(sha256sum "$source_file" | cut -d ' ' -f 1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "STAGING_GENERATED_SOURCE_CONFIG_DIFFERS: $source_file"
    exit 1
  fi
done
test "$(stat -c %a .env.staging)" = 600
python3 scripts/check_staging_env.py --env-file .env.staging >/dev/null
compose=(sudo -n docker compose --env-file .env.staging -f compose.staging.yaml)
sudo -v
services="$("${compose[@]}" ps --status running --services)"
for service in db redis web gateway; do
  if ! grep -Fxq "$service" <<< "$services"; then
    echo "STAGING_BACKUP_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
test "$("${compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
test "$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" = "$(sudo -n docker image inspect -f '{{.Id}}' teacher-workbench-staging-web:manual-queue-20261017)"
sudo -n docker volume inspect teacher-workbench-staging_staging_private >/dev/null
timeout 60s "${compose[@]}" exec -T web python - < "$helper"
echo "STAGING_POSTGRES_PREFLIGHT_START"
timeout 45s "${compose[@]}" exec -T db sh -c 'pg_dump -Fc --schema-only -U "$POSTGRES_USER" "$POSTGRES_DB"' >/dev/null
echo "STAGING_POSTGRES_PREFLIGHT_OK"
timeout 45s sudo -n docker run --pull never --rm --network none --user 0:0 \
  -v teacher-workbench-staging_staging_private:/data:ro \
  --entrypoint sh redis:7-alpine -c 'test -d /data/materials && tar -cf /dev/null -C /data materials'
echo "STAGING_PRIVATE_PREFLIGHT_OK"

backup_root="$HOME/teacher-workbench-staging-backups"
if [[ -L "$backup_root" ]]; then
  echo "STAGING_BACKUP_ROOT_SYMLINK"
  exit 1
fi
mkdir -m 700 -p "$backup_root"
test "$(stat -c %a "$backup_root")" = 700
exec 9>"$backup_root/.snapshot.lock"
if ! flock -n 9; then
  echo "STAGING_BACKUP_ALREADY_RUNNING"
  exit 1
fi
backup_dir="$(mktemp -d "$backup_root/backup-generated-XXXXXXXX")"
printf 'INCOMPLETE\n' > "$backup_dir/STATE"

stopped=0
restart_if_needed() {
  if [[ "$stopped" == 1 ]]; then
    if timeout 90s "${compose[@]}" start web gateway >/dev/null; then
      echo "STAGING_APPLICATION_RESTARTED_AFTER_ERROR"
    else
      echo "STAGING_RESTART_NEEDS_MANUAL_ACTION" >&2
    fi
  fi
}
trap restart_if_needed EXIT

stopped=1
echo "STAGING_APPLICATION_STOP_START"
timeout 90s "${compose[@]}" stop gateway web >/dev/null
echo "STAGING_APPLICATION_WRITES_STOPPED"
echo "STAGING_POSTGRES_DUMP_START"
timeout 120s "${compose[@]}" exec -T db sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$backup_dir/db.dump"
echo "STAGING_POSTGRES_DUMP_READY"
echo "STAGING_PRIVATE_ARCHIVE_START"
timeout 120s sudo -n docker run --pull never --rm --network none --user 0:0 \
  -v teacher-workbench-staging_staging_private:/data:ro \
  --entrypoint sh redis:7-alpine -c 'cd /data && tar -czf - .' > "$backup_dir/private.tar.gz"
echo "STAGING_PRIVATE_ARCHIVE_READY"
test -s "$backup_dir/db.dump"
test -s "$backup_dir/private.tar.gz"
timeout 30s "${compose[@]}" exec -T db pg_restore --list < "$backup_dir/db.dump" >/dev/null
tar -tzf "$backup_dir/private.tar.gz" | grep 'materials/' >/dev/null
install -m 600 "$source_archive" "$backup_dir/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
(cd "$backup_dir" && sha256sum db.dump private.tar.gz teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
sha256sum "$source_archive" "$helper" compose.staging.yaml Dockerfile.staging-offline config/nginx-staging.conf > "$backup_dir/SOURCE_SHA256SUMS"
printf '%s\n' "$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" > "$backup_dir/APP_IMAGE_ID"

echo "STAGING_APPLICATION_RESTART_START"
timeout 90s "${compose[@]}" start web gateway >/dev/null
stopped=0
python3 - <<'PY'
import time
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for _ in range(25):
    try:
        with opener.open("http://127.0.0.1:18002/login/", timeout=3) as response:
            if response.status == 200:
                print("STAGING_WEB_RESTARTED_HTTP_200")
                break
    except Exception:
        time.sleep(2)
else:
    raise SystemExit("STAGING_WEB_NOT_READY_AFTER_BACKUP")
PY
printf 'STAGING_GENERATED_BACKUP_COMPLETE\n' > "$backup_dir/STATE"
echo "STAGING_GENERATED_BACKUP_FILES_VERIFIED"
echo "STAGING_GENERATED_BACKUP_DIR=$backup_dir"
