#!/usr/bin/env bash
# Snapshot the fictional post-fix staging site, then restore to new isolated
# volumes. This script never changes the old test site or production.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_ERRORS_RECOVERY_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage="$HOME/teacher-workbench-staging-errors-20261022"
backup_script="$HOME/backup_ubuntu_staging_errors.sh"
restore_script="$HOME/restore_ubuntu_staging_errors.sh"
record="$HOME/teacher-workbench-staging-errors-recovery-20261022"
image=teacher-workbench-staging-web:generic-errors-20261022
web=teacher-workbench-staging-web-1

[[ ! -L "$stage" && -d "$stage" && "$(stat -c %a "$stage")" == 700 ]]
for file in "$stage/APP_IMAGE_ID" "$stage/STATE"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]]
done
[[ "$(cat "$stage/STATE")" == STAGING_ERRORS_ONLINE_SWITCH_COMPLETE ]]
[[ ! -e "$record" && ! -L "$record" ]] || {
  echo STAGING_ERRORS_RECOVERY_RECORD_EXISTS
  exit 1
}
[[ "$(sha256sum "$backup_script" | cut -d ' ' -f 1)" == 17706c1caaa32807079ed22df19a5c4b9801719f1659a2aae022099a07e88c6f ]]
[[ "$(sha256sum "$restore_script" | cut -d ' ' -f 1)" == c10b5f255a7563ff957b492bd6423776f525040c3ee031c23e43abc42027a60f ]]
bash -n "$backup_script"
bash -n "$restore_script"
echo STAGING_ERRORS_RECOVERY_SCRIPTS_VERIFIED

sudo -n -v || { echo STAGING_ERRORS_RECOVERY_SUDO_REQUIRED; exit 1; }
image_id="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$image")"
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(cat "$stage/APP_IMAGE_ID")" == "$image_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$image_id" ]]
for name in "$web" teacher-workbench-staging-gateway-1 \
            teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$name")" == running ]]
done
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_ERRORS_RECOVERY_OLD_LOGINS_HTTP_200')
PY
echo STAGING_ERRORS_RECOVERY_PREFLIGHT_OK

mkdir -m 700 "$record"
if ! bash "$backup_script" 2>&1 | tee "$record/backup.log"; then
  echo STAGING_ERRORS_RECOVERY_BACKUP_FAILED
  exit 1
fi
grep -Fxq STAGING_ERRORS_PAIRED_FILES_VERIFIED "$record/backup.log"
[[ "$(grep -c '^STAGING_ERRORS_BACKUP_DIR=' "$record/backup.log")" == 1 ]]
backup="$(grep '^STAGING_ERRORS_BACKUP_DIR=' "$record/backup.log" | cut -d= -f2)"
[[ "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-staging-errors-[A-Za-z0-9]{8}$ ]]
echo STAGING_ERRORS_RECOVERY_FRESH_BACKUP_VERIFIED

if ! bash "$restore_script" "$backup" 2>&1 | tee "$record/restore.log"; then
  echo STAGING_ERRORS_RECOVERY_RESTORE_FAILED
  exit 1
fi
grep -Fxq STAGING_ERRORS_INDEPENDENT_RESTORE_VERIFIED "$record/restore.log"
[[ "$(grep -c '^STAGING_ERRORS_RESTORE_DIR=' "$record/restore.log")" == 1 ]]
restore="$(grep '^STAGING_ERRORS_RESTORE_DIR=' "$record/restore.log" | cut -d= -f2)"
[[ "$restore" =~ ^/home/huahua/tw-errors-restore-[A-Za-z0-9]{8}$ ]]
echo STAGING_ERRORS_RECOVERY_FRESH_RESTORE_VERIFIED

[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$web")" == "$image_id" ]]
python3 - <<'PY'
from urllib.error import HTTPError
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
try:
    opener.open('http://127.0.0.1:18002/staging-error-page-check-nonexistent/', timeout=5)
except HTTPError as error:
    assert error.code == 404 and b'Using the URLconf' not in error.read()
else:
    raise AssertionError('expected a generic 404')
print('STAGING_ERRORS_RECOVERY_ONLINE_LOGINS_AND_404_OK')
PY
printf '%s\n' "$backup" > "$record/BACKUP_DIR"
printf '%s\n' "$restore" > "$record/RESTORE_DIR"
printf 'STAGING_ERRORS_RECOVERY_COMPLETE\n' > "$record/STATE"
echo "STAGING_ERRORS_RECOVERY_BACKUP_DIR=$backup"
echo "STAGING_ERRORS_RECOVERY_RESTORE_DIR=$restore"
echo "STAGING_ERRORS_RECOVERY_RECORD_DIR=$record"
echo STAGING_ERRORS_RECOVERY_BACKUP_AND_RESTORE_OK
