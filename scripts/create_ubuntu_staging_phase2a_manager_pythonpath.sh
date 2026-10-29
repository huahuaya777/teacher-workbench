#!/usr/bin/env bash
# Create only a fictional manager in the isolated staging stack, without Compose CLI.
# The script entry point lives under /app/scripts; expose /app for config imports.
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
if ps -u huahua -o args= | grep -Fqx 'bash /home/huahua/create_ubuntu_staging_phase2a_manager.sh'; then
  echo "STAGING_PHASE2A_OLD_MANAGER_SCRIPT_STILL_RUNNING"
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
echo "STAGING_PHASE2A_DIRECT_LOCAL_PREFLIGHT_OK"

sudo -v
port="$(timeout 30s sudo -n docker port teacher-workbench-staging-gateway-1 8080/tcp)"
if [[ "$port" != '127.0.0.1:18002' ]]; then
  echo "STAGING_PHASE2A_GATEWAY_UNEXPECTED"
  exit 1
fi
web_image="$(timeout 30s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)"
tag_image="$(timeout 30s sudo -n docker image inspect -f '{{.Id}}' teacher-workbench-staging-web:accounts-20261018)"
if [[ "$web_image" != "$tag_image" ]]; then
  echo "STAGING_PHASE2A_WEB_IMAGE_UNEXPECTED"
  exit 1
fi
for container in teacher-workbench-staging-db-1 teacher-workbench-staging-redis-1 \
                 teacher-workbench-staging-web-1 teacher-workbench-staging-gateway-1; do
  if [[ "$(timeout 30s sudo -n docker inspect -f '{{.State.Status}}' "$container")" != running ]]; then
    echo "STAGING_PHASE2A_SERVICE_NOT_RUNNING: $container"
    exit 1
  fi
done
if ! timeout 60s sudo -n docker exec teacher-workbench-staging-web-1 \
    python manage.py showmigrations workbench | grep -Fq '[X] 0004_memberaccess_memberaudit'; then
  echo "STAGING_PHASE2A_MIGRATION_NOT_READY"
  exit 1
fi
count="$(timeout 30s sudo -n docker exec teacher-workbench-staging-db-1 \
  psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc \
  "SELECT COUNT(*) FROM auth_user WHERE username = 'staging_manager_20261018'")"
if [[ "$count" != 0 ]]; then
  echo "STAGING_PHASE2A_MANAGER_ACCOUNT_NOT_EMPTY"
  exit 1
fi
echo "STAGING_PHASE2A_MANAGER_DIRECT_PREFLIGHT_OK"

sudo -n docker exec -it -e PYTHONPATH=/app teacher-workbench-staging-web-1 \
  python scripts/prepare_ubuntu_staging_phase2a_manager.py --confirm-staging-manager
