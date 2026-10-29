#!/usr/bin/env bash
# Read-only diagnostic for the pre-sudo checks in the 2C allowance backup.
set -uo pipefail

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_BACKUP_DIAG_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage="$HOME/teacher-workbench-staging-phase2c-20261022"
old="$HOME/teacher-workbench-staging-phase2b-20261020"
build="$HOME/teacher-workbench-staging-phase2c-migration-F6yZnxfi"
source_root="$build/src"
keyring="$HOME/teacher-workbench-staging-model-keyring"
compose="$stage/compose.staging.yaml"
failed=0

report() {
  local label="$1" result="$2"
  echo "$label=$result"
  [[ "$result" == OK ]] || failed=1
}

check_dir() {
  local label="$1" path="$2"
  if [[ ! -L "$path" && -d "$path" && "$(stat -c %a "$path" 2>/dev/null)" == 700 ]]; then
    report "$label" OK
  else
    report "$label" FAIL
  fi
}

check_file() {
  local label="$1" path="$2"
  if [[ ! -L "$path" && -f "$path" && "$(stat -c %a "$path" 2>/dev/null)" == 600 ]]; then
    report "$label" OK
  else
    report "$label" FAIL
  fi
}

check_line() {
  local label="$1" expected="$2"
  if grep -Fxq "$expected" "$compose" 2>/dev/null; then
    report "$label" OK
  else
    report "$label" FAIL
  fi
}

check_dir STAGING_2C_DIAG_CONFIG_DIR "$stage"
check_dir STAGING_2C_DIAG_OLD_SOURCE_DIR "$old"
check_dir STAGING_2C_DIAG_BUILD_DIR "$build"
check_dir STAGING_2C_DIAG_BUILD_SOURCE_DIR "$source_root"
check_dir STAGING_2C_DIAG_KEYRING_DIR "$keyring"

check_file STAGING_2C_DIAG_ENV_FILE "$stage/.env.staging"
check_file STAGING_2C_DIAG_COMPOSE_FILE "$compose"
check_file STAGING_2C_DIAG_NGINX_FILE "$stage/config/nginx-staging.conf"
check_file STAGING_2C_DIAG_CONFIG_IMAGE_ID "$stage/APP_IMAGE_ID"
check_file STAGING_2C_DIAG_CONFIG_STATE_FILE "$stage/STATE"
check_file STAGING_2C_DIAG_BUILD_IMAGE_ID "$build/APP_IMAGE_ID"
check_file STAGING_2C_DIAG_BUILD_STATE_FILE "$build/IMAGE_BUILD_STATE"
check_file STAGING_2C_DIAG_SOURCE_MANIFEST "$build/SOURCE_SHA256SUMS"
check_file STAGING_2C_DIAG_OVERLAY_DOCKERFILE "$source_root/Dockerfile.phase2c-overlay"
check_file STAGING_2C_DIAG_KEY_FILE "$keyring/v1.key"

check_line STAGING_2C_DIAG_COMPOSE_NAME 'name: teacher-workbench-staging'
check_line STAGING_2C_DIAG_COMPOSE_PORT '      - "127.0.0.1:18002:8080"'
check_line STAGING_2C_DIAG_COMPOSE_IMAGE '    image: teacher-workbench-staging-web:member-quota-20261022'
check_line STAGING_2C_DIAG_AI_ENABLED_OFF '      AI_ENABLED: "0"'
check_line STAGING_2C_DIAG_AI_KEY_EMPTY '      AI_API_KEY: ""'
check_line STAGING_2C_DIAG_LOCAL_QUEUE_OFF '      AI_LOCAL_QUEUE: "0"'
check_line STAGING_2C_DIAG_MANUAL_QUEUE_ON '      AI_STAGING_MANUAL_QUEUE: "1"'
check_line STAGING_2C_DIAG_MEMBER_TASKS_OFF '      AI_MEMBER_TASKS_ENABLED: "0"'
check_line STAGING_2C_DIAG_KEYRING_SETTING '      MODEL_KEYRING_DIR: /run/model-keyring'
check_line STAGING_2C_DIAG_KEYRING_MOUNT '      - /home/huahua/teacher-workbench-staging-model-keyring:/run/model-keyring:ro'

if [[ ! -L "$old/scripts/check_staging_env.py" && -f "$old/scripts/check_staging_env.py" &&
      ! -L "$old/scripts/check_test_env.py" && -f "$old/scripts/check_test_env.py" ]]; then
  report STAGING_2C_DIAG_ENV_CHECKER OK
else
  report STAGING_2C_DIAG_ENV_CHECKER FAIL
fi

if [[ "$(cat "$stage/STATE" 2>/dev/null)" == STAGING_2C_CONFIG_PREPARED ]]; then
  report STAGING_2C_DIAG_CONFIG_STATE OK
else
  report STAGING_2C_DIAG_CONFIG_STATE FAIL
fi
if [[ "$(cat "$build/IMAGE_BUILD_STATE" 2>/dev/null)" == STAGING_2C_OFFLINE_IMAGE_COMPLETE ]]; then
  report STAGING_2C_DIAG_BUILD_STATE OK
else
  report STAGING_2C_DIAG_BUILD_STATE FAIL
fi
if cmp -s "$stage/APP_IMAGE_ID" "$build/APP_IMAGE_ID"; then
  report STAGING_2C_DIAG_IMAGE_ID_MATCH OK
else
  report STAGING_2C_DIAG_IMAGE_ID_MATCH FAIL
fi
if python3 "$old/scripts/check_staging_env.py" --env-file "$stage/.env.staging" >/dev/null 2>&1; then
  report STAGING_2C_DIAG_ENV_VALID OK
else
  report STAGING_2C_DIAG_ENV_VALID FAIL
fi
if (cd "$source_root" && sha256sum -c ../SOURCE_SHA256SUMS >/dev/null 2>&1); then
  report STAGING_2C_DIAG_SOURCE_CHECKSUMS OK
else
  report STAGING_2C_DIAG_SOURCE_CHECKSUMS FAIL
fi

echo STAGING_2C_BACKUP_PREFLIGHT_DIAG_DONE
exit "$failed"
