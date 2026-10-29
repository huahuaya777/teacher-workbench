#!/usr/bin/env bash
# Exercise the package code in the pinned pilot image with fictional bytes only.
set -euo pipefail
if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_ESCROW_FICTIONAL_WRONG_HOST_USER_OR_ARGS
  exit 1
fi
helper="$HOME/offline_pilot_escrow_package.py"
tests="$HOME/test_offline_pilot_escrow_package.py"
imported="$HOME/teacher-workbench-nas-import-pilot-manager-data-Lx7aqLEz-9037d08db8d9"
[[ ! -L "$helper" && -f "$helper" && "$(stat -c %a "$helper")" == 600 ]]
[[ ! -L "$tests" && -f "$tests" && "$(stat -c %a "$tests")" == 600 ]]
[[ ! -L "$imported" && -d "$imported" && "$(cat "$imported/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(sha256sum "$helper" | cut -d ' ' -f 1)" == 94d3f83d3f07b2cf222a9f3252242706c3cf67231a822989b82081419af50dfd ]]
image="$(head -n 1 "$imported/IMAGE_IDS")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
sudo -v
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-pilot-web-1)" == "$image" ]]
echo PILOT_ESCROW_FICTIONAL_IMAGE_AND_SOURCE_OK
timeout 90s sudo -n docker run --pull never --rm --network none \
  --user "$(id -u):$(id -g)" --read-only --cap-drop ALL \
  --security-opt no-new-privileges -e PYTHONDONTWRITEBYTECODE=1 \
  -v "$helper:/app/offline_pilot_escrow_package.py:ro" \
  -v "$tests:/app/test_offline_pilot_escrow_package.py:ro" \
  "$image" python /app/test_offline_pilot_escrow_package.py
echo PILOT_ESCROW_FICTIONAL_CRYPTO_IN_PINNED_IMAGE_OK
