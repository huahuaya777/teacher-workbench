#!/usr/bin/env bash
# Update only the isolated staging web/gateway from a reviewed offline bundle.
# Keep the old source/image and all volumes; rollback web/gateway on failure.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
old="$HOME/teacher-workbench-staging-74586f82"
new="$HOME/teacher-workbench-staging-1d3ed18b"
archive="$HOME/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
backup="$HOME/teacher-workbench-staging-backups/backup-cxi7XtWw"
helper="$HOME/verify_staging_fictional_snapshot.py"
expected_archive="1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb"
expected_helper="ce5c3baba4155d67621e7a18a820e25c9835f8da2ae662c5b6d8afecc8ee0ea6"

if [[ -e "$new" || -L "$new" || -L "$old" || ! -d "$old" || "$(stat -c %a "$old")" != 700 ]]; then
  echo "STAGING_UPDATE_SOURCE_OR_TARGET_UNSAFE"
  exit 1
fi
if [[ -L "$archive" || ! -f "$archive" || "$(sha256sum "$archive" | cut -d ' ' -f 1)" != "$expected_archive" ]]; then
  echo "STAGING_UPDATE_ARCHIVE_HASH_MISMATCH"
  exit 1
fi
if [[ -L "$helper" || ! -f "$helper" || "$(sha256sum "$helper" | cut -d ' ' -f 1)" != "$expected_helper" ]]; then
  echo "STAGING_UPDATE_HELPER_HASH_MISMATCH"
  exit 1
fi
if [[ -L "$backup" || ! -d "$backup" || "$(stat -c %a "$backup")" != 700 || "$(cat "$backup/STATE")" != STAGING_BACKUP_COMPLETE ]]; then
  echo "STAGING_UPDATE_BACKUP_UNSAFE"
  exit 1
fi
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
echo "STAGING_UPDATE_BACKUP_VERIFIED"

cd "$old"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '      - "127.0.0.1:18002:8080"' compose.staging.yaml
grep -Fq 'proxy_set_header Host $http_host;' config/nginx-staging.conf
test "$(stat -c %a .env.staging)" = 600
python3 scripts/check_staging_env.py --env-file .env.staging >/dev/null
sudo -v
old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
services="$("${old_compose[@]}" ps --status running --services)"
for service in db redis web gateway; do
  if ! grep -Fxq "$service" <<< "$services"; then
    echo "STAGING_UPDATE_SOURCE_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
test "$("${old_compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
for volume in teacher-workbench-staging_staging_db teacher-workbench-staging_staging_private; do
  sudo -n docker volume inspect "$volume" >/dev/null
done
source_image="$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)"
test "$source_image" = "$(cat "$backup/APP_IMAGE_ID")"
timeout 60s "${old_compose[@]}" exec -T web python - < "$helper"
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_UPDATE_SOURCE_LOGIN_FAILED")
print("STAGING_UPDATE_SOURCE_HTTP_200")
PY
echo "STAGING_UPDATE_ISOLATION_PREFLIGHT_OK"

mkdir -m 700 "$new"
tar -xzf "$archive" -C "$new"
install -m 600 "$old/.env.staging" "$new/.env.staging"
grep -Fxq 'name: teacher-workbench-staging' "$new/compose.staging.yaml"
grep -Fxq '    image: teacher-workbench-staging-web:manual-queue-20261017' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
python3 "$new/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
"${new_compose[@]}" config --quiet
echo "STAGING_UPDATE_NEW_CONFIG_READY"
"${new_compose[@]}" build web
echo "STAGING_UPDATE_NEW_IMAGE_READY"

switched=1
rollback_if_needed() {
  if [[ "$switched" == 1 ]]; then
    if timeout 120s "${old_compose[@]}" up -d --no-deps --force-recreate web gateway >/dev/null; then
      echo "STAGING_UPDATE_FAILED_OLD_WEB_GATEWAY_RESTORED" >&2
    else
      echo "STAGING_UPDATE_ROLLBACK_FAILED_REVIEW_REQUIRED" >&2
    fi
  fi
}
trap rollback_if_needed EXIT
timeout 120s "${new_compose[@]}" up -d --no-deps --force-recreate web gateway
ready=0
for _ in {1..30}; do
  if python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
try:
    with build_opener(ProxyHandler({})).open("http://127.0.0.1:18002/login/", timeout=3) as response:
        assert response.status == 200
except Exception:
    raise SystemExit(1)
PY
  then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != 1 ]]; then
  echo "STAGING_UPDATE_NEW_LOGIN_NOT_READY"
  exit 1
fi
timeout 30s "${new_compose[@]}" exec -T web python - <<'PY'
import os
from django.conf import settings
from workbench.ai import configured
assert settings.AI_STAGING_MANUAL_QUEUE
assert not settings.AI_ENABLED and not settings.AI_API_KEY
assert not configured()
assert settings.DATABASES["default"]["NAME"] == "teacher_workbench_staging"
print("STAGING_MANUAL_QUEUE_AI_OFF_VERIFIED")
PY
timeout 30s "${new_compose[@]}" exec -T web python manage.py check >/dev/null
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_UPDATE_LOGIN_NOT_READY")
print("STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_UPDATE")
PY
switched=0
echo "STAGING_MANUAL_QUEUE_DEPLOYED_AI_OFF"
echo "STAGING_NEW_DIR=$new"
