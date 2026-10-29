#!/usr/bin/env bash
# Verify and decrypt a returned pilot escrow package without mounting online secrets.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 2 || ! -t 0 ]]; then
  echo PILOT_ESCROW_RESTORE_WRONG_HOST_USER_OR_TERMINAL
  exit 1
fi
package="$1"
expected_sha="$2"
if [[ ! "$package" =~ ^/home/huahua/teacher-workbench-pilot-offline-escrow-return-([0-9a-f]{12})/teacher-workbench-pilot-escrow-Lx7aqLEz.json$ ]]; then
  echo PILOT_ESCROW_RESTORE_ARGUMENTS_UNSAFE
  exit 1
fi
if [[ ! "$expected_sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo PILOT_ESCROW_RESTORE_ARGUMENTS_UNSAFE
  exit 1
fi
source_dir="$(dirname "$package")"
attempt_suffix="$(python3 -c 'import secrets; print(secrets.token_hex(6))')"
[[ "$attempt_suffix" =~ ^[0-9a-f]{12}$ ]]
destination="$HOME/teacher-workbench-pilot-offline-escrow-restore-$attempt_suffix"
imported="$HOME/teacher-workbench-nas-import-pilot-manager-data-Lx7aqLEz-9037d08db8d9"
pilot="$HOME/teacher-workbench-pilot"
helper="$HOME/offline_pilot_escrow_package.py"

for directory in "$source_dir" "$imported" "$pilot"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]]
done
for file in "$package" "$helper" "$imported/KEY_SHA256" "$imported/CA_SHA256"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]]
done
[[ "$(sha256sum "$package" | cut -d ' ' -f 1)" == "$expected_sha" ]]
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == 94d3f83d3f07b2cf222a9f3252242706c3cf67231a822989b82081419af50dfd ]]
[[ "$(cat "$imported/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(cat "$imported/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
(cd "$imported" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ ! -e "$destination" && ! -L "$destination" ]]
echo PILOT_ESCROW_RETURN_PACKAGE_AND_NAS_DATA_VERIFIED

sudo -v
image="$(head -n 1 "$imported/IMAGE_IDS")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
timeout 15s sudo -n docker image inspect "$image" >/dev/null
mkdir -m 700 "$destination"
echo '请在当前可见终端输入离线解锁口令；不要发给助手或写入命令。'
timeout 900s sudo -n docker run --pull never --rm -it --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$source_dir:/input:ro" -v "$destination:/output:rw" \
  -v "$helper:/app/offline_pilot_escrow_package.py:ro" \
  "$image" python /app/offline_pilot_escrow_package.py restore \
  /input/teacher-workbench-pilot-escrow-Lx7aqLEz.json /output

[[ "$(cat "$destination/STATE")" == PILOT_ESCROW_COMPLETE ]]
(cd "$destination" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$destination/v1.key" | cut -d ' ' -f 1)" == "$(cat "$imported/KEY_SHA256")" ]]
root_ca_hash="$(tar -xOzf "$destination/caddy_data.tar.gz" \
  ./caddy/pki/authorities/local/root.crt | sha256sum | cut -d ' ' -f 1)"
[[ "$root_ca_hash" == "$(cat "$imported/CA_SHA256")" ]]
python3 "$pilot/check_pilot_env.py" --env-file "$destination/env.pilot" >/dev/null
echo PILOT_ESCROW_RECOVERED_KEY_CA_AND_ENV_MATCH_NAS_DATA
echo "PILOT_ESCROW_RECOVERED_DIR=$destination"
echo PILOT_ESCROW_FROM_RETURNED_PACKAGE_VERIFIED
