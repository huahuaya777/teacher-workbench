#!/usr/bin/env bash
# Encrypt only the fictional 2B staging master key into a private package.
# This runs in the existing app image without network, never touching live DB.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo OFFLINE_KEY_EXPORT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

helper="$HOME/offline_model_key_package.py"
keyring="$HOME/teacher-workbench-staging-model-keyring"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2b-keys-X6F4w9bJ"
imported="$HOME/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b"
stage="$HOME/teacher-workbench-staging-phase2b-20261020"
root="$HOME/teacher-workbench-staging-offline-key-packages"
web=teacher-workbench-staging-web-1

for directory in "$keyring" "$backup" "$imported" "$stage"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo OFFLINE_KEY_EXPORT_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$keyring/v1.key" "$backup/KEY_SHA256" "$imported/KEY_SHA256" "$helper"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo OFFLINE_KEY_EXPORT_SOURCE_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == f37d85043c9485030dd1c7626d3edb49c7f0cb03ee5b0104aa1f14d8b6966ce0 ]]
key_hash="$(sha256sum "$keyring/v1.key" | cut -d ' ' -f 1)"
[[ "$key_hash" == "$(cat "$backup/KEY_SHA256")" && "$key_hash" == "$(cat "$imported/KEY_SHA256")" ]]
[[ "$(cat "$backup/STATE")" == STAGING_2B_CREDENTIAL_BACKUP_COMPLETE ]]
[[ "$(cat "$imported/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$imported" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
grep -Fxq '      AI_ENABLED: "0"' "$stage/compose.staging.yaml"
grep -Fxq '      AI_API_KEY: ""' "$stage/compose.staging.yaml"

sudo -v
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$image" == "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' "$web")" ]]
timeout 10s sudo -n docker image inspect "$image" >/dev/null
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
with build_opener(ProxyHandler({})).open('http://127.0.0.1:18002/login/', timeout=5) as response:
    assert response.status == 200
print('OFFLINE_KEY_EXPORT_SOURCE_LOGIN_HTTP_200')
PY
echo OFFLINE_KEY_EXPORT_PREFLIGHT_OK

if [[ -L "$root" ]]; then
  echo OFFLINE_KEY_EXPORT_ROOT_UNSAFE
  exit 1
fi
mkdir -m 700 -p "$root"
[[ "$(stat -c %a "$root")" == 700 ]]
package_dir="$(mktemp -d "$root/package-XXXXXXXX")"
[[ "$(stat -c %a "$package_dir")" == 700 ]]
package="$package_dir/teacher-workbench-staging-model-key-v1.json"

echo '只在当前终端输入你自己设置的长解锁口令；不要发到聊天、写进命令或项目文件。'
timeout 900s sudo -n docker run --pull never --rm -it --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$keyring:/input:ro" -v "$package_dir:/output:rw" \
  -v "$helper:/app/offline_model_key_package.py:ro" \
  "$image" python /app/offline_model_key_package.py export \
  /input/v1.key /output/teacher-workbench-staging-model-key-v1.json

[[ ! -L "$package" && -f "$package" && "$(stat -c %a "$package")" == 600 ]]
python3 - "$package" <<'PY'
import json
from pathlib import Path
import sys
package = json.loads(Path(sys.argv[1]).read_text(encoding='ascii'))
assert package['format'] == 'teacher-workbench-offline-model-key-v1'
assert package['key_version'] == 1
assert 'ciphertext' in package and 'salt' in package and 'nonce' in package
assert 'v1.key' not in package and 'api_key' not in package
print('OFFLINE_KEY_EXPORT_PACKAGE_STRUCTURE_OK')
PY
echo "OFFLINE_KEY_PACKAGE_PATH=$package"
echo "OFFLINE_KEY_PACKAGE_SHA256=$(sha256sum "$package" | cut -d ' ' -f 1)"
echo OFFLINE_KEY_ENCRYPTED_EXPORT_READY
