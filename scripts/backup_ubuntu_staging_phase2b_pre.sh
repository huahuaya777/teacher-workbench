#!/usr/bin/env bash
# Back up the current fictional 2A staging DB, private files, code and image.
# Uses fixed container names and Docker CLI; never writes to production or NAS.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua || "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_PHASE2B_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
stage="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
root="$HOME/teacher-workbench-staging-backups"
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1
db=teacher-workbench-staging-db-1
private=teacher-workbench-staging_staging_private
old_image=teacher-workbench-staging-web:accounts-20261018
if [[ -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != 700 ||
      -L "$stage/.env.staging" || ! -f "$stage/.env.staging" ||
      "$(stat -c %a "$stage/.env.staging")" != 600 ]]; then
  echo STAGING_PHASE2B_SOURCE_UNSAFE
  exit 1
fi
grep -Fxq 'name: teacher-workbench-staging' "$stage/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$stage/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$stage/compose.staging.yaml"
grep -Fxq "    image: $old_image" "$stage/compose.staging.yaml"
python3 "$stage/scripts/check_staging_env.py" --env-file "$stage/.env.staging" >/dev/null
sudo -v
for name in "$web" "$gateway" "$db" teacher-workbench-staging-redis-1; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$name")" == running ]] || {
    echo "STAGING_PHASE2B_SERVICE_NOT_RUNNING=$name"; exit 1;
  }
done
image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$old_image")"
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$image_id" ]]
timeout 10s sudo -n docker volume inspect "$private" >/dev/null
timeout 20s sudo -n docker exec "$db" sh -c 'pg_dump -Fc --schema-only -U "$POSTGRES_USER" "$POSTGRES_DB"' >/dev/null
timeout 45s sudo -n docker run --pull never --rm --network none --user 0:0 \
  -v "$private:/data:ro" --entrypoint sh redis:7-alpine \
  -c 'test -d /data/materials && tar -cf /dev/null -C /data materials' >/dev/null
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
with build_opener(ProxyHandler({})).open('http://127.0.0.1:18002/login/', timeout=5) as response:
    assert response.status == 200
print('STAGING_PHASE2B_PRE_BACKUP_PREFLIGHT_OK')
PY

if [[ -L "$root" ]]; then echo STAGING_PHASE2B_BACKUP_ROOT_SYMLINK; exit 1; fi
mkdir -m 700 -p "$root"
[[ "$(stat -c %a "$root")" == 700 ]]
exec 9>"$root/.phase2b-snapshot.lock"
flock -n 9 || { echo STAGING_PHASE2B_BACKUP_ALREADY_RUNNING; exit 1; }
backup="$(mktemp -d "$root/backup-phase2b-pre-XXXXXXXX")"
printf 'INCOMPLETE\n' > "$backup/STATE"
stopped=0
restart_if_needed() {
  if [[ "$stopped" == 1 ]]; then
    if timeout 60s sudo -n docker start "$web" "$gateway" >/dev/null; then
      echo STAGING_PHASE2B_APPLICATION_RESTARTED_AFTER_ERROR >&2
    else
      echo STAGING_PHASE2B_RESTART_NEEDS_REVIEW >&2
    fi
  fi
}
trap restart_if_needed EXIT

stopped=1
echo STAGING_PHASE2B_APPLICATION_STOP_START
timeout 60s sudo -n docker stop "$gateway" "$web" >/dev/null
echo STAGING_PHASE2B_APPLICATION_WRITES_STOPPED
timeout 180s sudo -n docker exec "$db" sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$backup/db.dump"
echo STAGING_PHASE2B_POSTGRES_DUMP_READY
echo STAGING_PHASE2B_PRIVATE_ARCHIVE_START
timeout 180s sudo -n docker run --pull never --rm --network none --user 0:0 \
  -v "$private:/data:ro" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -czf - .' > "$backup/private.tar.gz"
echo STAGING_PHASE2B_PRIVATE_ARCHIVE_READY

# Save the exact old image. Its Django code can later be run against the
# restored database, while the original online stack remains untouched.
echo STAGING_PHASE2B_OLD_IMAGE_ARCHIVE_START
timeout 900s sudo -n docker image save "$image_id" | gzip -1 > "$backup/app-image.tar.gz"
echo STAGING_PHASE2B_OLD_IMAGE_ARCHIVE_READY
python3 - "$stage" "$backup/source.tar.gz" <<'PY'
import gzip
from io import BytesIO
from pathlib import Path
import sys
import tarfile
root, output = map(Path, sys.argv[1:])
names = ['manage.py', 'requirements.txt', 'compose.staging.yaml',
         'Dockerfile.staging-offline', 'Dockerfile.phase2a-paired']
for directory in ('config', 'workbench', 'templates'):
    names.extend(p.relative_to(root).as_posix() for p in (root / directory).rglob('*')
                 if p.is_file() and p.suffix in {'.py', '.html', '.css', '.js', '.conf'})
names = sorted(set(names))
for name in names:
    path = root / name
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
        raise SystemExit('STAGING_PHASE2B_SOURCE_MEMBER_UNSAFE')
with output.open('xb') as raw:
    with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w') as archive:
            for name in names:
                payload = (root / name).read_bytes()
                info = tarfile.TarInfo(name)
                info.size = len(payload)
                info.mode = 0o644
                info.mtime = 0
                archive.addfile(info, BytesIO(payload))
print('STAGING_PHASE2B_SOURCE_ARCHIVE_READY')
PY
test -s "$backup/db.dump"
test -s "$backup/private.tar.gz"
test -s "$backup/app-image.tar.gz"
test -s "$backup/source.tar.gz"
timeout 30s sudo -n docker exec -i "$db" pg_restore --list < "$backup/db.dump" >/dev/null
tar -tzf "$backup/private.tar.gz" | grep -F materials/ >/dev/null
printf '%s\n' "$image_id" > "$backup/APP_IMAGE_ID"
(cd "$backup" && sha256sum db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
for file in db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID SHA256SUMS STATE; do
  [[ "$(stat -c %a "$backup/$file")" == 600 ]]
done

echo STAGING_PHASE2B_APPLICATION_RESTART_START
timeout 60s sudo -n docker start "$web" "$gateway" >/dev/null
stopped=0
python3 - <<'PY'
import time
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for _ in range(25):
    try:
        with opener.open('http://127.0.0.1:18002/login/', timeout=3) as response:
            if response.status == 200:
                print('STAGING_PHASE2B_WEB_RESTARTED_HTTP_200')
                break
    except Exception:
        time.sleep(2)
else:
    raise SystemExit('STAGING_PHASE2B_WEB_NOT_READY')
PY
printf 'STAGING_PHASE2B_PRE_BACKUP_COMPLETE\n' > "$backup/STATE"
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
echo STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED
echo "STAGING_PHASE2B_PRE_BACKUP_DIR=$backup"
