#!/usr/bin/env bash
# Retry the returned USB package only after confirming the failed output is empty.
# The online keyring and same-host escrow are never mounted into this process.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo OFFLINE_KEY_RETRY_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

source_dir="$HOME/teacher-workbench-staging-offline-key-return-ddfae9d5abc1"
package="$source_dir/teacher-workbench-staging-model-key-v1.json"
destination="$HOME/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1"
helper="$HOME/offline_model_key_package.py"
backup="$HOME/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b"
expected_package_sha=969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc
expected_helper_sha=f37d85043c9485030dd1c7626d3edb49c7f0cb03ee5b0104aa1f14d8b6966ce0

for directory in "$source_dir" "$destination" "$backup"; do
  if [[ -L "$directory" || ! -d "$directory" ||
        "$(stat -c '%u:%g %a' "$directory")" != "$(id -u):$(id -g) 700" ]]; then
    echo OFFLINE_KEY_RETRY_DIRECTORY_UNSAFE
    exit 1
  fi
done

first_entry="$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit)"
if [[ -n "$first_entry" ]]; then
  echo OFFLINE_KEY_RETRY_TARGET_NOT_EMPTY
  exit 1
fi

for file in "$package" "$helper" "$backup/KEY_SHA256" "$backup/APP_IMAGE_ID"; do
  if [[ -L "$file" || ! -f "$file" ||
        "$(stat -c '%u:%g %a' "$file")" != "$(id -u):$(id -g) 600" ]]; then
    echo OFFLINE_KEY_RETRY_FILE_UNSAFE
    exit 1
  fi
done

[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == "$expected_helper_sha" ]]
[[ "$(sha256sum "$package" | cut -d ' ' -f 1)" == "$expected_package_sha" ]]
[[ "$(cat "$backup/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
echo OFFLINE_KEY_RETRY_EMPTY_TARGET_AND_DATA_VERIFIED

sudo -v
image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
timeout 10s sudo -n docker image inspect "$image" >/dev/null

echo '请输入第二次成功导出时设置的解锁口令；输入不显示，不要发送给助手。'
timeout 900s sudo -n docker run --pull never --rm -it --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$source_dir:/input:ro" -v "$destination:/output:rw" \
  -v "$helper:/app/offline_model_key_package.py:ro" \
  "$image" python /app/offline_model_key_package.py restore \
  /input/teacher-workbench-staging-model-key-v1.json /output/v1.key

[[ ! -L "$destination/v1.key" && -f "$destination/v1.key" &&
   "$(stat -c '%u:%g %a' "$destination/v1.key")" == "$(id -u):$(id -g) 600" ]]
[[ "$(sha256sum "$destination/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
echo OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA
echo "OFFLINE_KEY_RECOVERED_DIR=$destination"
echo OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED
