#!/usr/bin/env bash
# Snapshot the online fictional 2C staging state. The database and master-key
# copy go to separate private directories on the same Ubuntu host.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_SNAPSHOT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage="$HOME/teacher-workbench-staging-phase2c-20261022"
old="$HOME/teacher-workbench-staging-phase2b-20261020"
build="$HOME/teacher-workbench-staging-phase2c-migration-F6yZnxfi"
source_root="$build/src"
keyring="$HOME/teacher-workbench-staging-model-keyring"
root="$HOME/teacher-workbench-staging-backups"
escrow_root="$HOME/teacher-workbench-staging-key-escrow"
web=teacher-workbench-staging-web-1
gateway=teacher-workbench-staging-gateway-1
db=teacher-workbench-staging-db-1
redis=teacher-workbench-staging-redis-1
private=teacher-workbench-staging_staging_private
image=teacher-workbench-staging-web:member-quota-20261022

for directory in "$stage" "$old" "$build" "$source_root" "$keyring"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_2C_SNAPSHOT_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$stage/.env.staging" "$stage/compose.staging.yaml" \
            "$stage/config/nginx-staging.conf" \
            "$stage/APP_IMAGE_ID" "$stage/STATE" "$build/APP_IMAGE_ID" \
            "$build/IMAGE_BUILD_STATE" "$build/SOURCE_SHA256SUMS" \
            "$source_root/Dockerfile.phase2c-overlay" "$keyring/v1.key"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_2C_SNAPSHOT_SOURCE_FILE_UNSAFE
    exit 1
  fi
done
grep -Fxq 'name: teacher-workbench-staging' "$stage/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$stage/compose.staging.yaml"
grep -Fxq "    image: $image" "$stage/compose.staging.yaml"
grep -Fxq '      AI_ENABLED: "0"' "$stage/compose.staging.yaml"
grep -Fxq '      AI_API_KEY: ""' "$stage/compose.staging.yaml"
grep -Fxq '      AI_LOCAL_QUEUE: "0"' "$stage/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$stage/compose.staging.yaml"
grep -Fxq '      AI_MEMBER_TASKS_ENABLED: "0"' "$stage/compose.staging.yaml"
grep -Fxq '      MODEL_KEYRING_DIR: /run/model-keyring' "$stage/compose.staging.yaml"
grep -Fxq '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro' "$stage/compose.staging.yaml"
if [[ -L "$old/scripts/check_staging_env.py" || ! -f "$old/scripts/check_staging_env.py" ||
      -L "$old/scripts/check_test_env.py" || ! -f "$old/scripts/check_test_env.py" ]]; then
  echo STAGING_2C_SNAPSHOT_ENV_CHECKER_MISSING
  exit 1
fi
if [[ "$(cat "$stage/STATE")" != STAGING_2C_ONLINE_SWITCH_COMPLETE ]]; then
  echo STAGING_2C_SNAPSHOT_ONLINE_STATE_UNEXPECTED
  exit 1
fi
[[ "$(cat "$build/IMAGE_BUILD_STATE")" == STAGING_2C_OFFLINE_IMAGE_COMPLETE ]]
cmp -s "$stage/APP_IMAGE_ID" "$build/APP_IMAGE_ID"
python3 "$old/scripts/check_staging_env.py" --env-file "$stage/.env.staging" >/dev/null
(cd "$source_root" && sha256sum -c ../SOURCE_SHA256SUMS >/dev/null)
echo STAGING_2C_SNAPSHOT_CONFIG_AND_SOURCE_READY

sudo -v
echo STAGING_2C_SNAPSHOT_DOCKER_PREFLIGHT_START
for name in "$web" "$gateway" "$db" "$redis"; do
  [[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Status}}' "$name")" == running ]]
done
image_id="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' "$image")"
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(cat "$stage/APP_IMAGE_ID")" == "$image_id" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$image_id" ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run/model-keyring"}}{{.Source}}:{{.RW}}{{end}}{{end}}' "$web")" == "$keyring:false" ]]
timeout 20s sudo -n docker volume inspect "$private" >/dev/null
timeout 20s sudo -n docker exec "$db" sh -c 'pg_dump -Fc --schema-only -U "$POSTGRES_USER" "$POSTGRES_DB"' >/dev/null
timeout 45s sudo -n docker exec -i "$web" python - <<'PY'
import django
django.setup()
import os
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from django.utils import timezone
from workbench.credential_vault import vault_ready
from workbench.models import CallAllowance, CallAttempt, ModelCredential, WorksheetVersion
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_LOCAL_QUEUE
assert settings.MODEL_ACTIVE_KEY_VERSION == 1 and vault_ready()
assert os.getenv('TW_STAGING') == '1'
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
owner_count = ModelCredential.objects.filter(owner=owner).count()
if owner_count < 2:
    raise SystemExit(f'STAGING_2C_SNAPSHOT_OWNER_CONFIG_COUNT_UNEXPECTED={owner_count}')
assert not ModelCredential.objects.exclude(key_version=1).exists()
allowance = CallAllowance.objects.get(owner=owner)
assert (allowance.max_calls, allowance.used_calls, allowance.reserved_calls) == (0, 0, 0)
assert timezone.localtime(allowance.valid_until).strftime('%Y-%m-%d %H:%M') == '2026-10-30 23:00'
assert not CallAttempt.objects.exists()
print('STAGING_2C_SNAPSHOT_ZERO_ALLOWANCE_READY')
print(f'STAGING_2C_SNAPSHOT_FICTIONAL_ROWS_READY count={owner_count}')
PY
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002,):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_SNAPSHOT_LOGIN_HTTP_200')
PY
echo STAGING_2C_SNAPSHOT_PREFLIGHT_OK

for directory in "$root" "$escrow_root"; do
  [[ ! -L "$directory" ]] || { echo STAGING_2C_SNAPSHOT_ROOT_SYMLINK; exit 1; }
  mkdir -m 700 -p "$directory"
  [[ "$(stat -c %a "$directory")" == 700 ]]
done
exec 9>"$root/.snapshot.lock"
flock -n 9 || { echo STAGING_2C_SNAPSHOT_ALREADY_RUNNING; exit 1; }
backup="$(mktemp -d "$root/backup-phase2c-allowance-XXXXXXXX")"
suffix="${backup##*-}"
escrow="$escrow_root/keyring-$suffix"
mkdir -m 700 "$escrow"
printf 'INCOMPLETE\n' > "$backup/STATE"
printf 'INCOMPLETE\n' > "$escrow/STATE"
stopped=0
restart_if_needed() {
  if [[ "$stopped" == 1 ]]; then
    if timeout 60s sudo -n docker start "$web" "$gateway" >/dev/null; then
      echo STAGING_2C_APPLICATION_RESTARTED_AFTER_ERROR >&2
    else
      echo STAGING_2C_RESTART_NEEDS_REVIEW >&2
    fi
  fi
}
trap restart_if_needed EXIT

python3 - "$source_root" "$stage/compose.staging.yaml" \
          "$stage/config/nginx-staging.conf" "$backup/source.tar.gz" <<'PY'
import gzip
from io import BytesIO
from pathlib import Path
import sys
import tarfile

root, compose, nginx, output = map(Path, sys.argv[1:])
names = ['manage.py', 'requirements.txt', 'Dockerfile.phase2c-overlay']
names += [p.relative_to(root).as_posix() for directory in ('config', 'workbench', 'templates')
          for p in (root / directory).rglob('*')
          if p.is_file() and p.suffix in {'.py', '.html', '.css', '.js'}]
files = {name: root / name for name in names}
files['compose.staging.yaml'] = compose
files['config/nginx-staging.conf'] = nginx
if len(names) != len(set(names)) or not any(name.startswith('workbench/') for name in names):
    raise SystemExit('STAGING_2C_SOURCE_MANIFEST_UNSAFE')
for name, path in files.items():
    expected_root = compose.parent if name == 'compose.staging.yaml' else (
        nginx.parent if name == 'config/nginx-staging.conf' else root)
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(expected_root):
        raise SystemExit('STAGING_2C_SOURCE_MEMBER_UNSAFE')
with output.open('xb') as raw:
    with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w') as archive:
            for name, path in sorted(files.items()):
                payload = path.read_bytes()
                member = tarfile.TarInfo(name)
                member.size, member.mode, member.mtime = len(payload), 0o644, 0
                archive.addfile(member, BytesIO(payload))
print('STAGING_2C_SOURCE_ARCHIVE_READY')
PY

stopped=1
echo STAGING_2C_APPLICATION_STOP_START
timeout 60s sudo -n docker stop "$gateway" "$web" >/dev/null
echo STAGING_2C_APPLICATION_WRITES_STOPPED
install -m 600 "$keyring/v1.key" "$escrow/v1.key"
cmp -s "$keyring/v1.key" "$escrow/v1.key"
echo STAGING_2C_POSTGRES_DUMP_START
timeout 180s sudo -n docker exec "$db" sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$backup/db.dump"
echo STAGING_2C_POSTGRES_DUMP_READY
echo STAGING_2C_PRIVATE_ARCHIVE_START
timeout 180s sudo -n docker run --pull never --rm --network none --user 0:0 \
  -v "$private:/data:ro" --entrypoint sh redis:7-alpine \
  -c 'cd /data && tar -czf - .' > "$backup/private.tar.gz"
echo STAGING_2C_PRIVATE_ARCHIVE_READY
echo STAGING_2C_IMAGE_ARCHIVE_START
timeout 900s sudo -n docker image save "$image_id" | gzip -1 > "$backup/app-image.tar.gz"
echo STAGING_2C_IMAGE_ARCHIVE_READY
for file in db.dump private.tar.gz app-image.tar.gz source.tar.gz; do test -s "$backup/$file"; done
test -s "$escrow/v1.key"
timeout 30s sudo -n docker exec -i "$db" pg_restore --list < "$backup/db.dump" >/dev/null
tar -tzf "$backup/private.tar.gz" | grep -F materials/ >/dev/null
printf '%s\n' "$image_id" > "$backup/APP_IMAGE_ID"
sha256sum "$escrow/v1.key" | cut -d ' ' -f 1 > "$backup/KEY_SHA256"
(cd "$backup" && sha256sum db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID KEY_SHA256 > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum v1.key > SHA256SUMS && sha256sum -c SHA256SUMS >/dev/null)
for file in db.dump private.tar.gz app-image.tar.gz source.tar.gz APP_IMAGE_ID KEY_SHA256 SHA256SUMS STATE; do
  [[ "$(stat -c %a "$backup/$file")" == 600 ]]
done
for file in v1.key SHA256SUMS STATE; do [[ "$(stat -c %a "$escrow/$file")" == 600 ]]; done

echo STAGING_2C_APPLICATION_RESTART_START
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
                print('STAGING_2C_WEB_RESTARTED_HTTP_200')
                break
    except Exception:
        time.sleep(2)
else:
    raise SystemExit('STAGING_2C_WEB_NOT_READY')
PY
printf 'STAGING_2C_KEY_ESCROW_COMPLETE\n' > "$escrow/STATE"
printf 'STAGING_2C_ALLOWANCE_BACKUP_COMPLETE\n' > "$backup/STATE"
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
echo STAGING_2C_PAIRED_FILES_VERIFIED
echo "STAGING_2C_BACKUP_DIR=$backup"
echo "STAGING_2C_ESCROW_DIR=$escrow"
