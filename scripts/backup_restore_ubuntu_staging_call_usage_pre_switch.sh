#!/usr/bin/env bash
# Take a fresh paired snapshot of the unchanged fictional 2C site, then
# restore it to new isolated volumes before any call-usage page switch.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_CALL_USAGE_SNAPSHOT_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

suffix=14537acaacc6
candidate="$HOME/teacher-workbench-staging-call-usage-$suffix"
record="$HOME/teacher-workbench-staging-call-usage-pre-switch-$suffix"
backup_script="$HOME/backup_ubuntu_staging_phase2c_allowance_v3.sh"
restore_script="$HOME/restore_ubuntu_staging_phase2c_allowance.sh"
candidate_tag="teacher-workbench-staging-web:call-usage-$suffix"
old_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a
candidate_id=sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26

[[ ! -L "$candidate" && -d "$candidate" && "$(stat -c %a "$candidate")" == 700 ]]
for file in "$candidate/APP_IMAGE_ID" "$candidate/STATE"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]]
done
[[ "$(cat "$candidate/APP_IMAGE_ID")" == "$candidate_id" ]]
[[ "$(cat "$candidate/STATE")" == STAGING_CALL_USAGE_OFFLINE_IMAGE_COMPLETE ]]
[[ ! -e "$record" && ! -L "$record" ]] || {
  echo STAGING_CALL_USAGE_SNAPSHOT_RECORD_EXISTS
  exit 1
}

for item in \
  "2ccf1d8fe99d79107ad350717a2e9e2a31de8236b80887cd4cd310f83a86c531 $backup_script" \
  "a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d $restore_script"; do
  expected="${item%% *}"
  path="${item#* }"
  [[ ! -L "$path" && -f "$path" && "$(sha256sum "$path" | cut -d ' ' -f 1)" == "$expected" ]]
  bash -n "$path"
done
echo STAGING_CALL_USAGE_SNAPSHOT_SCRIPTS_VERIFIED

sudo -n -v || { echo STAGING_CALL_USAGE_SNAPSHOT_SUDO_AUTH_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$candidate_tag")" == "$candidate_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' teacher-workbench-staging-web-1)" == running ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_SNAPSHOT_OLD_LOGINS_HTTP_200')
PY
echo STAGING_CALL_USAGE_SNAPSHOT_PREFLIGHT_OK

mkdir -m 700 "$record"
set +e
bash "$backup_script" 2>&1 | tee "$record/backup.log"
backup_rc=${PIPESTATUS[0]}
set -e
[[ "$backup_rc" == 0 ]] || {
  echo STAGING_CALL_USAGE_FRESH_BACKUP_FAILED
  exit 1
}
grep -Fxq STAGING_2C_PAIRED_FILES_VERIFIED "$record/backup.log"
mapfile -t backup_lines < <(grep '^STAGING_2C_BACKUP_DIR=' "$record/backup.log")
[[ "${#backup_lines[@]}" == 1 ]]
backup="${backup_lines[0]#STAGING_2C_BACKUP_DIR=}"
[[ "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-[A-Za-z0-9]{8}$ ]]
echo STAGING_CALL_USAGE_FRESH_BACKUP_VERIFIED

set +e
bash "$restore_script" "$backup" 2>&1 | tee "$record/restore.log"
restore_rc=${PIPESTATUS[0]}
set -e
[[ "$restore_rc" == 0 ]] || {
  echo STAGING_CALL_USAGE_FRESH_RESTORE_FAILED
  exit 1
}
grep -Fxq STAGING_2C_INDEPENDENT_RESTORE_VERIFIED "$record/restore.log"
mapfile -t restore_lines < <(grep '^STAGING_2C_RESTORE_DIR=' "$record/restore.log")
[[ "${#restore_lines[@]}" == 1 ]]
restore="${restore_lines[0]#STAGING_2C_RESTORE_DIR=}"
[[ "$restore" =~ ^/home/huahua/teacher-workbench-staging-phase2c-allowance-restore-[A-Za-z0-9]{8}$ ]]
echo STAGING_CALL_USAGE_FRESH_RESTORE_VERIFIED

[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_id" ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_ONLINE_LOGINS_AFTER_RESTORE_HTTP_200')
PY
printf '%s\n' "$backup" > "$record/BACKUP_DIR"
printf '%s\n' "$restore" > "$record/RESTORE_DIR"
printf 'STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_COMPLETE\n' > "$record/STATE"
echo "STAGING_CALL_USAGE_FRESH_BACKUP_DIR=$backup"
echo "STAGING_CALL_USAGE_FRESH_RESTORE_DIR=$restore"
echo "STAGING_CALL_USAGE_PRE_SWITCH_RECORD_DIR=$record"
echo STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_OK
