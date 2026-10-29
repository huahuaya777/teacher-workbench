#!/usr/bin/env bash
# Rebuild the accepted renderer from NAS-imported code and the paired local app image.
# No live staging volumes, services, credentials, or paid model calls are changed.
set -euo pipefail
umask 077

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" || "$HOME" != "/home/huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ "$#" != 0 ]]; then
  echo "USAGE: verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh"
  exit 1
fi

import_dir="$HOME/teacher-workbench-nas-import-staging-revised-X7Bv9cfE-8fb7b9d72c41"
restore_dir="$HOME/teacher-workbench-staging-revised-nas-restore-20261017"
source_archive="$import_dir/teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz"
patch_archive="$import_dir/teacher-workbench-staging-linebreak-fix-7198283e.tar.gz"
build_dir="$restore_dir/nas-renderer-paired-source"
paired_tag="teacher-workbench-staging-web:manual-queue-20261017"
image_tag="teacher-workbench-staging-web:nas-renderer-paired-20261017"
prefix="teacher-workbench-staging-revised-nas-restore-20261017"
network="$prefix-net"
db_volume="$prefix-db"
private_volume="$prefix-private"
db_container="$prefix-db"
env_file="$restore_dir/.env.staging"

if [[ -L "$import_dir" || ! -d "$import_dir" || "$(stat -c %a "$import_dir")" != 700 || \
      -L "$restore_dir" || ! -d "$restore_dir" || "$(stat -c %a "$restore_dir")" != 700 || \
      -e "$build_dir" || -L "$build_dir" ]]; then
  echo "NAS_RENDERER_SOURCE_OR_TARGET_UNSAFE"
  exit 1
fi
for file in "$source_archive" "$patch_archive" "$env_file" "$import_dir/APP_IMAGE_ID"; do
  if [[ -L "$file" || ! -f "$file" || "$(stat -c %a "$file")" != 600 ]]; then
    echo "NAS_RENDERER_INPUT_UNSAFE"
    exit 1
  fi
done
if [[ "$(sha256sum "$source_archive" | cut -d ' ' -f 1)" != "1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb" || \
      "$(sha256sum "$patch_archive" | cut -d ' ' -f 1)" != "7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d" ]]; then
  echo "NAS_RENDERER_ARCHIVE_HASH_MISMATCH"
  exit 1
fi
if [[ "$(cat "$import_dir/NAS_TRANSFER_STATE")" != NAS_TRANSFER_COMPLETE || \
      "$(cat "$import_dir/STATE")" != STAGING_REVISED_BACKUP_COMPLETE ]]; then
  echo "NAS_RENDERER_IMPORT_NOT_COMPLETE"
  exit 1
fi
(cd "$import_dir" && sha256sum -c NAS_SHA256SUMS >/dev/null && sha256sum -c SHA256SUMS >/dev/null)

sudo -v
available_kib="$(df -Pk /var/lib/docker | awk 'NR == 2 {print $4}')"
if [[ ! "$available_kib" =~ ^[0-9]+$ ]] || (( available_kib < 8 * 1024 * 1024 )); then
  echo "NAS_RENDERER_DISK_SPACE_LOW_OR_UNKNOWN"
  exit 1
fi
if sudo -n docker image inspect "$image_tag" >/dev/null 2>&1; then
  echo "NAS_RENDERER_IMAGE_TAG_ALREADY_EXISTS"
  exit 1
fi
paired_id="$(sudo -n docker image inspect -f '{{.Id}}' "$paired_tag")"
recorded_id="$(cat "$import_dir/APP_IMAGE_ID")"
if [[ ! "$recorded_id" =~ ^sha256:[0-9a-f]{64}$ || "$paired_id" != "$recorded_id" ]]; then
  echo "NAS_RENDERER_PAIRED_IMAGE_MISMATCH"
  exit 1
fi
sudo -n docker network inspect "$network" >/dev/null
for volume in "$db_volume" "$private_volume"; do
  sudo -n docker volume inspect "$volume" >/dev/null
done
if [[ "$(sudo -n docker inspect -f '{{.State.Status}}' "$db_container")" != exited || \
      "$(sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$db_container")" != "$network" || \
      "$(sudo -n docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$db_container")" != "$db_volume" ]]; then
  echo "NAS_RENDERER_RESTORE_DATABASE_UNEXPECTED"
  exit 1
fi
echo "NAS_RENDERER_PAIRED_ISOLATION_PREFLIGHT_OK"

mkdir -m 700 "$build_dir"
python3 - "$source_archive" "$patch_archive" "$build_dir" <<'PY'
import sys
import tarfile
from pathlib import Path, PurePosixPath

source, patch, target = map(Path, sys.argv[1:])
patch_names = {"workbench/export.py", "workbench/templatetags/worksheet_display.py"}
for archive_path, expected_names in ((source, None), (patch, patch_names)):
    with tarfile.open(archive_path, "r:gz") as archive:
        members = archive.getmembers()
        names = [item.name for item in members]
        if len(names) != len(set(names)):
            raise SystemExit("NAS_RENDERER_ARCHIVE_DUPLICATE")
        if expected_names is not None and set(names) != expected_names:
            raise SystemExit("NAS_RENDERER_PATCH_MEMBERS_UNEXPECTED")
        for item in members:
            path = PurePosixPath(item.name)
            if path.is_absolute() or ".." in path.parts or not (item.isfile() or item.isdir()):
                raise SystemExit("NAS_RENDERER_ARCHIVE_MEMBER_UNSAFE")
        archive.extractall(target, filter="data")
for name in patch_names:
    if not (target / name).is_file():
        raise SystemExit("NAS_RENDERER_PATCH_FILE_MISSING")
for name in ("manage.py", "config", "workbench", "templates", "scripts/check_test_env.py", "scripts/check_staging_env.py"):
    if not (target / name).exists():
        raise SystemExit("NAS_RENDERER_APPLICATION_SOURCE_MISSING")
print("NAS_RENDERER_SOURCE_AND_PATCH_READY")
PY
python3 "$build_dir/scripts/check_staging_env.py" --env-file "$env_file" >/dev/null

cat > "$build_dir/Dockerfile.nas-renderer-paired" <<'DOCKERFILE'
FROM teacher-workbench-staging-web:manual-queue-20261017
WORKDIR /app
COPY manage.py ./
COPY config/ ./config/
COPY workbench/ ./workbench/
COPY templates/ ./templates/
COPY scripts/check_test_env.py ./scripts/check_test_env.py
COPY scripts/check_staging_env.py ./scripts/check_staging_env.py
DOCKERFILE

timeout 900s sudo -n docker build --pull=false --no-cache --network none \
  -f "$build_dir/Dockerfile.nas-renderer-paired" -t "$image_tag" "$build_dir"
sudo -n docker image inspect "$image_tag" >/dev/null
echo "NAS_RENDERER_PAIRED_OFFLINE_IMAGE_BUILT"

started=0
stop_if_needed() {
  if [[ "$started" == 1 ]]; then
    timeout 30s sudo -n docker stop "$db_container" >/dev/null 2>&1 || echo "NAS_RENDERER_DATABASE_STOP_UNVERIFIED" >&2
  fi
}
trap stop_if_needed EXIT
started=1
timeout 30s sudo -n docker start "$db_container" >/dev/null
ready=0
for _ in {1..30}; do
  if timeout 5s sudo -n docker exec "$db_container" psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
if [[ "$ready" != 1 ]]; then
  echo "NAS_RENDERER_RESTORE_DATABASE_NOT_READY"
  exit 1
fi

timeout 90s sudo -n docker run --pull never --rm -i --network "$network" \
  --env-file "$env_file" -e DB_HOST="$db_container" \
  -e REDIS_URL="redis://${prefix}-redis:6379/0" \
  -e PRIVATE_FILE_ROOT=/app/data/private \
  -v "$private_volume:/app/data/private:ro" "$image_tag" python - <<'PY'
import os
from io import BytesIO
from zipfile import ZipFile
from docx import Document

assert os.getenv("TW_STAGING") == "1"
assert os.getenv("DJANGO_SETTINGS_MODULE") == "config.settings_staging"

import django
django.setup()

from django.conf import settings
from workbench.export import render_docx
from workbench.models import WorksheetVersion
from workbench.templatetags.worksheet_display import math_segments

assert not settings.AI_ENABLED and not settings.AI_API_KEY and not settings.AI_LOCAL_QUEUE
assert settings.AI_STAGING_MANUAL_QUEUE
assert settings.DATABASES["default"]["HOST"] == "teacher-workbench-staging-revised-nas-restore-20261017-db"
versions = list(WorksheetVersion.objects.order_by("number"))
assert [version.number for version in versions] == [1, 2]
content = versions[1].content
answers = [item["answer"] for item in content["questions"] if r"\n" in item["answer"]]
assert answers, "NAS_RENDERER_REVISED_LITERAL_BREAK_MISSING"
for answer in answers:
    preview = str(math_segments(answer))
    assert "<br>" in preview
    assert r"\n" not in preview
student = render_docx(content, "fictional.docx", teacher=False).getvalue()
teacher = render_docx(content, "fictional.docx", teacher=True).getvalue()
assert student != teacher
student_doc = Document(BytesIO(student))
teacher_doc = Document(BytesIO(teacher))
assert not any("参考答案：" in p.text for p in student_doc.paragraphs)
assert any("参考答案：" in p.text for p in teacher_doc.paragraphs)
with ZipFile(BytesIO(teacher)) as archive:
    xml = archive.read("word/document.xml")
assert b"<w:br" in xml and b"\\n" not in xml
print("NAS_RENDERER_REVISED_PREVIEW_AND_WORD_VERIFIED")
PY

timeout 30s sudo -n docker stop "$db_container" >/dev/null
started=0
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("NAS_RENDERER_SOURCE_LOGIN_FAILED")
print("NAS_RENDERER_SOURCE_LOGIN_HTTP_200")
PY
echo "NAS_RENDERER_RESTORE_DATABASE_STOPPED"
echo "NAS_RENDERER_FROM_NAS_PAIRED_REBUILD_VERIFIED"
