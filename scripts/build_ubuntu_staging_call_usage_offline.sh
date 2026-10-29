#!/usr/bin/env bash
# Build the reviewed call-usage page on the current fictional staging image.
# This script never changes Compose, the online database, or running services.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_CALL_USAGE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

source_sha=14537acaacc62f0584cd3d567028b158fe3d3cfab501128fdba6a5ba7b1105ca
suffix="${source_sha:0:12}"
bundle="$HOME/teacher-workbench-stage2c-guard-v3-source.tar.gz"
stage="$HOME/teacher-workbench-staging-call-usage-$suffix"
src="$stage/src"
online="$HOME/teacher-workbench-staging-phase2c-20261022"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2c-allowance-j33bqT1R"
web=teacher-workbench-staging-web-1
old_tag=teacher-workbench-staging-web:member-quota-20261022
new_tag="teacher-workbench-staging-web:call-usage-$suffix"
old_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a

for directory in "$online" "$backup"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]] || {
    echo STAGING_CALL_USAGE_SOURCE_DIRECTORY_UNSAFE
    exit 1
  }
done
for file in "$online/APP_IMAGE_ID" "$online/STATE" "$backup/source.tar.gz" \
            "$backup/SHA256SUMS" "$backup/APP_IMAGE_ID"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]] || {
    echo STAGING_CALL_USAGE_SOURCE_FILE_UNSAFE
    exit 1
  }
done
[[ "$(cat "$online/STATE")" == STAGING_2C_ONLINE_SWITCH_COMPLETE ]]
[[ "$(cat "$online/APP_IMAGE_ID")" == "$old_id" ]]
[[ "$(cat "$backup/APP_IMAGE_ID")" == "$old_id" ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
[[ ! -L "$bundle" && -f "$bundle" &&
   "$(sha256sum "$bundle" | cut -d ' ' -f 1)" == "$source_sha" ]] || {
  echo STAGING_CALL_USAGE_BUNDLE_UNSAFE
  exit 1
}
[[ ! -e "$stage" && ! -L "$stage" ]] || {
  echo STAGING_CALL_USAGE_TARGET_EXISTS
  exit 1
}

python3 - "$bundle" "$backup/source.tar.gz" <<'PY'
from pathlib import PurePosixPath
import sys
import tarfile

with tarfile.open(sys.argv[1], 'r:gz') as archive:
    members = archive.getmembers()
    names = {item.name for item in members}
    assert len(members) == 77 and len(names) == 77
    assert all(item.isfile() and not item.issym() and not item.islnk() for item in members)
    assert all(not PurePosixPath(item.name).is_absolute() and
               '..' not in PurePosixPath(item.name).parts for item in members)
    assert {'templates/workbench/_task_call_usage.html',
            'workbench/management/commands/reconcile_member_calls.py'} <= names
    requirements = archive.extractfile('requirements.txt').read()
with tarfile.open(sys.argv[2], 'r:gz') as archive:
    old_names = {item.name for item in archive if item.isfile() and
                 PurePosixPath(item.name).suffix in ('.py', '.html', '.css', '.js')}
    old_requirements = archive.extractfile('requirements.txt').read()
assert old_names <= names, 'new image would retain obsolete 2C source files'
assert requirements == old_requirements, 'new requirements need a separate dependency build'
print('STAGING_CALL_USAGE_SOURCE_AND_OVERLAY_VERIFIED')
PY

sudo -n -v || { echo STAGING_CALL_USAGE_SUDO_AUTH_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$old_tag")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$web")" == running ]]
if timeout 15s sudo -n docker image inspect "$new_tag" >/dev/null 2>&1; then
  echo STAGING_CALL_USAGE_IMAGE_TAG_EXISTS
  exit 1
fi

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_OLD_LOGINS_HTTP_200')
PY
echo STAGING_CALL_USAGE_OFFLINE_BUILD_PREFLIGHT_OK

mkdir -m 700 "$stage"
mkdir -m 700 "$src"
tar -xzf "$bundle" -C "$src" --no-same-owner --no-same-permissions
python3 - "$bundle" "$src" "$stage/SOURCE_SHA256SUMS" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys
import tarfile

bundle, source, manifest = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
with tarfile.open(bundle, 'r:gz') as archive, manifest.open('x', encoding='ascii', newline='\n') as output:
    for item in archive:
        path = source.joinpath(*item.name.split('/'))
        payload = archive.extractfile(item).read()
        assert path.is_file() and not path.is_symlink() and path.read_bytes() == payload
        output.write(f'{sha256(payload).hexdigest()}  {item.name}\n')
manifest.chmod(0o600)
PY
cat > "$src/Dockerfile.call-usage-overlay" <<'DOCKERFILE'
FROM teacher-workbench-staging-web:member-quota-20261022
COPY manage.py requirements.txt /app/
COPY config/ /app/config/
COPY workbench/ /app/workbench/
COPY templates/ /app/templates/
DOCKERFILE
chmod 600 "$src/Dockerfile.call-usage-overlay"

echo STAGING_CALL_USAGE_OFFLINE_IMAGE_BUILD_START
timeout 1200s sudo -n docker build --pull=false --no-cache --network none \
  -f "$src/Dockerfile.call-usage-overlay" -t "$new_tag" "$src"
new_id="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$new_tag")"
[[ "$new_id" =~ ^sha256:[0-9a-f]{64}$ && "$new_id" != "$old_id" ]]
printf '%s\n' "$new_id" > "$stage/APP_IMAGE_ID"
timeout 90s sudo -n docker run --pull never --rm --network none --read-only \
  -v "$stage/SOURCE_SHA256SUMS:/tmp/source.sha256:ro" "$new_tag" \
  sh -c 'cd /app && sha256sum -c /tmp/source.sha256 >/dev/null && echo STAGING_CALL_USAGE_IMAGE_SOURCE_MATCH_OK'
timeout 90s sudo -n docker run --pull never --rm --network none --read-only \
  -e DJANGO_DEBUG=1 -e AI_ENABLED=0 -e AI_MEMBER_TASKS_ENABLED=0 -e AI_API_KEY= \
  "$new_tag" python manage.py check
echo STAGING_CALL_USAGE_IMAGE_DJANGO_CHECK_OK

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_ONLINE_LOGINS_STILL_HTTP_200')
PY
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$old_id" ]]
printf 'STAGING_CALL_USAGE_OFFLINE_IMAGE_COMPLETE\n' > "$stage/STATE"
echo "STAGING_CALL_USAGE_OFFLINE_IMAGE_ID=$new_id"
echo "STAGING_CALL_USAGE_OFFLINE_IMAGE_DIR=$stage"
echo STAGING_CALL_USAGE_OFFLINE_IMAGE_BUILT_NO_SWITCH
