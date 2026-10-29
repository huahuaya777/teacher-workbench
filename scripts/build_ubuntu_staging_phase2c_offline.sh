#!/usr/bin/env bash
# Build the reviewed 2C source on the local 2B image, then smoke-test only
# against the already migrated fictional restore copy. No online switch.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_IMAGE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

suffix=F6yZnxfi
source_sha=36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303
bundle="$HOME/teacher-workbench-stage2c-pg-source.tar.gz"
stage="$HOME/teacher-workbench-staging-phase2c-migration-$suffix"
src="$stage/src"
restore="$HOME/teacher-workbench-staging-phase2b-keys-restore-$suffix"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2b-keys-$suffix"
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-$suffix"
prefix="teacher-workbench-staging-phase2b-keys-restore-$suffix"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db="$prefix-db"
redis="$prefix-redis"
probe="teacher-workbench-staging-phase2c-image-$suffix-probe"
old_tag=teacher-workbench-staging-web:credentials-20261020
new_tag=teacher-workbench-staging-web:member-quota-20261022
online_web=teacher-workbench-staging-web-1

for directory in "$stage" "$src" "$restore" "$backup" "$escrow"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo STAGING_2C_IMAGE_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$stage/STATE" "$restore/.env.staging" "$backup/APP_IMAGE_ID" \
            "$backup/SHA256SUMS" "$backup/STATE" "$escrow/v1.key"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo STAGING_2C_IMAGE_SOURCE_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(cat "$stage/STATE")" == STAGING_2C_RESTORE_MIGRATION_COMPLETE ]]
[[ "$(cat "$backup/STATE")" == STAGING_2B_CREDENTIAL_BACKUP_COMPLETE ]]
if [[ -L "$bundle" || ! -f "$bundle" ||
      "$(sha256sum "$bundle" | cut -d ' ' -f 1)" != "$source_sha" ]]; then
  echo STAGING_2C_IMAGE_BUNDLE_UNSAFE
  exit 1
fi
for output in "$src/Dockerfile.phase2c-overlay" "$stage/SOURCE_SHA256SUMS" \
              "$stage/APP_IMAGE_ID" "$stage/IMAGE_BUILD_STATE"; do
  if [[ -e "$output" || -L "$output" ]]; then
    echo STAGING_2C_IMAGE_OUTPUT_EXISTS
    exit 1
  fi
done
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)

# The user authenticates sudo in an interactive SSH shell before this script.
sudo -n -v || { echo STAGING_2C_IMAGE_SUDO_AUTH_REQUIRED; exit 1; }
old_image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$old_image" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" == "$old_image" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$online_web")" == "$old_image" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$online_web")" == running ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$db")" == "$network" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$redis")" == "$network" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$db")" == "$db_volume" ]]
timeout 15s sudo -n docker network inspect "$network" >/dev/null
timeout 15s sudo -n docker volume inspect "$private_volume" >/dev/null
if timeout 15s sudo -n docker image inspect "$new_tag" >/dev/null 2>&1 ||
   timeout 15s sudo -n docker container inspect "$probe" >/dev/null 2>&1; then
  echo STAGING_2C_IMAGE_TARGET_EXISTS
  exit 1
fi
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_IMAGE_ONLINE_LOGINS_BEFORE_HTTP_200')
PY
echo STAGING_2C_IMAGE_ISOLATION_PREFLIGHT_OK

python3 - "$bundle" "$backup/source.tar.gz" "$src" <<'PY'
from hashlib import sha256
from pathlib import Path, PurePosixPath
import sys
import tarfile

bundle, old_archive, source = sys.argv[1], sys.argv[2], Path(sys.argv[3])
with tarfile.open(bundle, 'r:gz') as archive:
    members = archive.getmembers()
    names = {member.name for member in members}
    assert len(members) == 74 and len(names) == 74
    lines = []
    for member in members:
        path = PurePosixPath(member.name)
        assert member.isfile() and not member.issym() and not member.islnk()
        assert not path.is_absolute() and '..' not in path.parts
        actual = source.joinpath(*path.parts)
        assert actual.is_file() and not actual.is_symlink()
        content = archive.extractfile(member).read()
        assert actual.read_bytes() == content
        lines.append(f'{sha256(content).hexdigest()}  {member.name}\n')
with tarfile.open(old_archive, 'r:gz') as archive:
    old_names = {item.name for item in archive if item.isfile() and
                 PurePosixPath(item.name).suffix in ('.py', '.html', '.css', '.js')}
assert old_names <= names, '2C overlay would leave removed 2B source files in the image'
print('STAGING_2C_IMAGE_SOURCE_AND_OVERLAY_VERIFIED')

manifest = source.parent / 'SOURCE_SHA256SUMS'
with manifest.open('x', encoding='ascii', newline='\n') as output:
    output.writelines(lines)
manifest.chmod(0o600)
dockerfile = source / 'Dockerfile.phase2c-overlay'
with dockerfile.open('x', encoding='ascii', newline='\n') as output:
    output.write('FROM teacher-workbench-staging-web:credentials-20261020\n'
                 'COPY manage.py requirements.txt /app/\n'
                 'COPY config/ /app/config/\n'
                 'COPY workbench/ /app/workbench/\n'
                 'COPY templates/ /app/templates/\n')
dockerfile.chmod(0o600)
PY

echo STAGING_2C_OFFLINE_IMAGE_BUILD_START
timeout 1200s sudo -n docker build --pull=false --no-cache --network none \
  -f "$src/Dockerfile.phase2c-overlay" -t "$new_tag" "$src"
new_image="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$new_image" =~ ^sha256:[0-9a-f]{64}$ && "$new_image" != "$old_image" ]]
printf '%s\n' "$new_image" > "$stage/APP_IMAGE_ID"
timeout 90s sudo -n docker run --pull never --rm --network none \
  -v "$stage/SOURCE_SHA256SUMS:/tmp/source.sha256:ro" "$new_tag" \
  sh -c 'cd /app && sha256sum -c /tmp/source.sha256 >/dev/null && echo STAGING_2C_OFFLINE_IMAGE_SOURCE_MATCH_OK'

services_started=0
probe_started=0
cleanup() {
  rc=$?
  if [[ "$probe_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$probe" >/dev/null 2>&1 || true
  fi
  if [[ "$services_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo STAGING_2C_IMAGE_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$rc" != 0 ]]; then echo STAGING_2C_OFFLINE_IMAGE_SMOKE_FAILED; fi
}
trap cleanup EXIT

services_started=1
timeout 60s sudo -n docker start "$db" "$redis" >/dev/null
ready=0
for ((index=0; index<45; index++)); do
  if timeout 8s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_IMAGE_DB_NOT_READY; exit 1; }
ready=0
for ((index=0; index<20; index++)); do
  if timeout 8s sudo -n docker exec "$redis" redis-cli ping 2>/dev/null | grep -Fxq PONG; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo STAGING_2C_IMAGE_REDIS_NOT_READY; exit 1; }

common_args=(--pull never --rm --name "$probe" --network "$network"
  --env-file "$restore/.env.staging" -e DB_HOST="$db"
  -e REDIS_URL="redis://$redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0
  -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0
  -v "$private_volume:/app/data/private:ro" -v "$escrow:/run/model-keyring:ro")
probe_started=1
timeout 90s sudo -n docker run "${common_args[@]}" "$new_tag" python manage.py check
probe_started=0
probe_started=1
timeout 90s sudo -n docker run "${common_args[@]}" "$new_tag" python manage.py migrate --check --noinput
probe_started=0
probe_started=1
timeout 90s sudo -n docker run -i "${common_args[@]}" "$new_tag" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.migrations.recorder import MigrationRecorder
from workbench.credential_vault import unseal_key_for_owner, vault_ready
from workbench.models import CallAllowance, CallAttempt, ModelCredential, WorksheetVersion

assert settings.DATABASES['default']['HOST'] == 'teacher-workbench-staging-phase2b-keys-restore-F6yZnxfi-db'
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_API_KEY
assert settings.AI_STAGING_MANUAL_QUEUE and vault_ready()
applied = set(MigrationRecorder.Migration.objects.filter(app='workbench').values_list('name', flat=True))
assert {'0006_callallowance_callattempt', '0007_alter_memberaudit_action',
        '0008_generationtask_member_credential_and_more'} <= applied
assert not CallAllowance.objects.exists() and not CallAttempt.objects.exists()
owner = get_user_model().objects.get(username='staging_teacher_a_20261018', is_active=True)
credentials = list(ModelCredential.objects.filter(owner=owner))
assert len(credentials) >= 2
assert all(unseal_key_for_owner(item, owner.pk).startswith('sk-fictional-') for item in credentials)
assert WorksheetVersion.objects.filter(worksheet__owner__username='staging_preview_20261017', number=2).exists()
print('STAGING_2C_OFFLINE_IMAGE_RESTORED_CONTENT_OK')
PY
probe_started=0

timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null
services_started=0
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_OFFLINE_IMAGE_ONLINE_LOGINS_STILL_HTTP_200')
PY
printf 'STAGING_2C_OFFLINE_IMAGE_COMPLETE\n' > "$stage/IMAGE_BUILD_STATE"
echo STAGING_2C_OFFLINE_IMAGE_RESTORE_CONTAINERS_STOPPED
echo "STAGING_2C_OFFLINE_IMAGE_ID=$new_image"
echo STAGING_2C_OFFLINE_IMAGE_BUILT_SMOKE_VERIFIED_NO_SWITCH
