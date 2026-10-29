#!/usr/bin/env bash
# Read-only check after an interrupted fictional staging manager creation.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" || "$HOME" != "/home/huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 0 ]]; then
  echo "USAGE: check_ubuntu_staging_phase2a_manager_readonly.sh"
  exit 1
fi

sudo -v
count="$(timeout 30s sudo -n docker exec teacher-workbench-staging-db-1 \
  psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc \
  "SELECT COUNT(*) FROM auth_user WHERE username = 'staging_manager_20261018'")"
if [[ "$count" != 0 && "$count" != 1 ]]; then
  echo "STAGING_PHASE2A_MANAGER_COUNT_UNEXPECTED"
  exit 1
fi
printf 'STAGING_PHASE2A_MANAGER_COUNT=%s\n' "$count"
