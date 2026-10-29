#!/usr/bin/env bash
# Encrypt the fixed pilot escrow for offline custody. No network in crypto container.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 || ! -t 0 ]]; then
  echo PILOT_ESCROW_EXPORT_WRONG_HOST_USER_OR_TERMINAL
  exit 1
fi

source_dir="$HOME/teacher-workbench-pilot-key-escrow/escrow-Lx7aqLEz"
imported="$HOME/teacher-workbench-nas-import-pilot-manager-data-Lx7aqLEz-9037d08db8d9"
pilot="$HOME/teacher-workbench-pilot"
helper="$HOME/offline_pilot_escrow_package.py"
root="$HOME/teacher-workbench-pilot-offline-escrow-packages"

for directory in "$source_dir" "$imported" "$pilot"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]]
done
for file in "$source_dir/env.pilot" "$source_dir/v1.key" \
            "$source_dir/caddy_data.tar.gz" "$source_dir/caddy_config.tar.gz" \
            "$source_dir/SHA256SUMS" "$source_dir/STATE" "$helper"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]]
done
[[ "$(cat "$source_dir/STATE")" == PILOT_ESCROW_COMPLETE ]]
[[ "$(cat "$imported/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(cat "$imported/NAS_TRANSFER_STATE")" == NAS_TRANSFER_COMPLETE ]]
[[ "$(cat "$pilot/STATE")" == PILOT_STARTED_AI_OFF ]]
(cd "$source_dir" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$imported" && sha256sum -c SHA256SUMS >/dev/null && sha256sum -c NAS_SHA256SUMS >/dev/null)
[[ "$(sha256sum "$source_dir/v1.key" | cut -d ' ' -f 1)" == "$(cat "$imported/KEY_SHA256")" ]]
escrow_ca_hash="$(tar -xOzf "$source_dir/caddy_data.tar.gz" \
  ./caddy/pki/authorities/local/root.crt | sha256sum | cut -d ' ' -f 1)"
[[ "$escrow_ca_hash" == "$(cat "$imported/CA_SHA256")" ]]
[[ "$(sha256sum "$pilot/pilot-root-ca.crt" | cut -d ' ' -f 1)" == "$escrow_ca_hash" ]]
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == 94d3f83d3f07b2cf222a9f3252242706c3cf67231a822989b82081419af50dfd ]]
echo PILOT_ESCROW_EXPORT_FIXED_SOURCE_AND_NAS_DATA_VERIFIED

sudo -v
image="$(head -n 1 "$imported/IMAGE_IDS")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-pilot-web-1)" == "$image" ]]
timeout 15s sudo -n docker image inspect "$image" >/dev/null

[[ ! -L "$root" ]]
mkdir -m 700 -p "$root"
[[ "$(stat -c %a "$root")" == 700 ]]
package_dir="$(mktemp -d "$root/package-XXXXXXXX")"
[[ ! -L "$package_dir" && "$(stat -c %a "$package_dir")" == 700 ]]
echo PILOT_ESCROW_EXPORT_ISOLATED_PREFLIGHT_OK
echo '请只在当前可见终端设置至少 20 字符的离线解锁口令；不要发到聊天或写入命令。'

timeout 900s sudo -n docker run --pull never --rm -it --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$source_dir:/input:ro" -v "$package_dir:/output:rw" \
  -v "$helper:/app/offline_pilot_escrow_package.py:ro" \
  "$image" python /app/offline_pilot_escrow_package.py export \
  /input /output/teacher-workbench-pilot-escrow-Lx7aqLEz.json

package="$package_dir/teacher-workbench-pilot-escrow-Lx7aqLEz.json"
[[ ! -L "$package" && -f "$package" && "$(stat -c %a "$package")" == 600 ]]
python3 - "$package" <<'PY'
import json
from pathlib import Path
import sys
payload = json.loads(Path(sys.argv[1]).read_text(encoding='ascii'))
assert set(payload) == {'format', 'kdf', 'salt', 'nonce', 'ciphertext'}
assert payload['format'] == 'teacher-workbench-pilot-escrow-Lx7aqLEz-v1'
print('PILOT_ESCROW_PACKAGE_STRUCTURE_ENCRYPTED_ONLY')
PY
echo "PILOT_ESCROW_PACKAGE_PATH=$package"
echo "PILOT_ESCROW_PACKAGE_SHA256=$(sha256sum "$package" | cut -d ' ' -f 1)"
echo PILOT_ESCROW_ENCRYPTED_EXPORT_READY
