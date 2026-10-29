#!/usr/bin/env bash
# Recover the fictional staging key from an encrypted file returned from USB.
# The online keyring and same-host escrow are never mounted into this process.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 2 ]]; then
  echo OFFLINE_KEY_RESTORE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

package="$1"
expected_sha="$2"
if [[ ! "$package" =~ ^/home/huahua/teacher-workbench-staging-offline-key-return-([0-9a-f]{12})/teacher-workbench-staging-model-key-v1.json$ ]]; then
  echo OFFLINE_KEY_RESTORE_ARGUMENTS_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
if [[ ! "$expected_sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo OFFLINE_KEY_RESTORE_ARGUMENTS_UNSAFE
  exit 1
fi
source_dir="$(dirname "$package")"
destination="$HOME/teacher-workbench-staging-offline-key-restore-$suffix"
helper="$HOME/offline_model_key_package.py"
backup="$HOME/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b"

for directory in "$source_dir" "$backup"; do
  if [[ -L "$directory" || ! -d "$directory" || "$(stat -c %a "$directory")" != 700 ]]; then
    echo OFFLINE_KEY_RESTORE_SOURCE_DIRECTORY_UNSAFE
    exit 1
  fi
done
for file in "$package" "$helper" "$backup/KEY_SHA256" "$backup/APP_IMAGE_ID"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo OFFLINE_KEY_RESTORE_SOURCE_FILE_UNSAFE
    exit 1
  fi
done
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == f37d85043c9485030dd1c7626d3edb49c7f0cb03ee5b0104aa1f14d8b6966ce0 ]]
[[ "$(sha256sum "$package" | cut -d ' ' -f 1)" == "$expected_sha" ]]
[[ "$(cat "$backup/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ ! -e "$destination" && ! -L "$destination" ]] || {
  echo OFFLINE_KEY_RESTORE_TARGET_EXISTS
  exit 1
}
echo OFFLINE_KEY_RETURN_PACKAGE_AND_DATA_VERIFIED

sudo -v
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
timeout 10s sudo -n docker image inspect "$image" >/dev/null

mkdir -m 700 "$destination"
echo '请在当前终端输入离线恢复包的解锁口令；不要发送给助手或写入命令。'
timeout 900s sudo -n docker run --pull never --rm -it --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$source_dir:/input:ro" -v "$destination:/output:rw" \
  -v "$helper:/app/offline_model_key_package.py:ro" \
  "$image" python /app/offline_model_key_package.py restore \
  /input/teacher-workbench-staging-model-key-v1.json /output/v1.key

[[ ! -L "$destination/v1.key" && -f "$destination/v1.key" &&
   "$(stat -c %a "$destination/v1.key")" == 600 ]]
[[ "$(sha256sum "$destination/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
echo OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA
echo "OFFLINE_KEY_RECOVERED_DIR=$destination"
echo OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED
