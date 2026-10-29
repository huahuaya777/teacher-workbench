#!/usr/bin/env bash
# Interactive fictional manager creation, only after the isolated 2A deployment.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" || "$HOME" != "/home/huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 0 || ! -t 0 ]]; then
  echo "STAGING_PHASE2A_INTERACTIVE_TERMINAL_REQUIRED"
  exit 1
fi
stage="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
if [[ -L "$stage" || ! -d "$stage" || "$(stat -c %a "$stage")" != 700 || \
      -L "$stage/.env.staging" || ! -f "$stage/.env.staging" || \
      "$(stat -c %a "$stage/.env.staging")" != 600 ]]; then
  echo "STAGING_PHASE2A_MANAGER_STAGE_UNSAFE"
  exit 1
fi
cd "$stage"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '    image: teacher-workbench-staging-web:accounts-20261018' compose.staging.yaml
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' compose.staging.yaml
python3 scripts/check_staging_env.py --env-file .env.staging >/dev/null
sudo -v
compose=(sudo -n docker compose --env-file .env.staging -f compose.staging.yaml)
test "$("${compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
test "$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" = \
  "$(sudo -n docker image inspect -f '{{.Id}}' teacher-workbench-staging-web:accounts-20261018)"
"${compose[@]}" exec -T web python manage.py showmigrations workbench | grep -Fq '[X] 0004_memberaccess_memberaudit'
echo "STAGING_PHASE2A_MANAGER_PREFLIGHT_OK"
"${compose[@]}" exec web python scripts/prepare_ubuntu_staging_phase2a_manager.py --confirm-staging-manager
