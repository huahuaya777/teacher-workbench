#!/usr/bin/env bash
# Make a fresh paired 2B snapshot and independently restore it before 2C.
# Does not switch the online image or migrate its database.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_SNAPSHOT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

preflight="$HOME/check_ubuntu_staging_phase2c_config_readonly.sh"
backup_script="$HOME/backup_ubuntu_staging_phase2b_credentials_v2.sh"
restore_script="$HOME/restore_ubuntu_staging_phase2b_credentials.sh"
root="$HOME/teacher-workbench-staging-backups"
for file in "$preflight" "$backup_script" "$restore_script"; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    echo STAGING_2C_SNAPSHOT_SCRIPT_MISSING_OR_LINK
    exit 1
  fi
done
for item in \
  "$preflight:92b6c91a914de58540a71c4a9fa807048edcba45f189a7e24646b655b32291e9" \
  "$backup_script:15f1a05afb3a11af649f85bdac99d27968687af88780b336d059b4fe8e9e39c5" \
  "$restore_script:a0a3e402d736dfa4dbbb37d965ed4b88180092c6d94ae70e311a5ba7104a3e22"; do
  file="${item%:*}"
  expected="${item##*:}"
  if [[ "$(sha256sum "$file" | cut -d ' ' -f 1)" != "$expected" ]]; then
    echo "STAGING_2C_SNAPSHOT_DEPENDENCY_HASH_MISMATCH file=$(basename "$file")"
    exit 1
  fi
done
echo STAGING_2C_SNAPSHOT_DEPENDENCIES_VERIFIED
if [[ -L "$root" || ! -d "$root" || "$(stat -c %a "$root")" != 700 ]]; then
  echo STAGING_2C_SNAPSHOT_BACKUP_ROOT_UNSAFE
  exit 1
fi
sudo -n -v || { echo STAGING_2C_SNAPSHOT_SUDO_REQUIRED; exit 1; }

bash "$preflight"
echo STAGING_2C_SNAPSHOT_PREFLIGHT_OK

log="$(mktemp "$root/.phase2c-switch-snapshot-XXXXXXXX.log")"
bash "$backup_script" 2>&1 | tee "$log"
mapfile -t paths < <(grep '^STAGING_2B_BACKUP_DIR=' "$log")
if [[ "${#paths[@]}" != 1 ]]; then
  echo STAGING_2C_SNAPSHOT_BACKUP_PATH_AMBIGUOUS
  exit 1
fi
backup="${paths[0]#STAGING_2B_BACKUP_DIR=}"
if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-([A-Za-z0-9]{8})$ ]]; then
  echo STAGING_2C_SNAPSHOT_BACKUP_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
[[ "$suffix" != F6yZnxfi ]] || { echo STAGING_2C_SNAPSHOT_NOT_FRESH; exit 1; }
[[ "$(grep -Fxc STAGING_2B_PAIRED_FILES_VERIFIED "$log")" == 1 ]]
echo STAGING_2C_SNAPSHOT_NEW_BACKUP_VERIFIED

restore_log="$(mktemp "$root/.phase2c-switch-restore-XXXXXXXX.log")"
bash "$restore_script" "$backup" 2>&1 | tee "$restore_log"
[[ "$(grep -Fxc STAGING_2B_INDEPENDENT_RESTORE_VERIFIED "$restore_log")" == 1 ]]
expected_restore="$HOME/teacher-workbench-staging-phase2b-keys-restore-$suffix"
[[ "$(grep -Fxc "STAGING_2B_RESTORE_DIR=$expected_restore" "$restore_log")" == 1 ]]

echo STAGING_2C_FRESH_2B_BACKUP_RESTORE_OK
echo "STAGING_2C_FRESH_BACKUP_DIR=$backup"
echo "STAGING_2C_FRESH_RESTORE_DIR=$expected_restore"
