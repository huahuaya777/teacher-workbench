#!/usr/bin/env bash
# Upgrade only the isolated staging web after a fresh paired backup and restore.
# Keep the old source/image and every volume; no paid model call or NAS write.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" || "$HOME" != "/home/huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 1 ]]; then
  echo "USAGE: apply_ubuntu_staging_phase2a.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-XXXXXXXX"
  exit 1
fi

old="$HOME/teacher-workbench-staging-linebreak-7198283e"
new="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
backup_root="$HOME/teacher-workbench-staging-backups"
backup="$1"
restore="$HOME/teacher-workbench-staging-phase2a-pre-restore-20261018"
source_archive="$backup/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
linebreak_archive="$backup/teacher-workbench-staging-linebreak-fix-7198283e.tar.gz"
accounts_archive="$HOME/teacher-workbench-staging-phase2a-1bf5a500.tar.gz"
helper="$HOME/verify_staging_phase2a_pre_snapshot.py"
old_tag="teacher-workbench-staging-web:linebreak-20261017"
new_tag="teacher-workbench-staging-web:accounts-20261018"
prefix="teacher-workbench-staging-phase2a-pre-restore-20261018"
restore_db="$prefix-db"
restore_redis="$prefix-redis"
restore_network="$prefix-net"
restore_private="$prefix-private"

if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-[A-Za-z0-9]{8}$ || \
      -L "$backup_root" || -L "$backup" || ! -d "$backup" || \
      "$(stat -c %a "$backup_root")" != 700 || "$(stat -c %a "$backup")" != 700 || \
      "$(cat "$backup/STATE")" != STAGING_PHASE2A_PRE_BACKUP_COMPLETE ]]; then
  echo "STAGING_PHASE2A_BACKUP_UNSAFE"
  exit 1
fi
if [[ -L "$old" || ! -d "$old" || "$(stat -c %a "$old")" != 700 || \
      -e "$new" || -L "$new" || -L "$restore" || ! -d "$restore" || \
      "$(stat -c %a "$restore")" != 700 ]]; then
  echo "STAGING_PHASE2A_SOURCE_OR_TARGET_UNSAFE"
  exit 1
fi
for file in "$source_archive" "$linebreak_archive" "$accounts_archive" "$helper" "$restore/.env.staging"; do
  if [[ -L "$file" || ! -f "$file" ]]; then
    echo "STAGING_PHASE2A_INPUT_MISSING_OR_SYMLINK"
    exit 1
  fi
done
if [[ "$(sha256sum "$source_archive" | cut -d ' ' -f 1)" != 1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb || \
      "$(sha256sum "$linebreak_archive" | cut -d ' ' -f 1)" != 7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d || \
      "$(sha256sum "$accounts_archive" | cut -d ' ' -f 1)" != 1bf5a500892ffc51233add592cc8230e5ae394472f868783fa3d01f71e0f8082 || \
      "$(sha256sum "$helper" | cut -d ' ' -f 1)" != 4a4991c504f27717c8c34bdd0863fca8013b7511d1e04d91ff607de8cda8db49 ]]; then
  echo "STAGING_PHASE2A_INPUT_HASH_MISMATCH"
  exit 1
fi
for file in db.dump private.tar.gz SHA256SUMS SOURCE_SHA256SUMS APP_IMAGE_ID STATE; do
  if [[ -L "$backup/$file" || ! -f "$backup/$file" || "$(stat -c %a "$backup/$file")" != 600 ]]; then
    echo "STAGING_PHASE2A_BACKUP_FILE_UNSAFE: $file"
    exit 1
  fi
done
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$old" && sha256sum -c "$backup/SOURCE_SHA256SUMS" >/dev/null)
test "$(stat -c %a "$restore/.env.staging")" = 600
test "$(stat -c %a "$old/.env.staging")" = 600
python3 "$old/scripts/check_staging_env.py" --env-file "$old/.env.staging" >/dev/null
python3 "$old/scripts/check_staging_env.py" --env-file "$restore/.env.staging" >/dev/null
grep -Fxq 'name: teacher-workbench-staging' "$old/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$old/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$old/compose.staging.yaml"
grep -Fxq "    image: $old_tag" "$old/compose.staging.yaml"
grep -Fq 'proxy_set_header Host $http_host;' "$old/config/nginx-staging.conf"

sudo -v
old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
services="$("${old_compose[@]}" ps --status running --services)"
for service in db redis web gateway; do
  grep -Fxq "$service" <<< "$services" || { echo "STAGING_PHASE2A_SOURCE_SERVICE_NOT_RUNNING: $service"; exit 1; }
done
test "$("${old_compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
old_image="$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)"
test "$old_image" = "$(cat "$backup/APP_IMAGE_ID")"
test "$old_image" = "$(sudo -n docker image inspect -f '{{.Id}}' "$old_tag")"
if sudo -n docker image inspect "$new_tag" >/dev/null 2>&1; then
  echo "STAGING_PHASE2A_IMAGE_TAG_EXISTS"
  exit 1
fi
sudo -n docker network inspect "$restore_network" >/dev/null
sudo -n docker volume inspect "$restore_private" >/dev/null
for container in "$restore_db" "$restore_redis"; do
  test "$(sudo -n docker inspect -f '{{.State.Status}}' "$container")" = exited
  test "$(sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$container")" = "$restore_network"
done
test "$(sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$restore_db")" = "$prefix-db"
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        assert response.status == 200
print("STAGING_PHASE2A_SOURCE_LOGIN_HTTP_200")
PY
echo "STAGING_PHASE2A_ISOLATION_PREFLIGHT_OK"

mkdir -m 700 "$new"
python3 - "$source_archive" "$linebreak_archive" "$accounts_archive" "$new" <<'PY'
import sys
import tarfile
from pathlib import Path, PurePosixPath
source, linebreak, accounts, target = map(Path, sys.argv[1:])
required_accounts = {
    "config/settings.py", "workbench/models.py", "workbench/forms.py", "workbench/urls.py",
    "workbench/member_views.py", "workbench/member_middleware.py",
    "workbench/migrations/0004_memberaccess_memberaudit.py", "workbench/tests_accounts.py",
    "templates/base.html", "templates/workbench/member_list.html",
    "templates/workbench/member_secret_once.html", "templates/workbench/member_change_password.html",
    "workbench/static/workbench/site.css", "scripts/prepare_ubuntu_staging_phase2a_manager.py",
}
for archive_path, expected in ((source, None), (linebreak, {"workbench/export.py", "workbench/templatetags/worksheet_display.py"}), (accounts, required_accounts)):
    with tarfile.open(archive_path, "r:gz") as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        if len(names) != len(set(names)) or (expected is not None and set(names) != expected):
            raise SystemExit("STAGING_PHASE2A_ARCHIVE_MEMBERS_UNEXPECTED")
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or not (member.isfile() or member.isdir()):
                raise SystemExit("STAGING_PHASE2A_ARCHIVE_MEMBER_UNSAFE")
        archive.extractall(target, filter="data")
print("STAGING_PHASE2A_SOURCE_READY")
PY
install -m 600 "$old/.env.staging" "$new/.env.staging"
python3 - "$new/compose.staging.yaml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
before = "image: teacher-workbench-staging-web:manual-queue-20261017"
after = "image: teacher-workbench-staging-web:accounts-20261018"
old_dockerfile = "dockerfile: Dockerfile.staging-offline"
new_dockerfile = "dockerfile: Dockerfile.phase2a-paired"
if content.count(before) != 1 or content.count(old_dockerfile) != 1:
    raise SystemExit("STAGING_PHASE2A_COMPOSE_IMAGE_UNEXPECTED")
path.write_text(content.replace(before, after).replace(old_dockerfile, new_dockerfile), encoding="utf-8", newline="\n")
PY
cat > "$new/Dockerfile.phase2a-paired" <<'DOCKERFILE'
FROM teacher-workbench-staging-web:linebreak-20261017
WORKDIR /app
COPY manage.py ./
COPY config/ ./config/
COPY workbench/ ./workbench/
COPY templates/ ./templates/
COPY scripts/prepare_ubuntu_staging_phase2a_manager.py ./scripts/prepare_ubuntu_staging_phase2a_manager.py
DOCKERFILE
python3 "$new/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
"${new_compose[@]}" config --quiet
grep -Fxq '      - "127.0.0.1:18002:8080"' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"
grep -Fq 'proxy_set_header Host $http_host;' "$new/config/nginx-staging.conf"
echo "STAGING_PHASE2A_NEW_CONFIG_READY"
timeout 900s sudo -n docker build --pull=false --no-cache --network none \
  -f "$new/Dockerfile.phase2a-paired" -t "$new_tag" "$new"
sudo -n docker image inspect "$new_tag" >/dev/null
echo "STAGING_PHASE2A_OFFLINE_IMAGE_BUILT"

restored_started=0
switched=0
cleanup() {
  if [[ "$restored_started" == 1 ]]; then
    timeout 30s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null 2>&1 || echo "STAGING_PHASE2A_RESTORE_STOP_NEEDS_REVIEW" >&2
  fi
  if [[ "$switched" == 1 ]]; then
    if timeout 120s "${old_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway >/dev/null; then
      echo "STAGING_PHASE2A_OLD_WEB_GATEWAY_RESTORED" >&2
    else
      echo "STAGING_PHASE2A_ROLLBACK_NEEDS_REVIEW" >&2
    fi
  fi
}
trap cleanup EXIT

restored_started=1
timeout 30s sudo -n docker start "$restore_db" "$restore_redis" >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$restore_db" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then ready=1; break; fi
  sleep 2
done
test "$ready" = 1 || { echo "STAGING_PHASE2A_RESTORE_DB_NOT_READY"; exit 1; }
run_restored=(sudo -n docker run --pull never --rm --network "$restore_network" --env-file "$restore/.env.staging" -e DB_HOST="$restore_db" -e REDIS_URL="redis://$restore_redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private -v "$restore_private:/app/data/private:ro" "$new_tag")
timeout 120s "${run_restored[@]}" python manage.py migrate --noinput
timeout 120s "${run_restored[@]}" python manage.py check
timeout 180s "${run_restored[@]}" python manage.py test workbench.tests_accounts --verbosity 0
timeout 60s "${run_restored[@]}" python - <<'PY'
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from workbench.models import Material, MemberAccess, Worksheet, WorksheetVersion
assert settings.DATABASES["default"]["HOST"] == "teacher-workbench-staging-phase2a-pre-restore-20261018-db"
assert not settings.AI_ENABLED and not settings.AI_API_KEY and settings.AI_STAGING_MANUAL_QUEUE
assert get_user_model().objects.filter(username="staging_preview_20261017").exists()
assert Material.objects.count() == 1 and Worksheet.objects.count() == 1
assert list(WorksheetVersion.objects.values_list("number", flat=True).order_by("number")) == [1, 2]
assert MemberAccess.objects.count() == 0
print("STAGING_PHASE2A_RESTORED_MIGRATION_AND_DATA_OK")
PY
timeout 30s sudo -n docker stop "$restore_redis" "$restore_db" >/dev/null
restored_started=0
echo "STAGING_PHASE2A_ISOLATED_POSTGRES_TESTS_OK"

switched=1
timeout 120s "${new_compose[@]}" up -d --no-deps --force-recreate --no-build --pull never web gateway
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
  then ready=1; break; fi
  sleep 2
done
test "$ready" = 1 || { echo "STAGING_PHASE2A_LOGIN_NOT_READY"; exit 1; }
timeout 45s "${new_compose[@]}" exec -T web python manage.py check >/dev/null
timeout 45s "${new_compose[@]}" exec -T web python manage.py showmigrations workbench | grep -Fq '[X] 0004_memberaccess_memberaudit'
timeout 90s "${new_compose[@]}" exec -T web python - < "$helper"
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        assert response.status == 200
print("STAGING_PHASE2A_NEW_AND_OLD_LOGIN_HTTP_200")
PY
switched=0
echo "STAGING_PHASE2A_DEPLOYED_AI_OFF"
echo "STAGING_PHASE2A_NEW_DIR=$new"
