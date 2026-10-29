#!/usr/bin/env bash
# Take a fresh 2A staging snapshot and independently restore it before the
# 2B online switch. Keeps both sites on the old image and leaves all volumes.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_PHASE2B_SWITCH_SNAPSHOT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

backup_script="$HOME/backup_ubuntu_staging_phase2b_pre.sh"
restore_script="$HOME/restore_ubuntu_staging_phase2b_pre.sh"
backup_root="$HOME/teacher-workbench-staging-backups"
for file in "$backup_script" "$restore_script"; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    echo STAGING_PHASE2B_SWITCH_SNAPSHOT_SCRIPT_MISSING_OR_LINK
    exit 1
  fi
done
[[ "$(sha256sum "$backup_script" | cut -d ' ' -f 1)" == 60b6007bb5537a9b2cafbf31a5cd300abf3735b64ea8a681eafb89426adaa074 ]]
[[ "$(sha256sum "$restore_script" | cut -d ' ' -f 1)" == 999ad7fcd58b0c073ab40441bb03d51c8e1bef4ffc058cb4f4713ec830abb87c ]]
if [[ -L "$backup_root" || ! -d "$backup_root" || "$(stat -c %a "$backup_root")" != 700 ]]; then
  echo STAGING_PHASE2B_SWITCH_SNAPSHOT_ROOT_UNSAFE
  exit 1
fi
if [[ ! -d "$HOME/teacher-workbench-staging-model-keyring" ||
      ! -d "$HOME/teacher-workbench-staging-phase2b-fictional-recovery-lESMk1Nj" ]]; then
  echo STAGING_PHASE2B_SWITCH_SNAPSHOT_KEY_REHEARSAL_MISSING
  exit 1
fi
echo STAGING_PHASE2B_FRESH_SNAPSHOT_PREPARED

log="$(mktemp "$backup_root/.phase2b-switch-snapshot-XXXXXXXX.log")"
bash "$backup_script" 2>&1 | tee "$log"
mapfile -t paths < <(grep '^STAGING_PHASE2B_PRE_BACKUP_DIR=' "$log")
if [[ "${#paths[@]}" != 1 ]]; then
  echo STAGING_PHASE2B_FRESH_BACKUP_PATH_AMBIGUOUS
  exit 1
fi
backup="${paths[0]#STAGING_PHASE2B_PRE_BACKUP_DIR=}"
if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-([A-Za-z0-9]{8})$ ]]; then
  echo STAGING_PHASE2B_FRESH_BACKUP_PATH_UNSAFE
  exit 1
fi
suffix="${BASH_REMATCH[1]}"
if [[ "$suffix" == lESMk1Nj ]]; then
  echo STAGING_PHASE2B_FRESH_BACKUP_NOT_FRESH
  exit 1
fi
echo STAGING_PHASE2B_FRESH_BACKUP_VERIFIED
bash "$restore_script" "$backup"
echo STAGING_PHASE2B_FRESH_PRE_SWITCH_BACKUP_AND_RESTORE_OK
echo "STAGING_PHASE2B_FRESH_BACKUP_DIR=$backup"
echo "STAGING_PHASE2B_FRESH_RESTORE_DIR=$HOME/teacher-workbench-staging-phase2b-pre-restore-$suffix"
