#!/usr/bin/env bash
# Rebuild only the isolated staging web from reviewed source plus two render files.
# Requires a paired two-version backup; preserves old source, image and all volumes.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 1 ]]; then
  echo "USAGE: apply_ubuntu_staging_linebreak_fix.sh /home/huahua/teacher-workbench-staging-backups/backup-revised-XXXXXXXX"
  exit 1
fi

old="$HOME/teacher-workbench-staging-1d3ed18b"
new="$HOME/teacher-workbench-staging-linebreak-7198283e"
source_archive="$HOME/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
patch_archive="$HOME/teacher-workbench-staging-linebreak-fix-7198283e.tar.gz"
backup_root="$HOME/teacher-workbench-staging-backups"
backup="$1"
expected_source="1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb"
expected_patch="7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d"

if [[ ! "$backup" =~ ^/home/huahua/teacher-workbench-staging-backups/backup-revised-[A-Za-z0-9]{8}$ ]] || \
   [[ -L "$backup_root" || -L "$backup" || ! -d "$backup" || "$(stat -c %a "$backup_root")" != 700 || "$(stat -c %a "$backup")" != 700 ]]; then
  echo "STAGING_LINEBREAK_BACKUP_PATH_UNSAFE"
  exit 1
fi
if [[ -e "$new" || -L "$new" || -L "$old" || ! -d "$old" || "$(stat -c %a "$old")" != 700 ]]; then
  echo "STAGING_LINEBREAK_SOURCE_OR_TARGET_UNSAFE"
  exit 1
fi
for archive in "$source_archive" "$patch_archive"; do
  if [[ -L "$archive" || ! -f "$archive" ]]; then
    echo "STAGING_LINEBREAK_ARCHIVE_UNSAFE"
    exit 1
  fi
done
if [[ "$(sha256sum "$source_archive" | cut -d ' ' -f 1)" != "$expected_source" || \
      "$(sha256sum "$patch_archive" | cut -d ' ' -f 1)" != "$expected_patch" ]]; then
  echo "STAGING_LINEBREAK_ARCHIVE_HASH_MISMATCH"
  exit 1
fi
for file in db.dump private.tar.gz SHA256SUMS SOURCE_SHA256SUMS APP_IMAGE_ID STATE teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz; do
  if [[ -L "$backup/$file" || ! -f "$backup/$file" || "$(stat -c %a "$backup/$file")" != 600 ]]; then
    echo "STAGING_LINEBREAK_BACKUP_FILE_UNSAFE: $file"
    exit 1
  fi
done
if [[ "$(cat "$backup/STATE")" != STAGING_REVISED_BACKUP_COMPLETE ]]; then
  echo "STAGING_LINEBREAK_BACKUP_INCOMPLETE"
  exit 1
fi
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)

cd "$old"
sha256sum -c "$backup/SOURCE_SHA256SUMS" >/dev/null
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
grep -Fxq '      - "127.0.0.1:18002:8080"' compose.staging.yaml
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' compose.staging.yaml
grep -Fq 'proxy_set_header Host $http_host;' config/nginx-staging.conf
test "$(stat -c %a .env.staging)" = 600
python3 scripts/check_staging_env.py --env-file .env.staging >/dev/null
for file in workbench/export.py workbench/templatetags/worksheet_display.py; do
  expected="$(tar -xOzf "$source_archive" "$file" | sha256sum | cut -d ' ' -f 1)"
  actual="$(sha256sum "$file" | cut -d ' ' -f 1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "STAGING_LINEBREAK_SOURCE_CODE_CHANGED: $file"
    exit 1
  fi
done

sudo -v
old_compose=(sudo -n docker compose --env-file "$old/.env.staging" -f "$old/compose.staging.yaml")
services="$("${old_compose[@]}" ps --status running --services)"
for service in db redis web gateway; do
  if ! grep -Fxq "$service" <<< "$services"; then
    echo "STAGING_LINEBREAK_SOURCE_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
test "$("${old_compose[@]}" port gateway 8080)" = '127.0.0.1:18002'
source_image="$(sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)"
test "$source_image" = "$(cat "$backup/APP_IMAGE_ID")"
if sudo -n docker image inspect teacher-workbench-staging-web:linebreak-20261017 >/dev/null 2>&1; then
  echo "STAGING_LINEBREAK_IMAGE_TAG_ALREADY_EXISTS"
  exit 1
fi
for volume in teacher-workbench-staging_staging_db teacher-workbench-staging_staging_private; do
  sudo -n docker volume inspect "$volume" >/dev/null
done
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_LINEBREAK_SOURCE_HTTP_FAILED")
print("STAGING_LINEBREAK_SOURCE_HTTP_200")
PY
echo "STAGING_LINEBREAK_ISOLATION_PREFLIGHT_OK"

mkdir -m 700 "$new"
tar -xzf "$source_archive" -C "$new"
tar -xzf "$patch_archive" -C "$new" \
  workbench/export.py workbench/templatetags/worksheet_display.py
install -m 600 "$old/.env.staging" "$new/.env.staging"
python3 - "$new/compose.staging.yaml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
old = "image: teacher-workbench-staging-web:manual-queue-20261017"
new = "image: teacher-workbench-staging-web:linebreak-20261017"
content = path.read_text(encoding="utf-8")
if content.count(old) != 1:
    raise SystemExit("STAGING_LINEBREAK_IMAGE_TAG_UNEXPECTED")
path.write_text(content.replace(old, new), encoding="utf-8", newline="\n")
PY
grep -Fxq 'name: teacher-workbench-staging' "$new/compose.staging.yaml"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$new/compose.staging.yaml"
grep -Fxq '      AI_STAGING_MANUAL_QUEUE: "1"' "$new/compose.staging.yaml"
grep -Fq 'proxy_set_header Host $http_host;' "$new/config/nginx-staging.conf"
python3 "$new/scripts/check_staging_env.py" --env-file "$new/.env.staging" >/dev/null
new_compose=(sudo -n docker compose --env-file "$new/.env.staging" -f "$new/compose.staging.yaml")
"${new_compose[@]}" config --quiet
echo "STAGING_LINEBREAK_NEW_CONFIG_READY"
"${new_compose[@]}" build web
echo "STAGING_LINEBREAK_NEW_IMAGE_READY"

switched=1
rollback_if_needed() {
  if [[ "$switched" == 1 ]]; then
    if timeout 120s "${old_compose[@]}" up -d --no-deps --force-recreate web gateway >/dev/null; then
      echo "STAGING_LINEBREAK_FAILED_OLD_WEB_GATEWAY_RESTORED" >&2
    else
      echo "STAGING_LINEBREAK_ROLLBACK_FAILED_REVIEW_REQUIRED" >&2
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
  echo "STAGING_LINEBREAK_NEW_LOGIN_NOT_READY"
  exit 1
fi
timeout 30s "${new_compose[@]}" exec -T web python - <<'PY'
import os
from io import BytesIO
from zipfile import ZipFile
from django.conf import settings
from workbench.ai import configured
from workbench.export import render_docx
from workbench.templatetags.worksheet_display import math_segments
assert os.getenv("TW_STAGING") == "1"
assert settings.AI_STAGING_MANUAL_QUEUE and not settings.AI_ENABLED and not settings.AI_API_KEY
assert not configured()
sample = {"title": "虚构换行核对", "questions": [{
    "stem": "题目", "answer": r"第一步。\n第二步。", "source": "AI生成（原题出处未核实）", "ai_generated": True,
}]}
assert "第一步。<br>第二步。" in str(math_segments(sample["questions"][0]["answer"]))
with ZipFile(BytesIO(render_docx(sample, "synthetic.docx", teacher=True).getvalue())) as archive:
    xml = archive.read("word/document.xml")
assert b"<w:br" in xml and b"\\n" not in xml
print("STAGING_LINEBREAK_RENDER_AND_AI_OFF_VERIFIED")
PY
timeout 30s "${new_compose[@]}" exec -T web python manage.py check >/dev/null
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_LINEBREAK_LOGIN_NOT_READY")
print("STAGING_LINEBREAK_AND_OLD_TEST_LOGIN_HTTP_200")
PY
switched=0
echo "STAGING_LINEBREAK_FIX_DEPLOYED_AI_OFF"
echo "STAGING_LINEBREAK_NEW_DIR=$new"
