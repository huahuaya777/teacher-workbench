#!/usr/bin/env bash
# Repair the isolated staging static volume without rebuilding or restarting services.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo WRONG_HOST_USER_OR_ARGS
  exit 1
fi

stage_dir="$HOME/teacher-workbench-staging-phase2a-1bf5a500"
compose_file="$stage_dir/compose.staging.yaml"
css_backup="$stage_dir/site.css.before-password-layout-fix"
compose_backup="$stage_dir/compose.staging.yaml.before-password-layout-fix"
web_container=teacher-workbench-staging-web-1
gateway_container=teacher-workbench-staging-gateway-1
expected_old_css=f51fd29e1bba4f30df3ea50e5e2d36e99862f2f5c7911860fa1f253125f126a5
expected_new_css=e69350c56233cc5adb34dd7ba2719abdb4378c17d90c85022f0ec8b317b9326b

if [[ -L "$stage_dir" || ! -d "$stage_dir" ||
      "$(stat -c %a "$stage_dir")" != 700 ||
      -L "$compose_file" || ! -f "$compose_file" ||
      -e "$css_backup" || -L "$css_backup" ||
      -e "$compose_backup" || -L "$compose_backup" ]]; then
  echo STAGING_PASSWORD_CSS_STAGE_UNSAFE
  exit 1
fi
grep -Fxq 'name: teacher-workbench-staging' "$compose_file"
grep -Fxq '    image: teacher-workbench-staging-web:accounts-20261018' "$compose_file"
grep -Fxq '      - "127.0.0.1:18002:8080"' "$compose_file"
grep -Fq 'python manage.py collectstatic --noinput' "$compose_file"
if grep -Fq 'python manage.py collectstatic --clear --noinput' "$compose_file"; then
  echo STAGING_PASSWORD_CSS_COMPOSE_ALREADY_CHANGED
  exit 1
fi

sudo -v
for container in "$web_container" "$gateway_container"; do
  if [[ "$(timeout 30s sudo -n docker inspect -f '{{.State.Status}}' "$container")" != running ]]; then
    echo STAGING_PASSWORD_CSS_SERVICE_NOT_RUNNING
    exit 1
  fi
done
web_image="$(timeout 30s sudo -n docker inspect -f '{{.Image}}' "$web_container")"
tag_image="$(timeout 30s sudo -n docker image inspect -f '{{.Id}}' teacher-workbench-staging-web:accounts-20261018)"
if [[ "$web_image" != "$tag_image" ||
      "$(timeout 30s sudo -n docker port "$gateway_container" 8080/tcp)" != '127.0.0.1:18002' ]]; then
  echo STAGING_PASSWORD_CSS_DEPLOYMENT_UNEXPECTED
  exit 1
fi

source_css="$(timeout 30s sudo -n docker exec "$web_container" sha256sum /app/workbench/static/workbench/site.css | cut -d ' ' -f 1)"
static_css="$(timeout 30s sudo -n docker exec "$web_container" sha256sum /app/staticfiles/workbench/site.css | cut -d ' ' -f 1)"
served_css="$(python3 - <<'PY'
from hashlib import sha256
from urllib.request import ProxyHandler, build_opener

with build_opener(ProxyHandler({})).open(
    'http://127.0.0.1:18002/static/workbench/site.css?phase2a-css-preflight', timeout=5
) as response:
    assert response.status == 200
    print(sha256(response.read()).hexdigest())
PY
)"
if [[ "$source_css" != "$expected_new_css" || "$static_css" != "$expected_old_css" ||
      "$served_css" != "$expected_old_css" ]]; then
  echo STAGING_PASSWORD_CSS_HASH_UNEXPECTED
  exit 1
fi
echo STAGING_PASSWORD_CSS_PREFLIGHT_OK

timeout 30s sudo -n docker cp "$web_container:/app/staticfiles/workbench/site.css" "$css_backup"
timeout 30s sudo -n chmod 600 "$css_backup"
cp -p "$compose_file" "$compose_backup"
chmod 600 "$compose_backup"
if [[ "$(timeout 30s sudo -n sha256sum "$css_backup" | cut -d ' ' -f 1)" != "$expected_old_css" ]]; then
  echo STAGING_PASSWORD_CSS_BACKUP_UNEXPECTED
  exit 1
fi
echo STAGING_PASSWORD_CSS_BACKUPS_READY

python3 - "$compose_file" <<'PY'
import os
from pathlib import Path
import sys
import tempfile

path = Path(sys.argv[1])
before = path.read_text(encoding='utf-8')
old = 'python manage.py collectstatic --noinput'
new = 'python manage.py collectstatic --clear --noinput'
if before.count(old) != 1 or new in before:
    raise SystemExit('STAGING_PASSWORD_CSS_COMPOSE_UNEXPECTED')
fd, temporary = tempfile.mkstemp(prefix='.compose-static-', dir=path.parent)
try:
    with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as output:
        output.write(before.replace(old, new))
        output.flush()
        os.fsync(output.fileno())
    os.chmod(temporary, path.stat().st_mode & 0o777)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY

timeout 30s sudo -n docker exec -i "$web_container" python - <<'PY'
from hashlib import sha256
import os
from pathlib import Path
import tempfile

source = Path('/app/workbench/static/workbench/site.css')
target = Path('/app/staticfiles/workbench/site.css')
old_hash = 'f51fd29e1bba4f30df3ea50e5e2d36e99862f2f5c7911860fa1f253125f126a5'
new_hash = 'e69350c56233cc5adb34dd7ba2719abdb4378c17d90c85022f0ec8b317b9326b'
if source.is_symlink() or target.is_symlink() or not target.is_file():
    raise SystemExit('STAGING_PASSWORD_CSS_PATH_UNSAFE')
payload = source.read_bytes()
if sha256(payload).hexdigest() != new_hash or sha256(target.read_bytes()).hexdigest() != old_hash:
    raise SystemExit('STAGING_PASSWORD_CSS_CONTENT_CHANGED')
fd, temporary = tempfile.mkstemp(prefix='.site-css-phase2a-', dir=target.parent)
try:
    with os.fdopen(fd, 'wb') as output:
        output.write(payload)
        output.flush()
        os.fsync(output.fileno())
    os.chmod(temporary, 0o644)
    os.replace(temporary, target)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print('STAGING_PASSWORD_CSS_ATOMIC_REPLACE_OK')
PY

new_static_css="$(timeout 30s sudo -n docker exec "$web_container" sha256sum /app/staticfiles/workbench/site.css | cut -d ' ' -f 1)"
new_served_css="$(python3 - <<'PY'
from hashlib import sha256
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
with opener.open('http://127.0.0.1:18002/static/workbench/site.css?phase2a-css-fixed', timeout=5) as response:
    assert response.status == 200
    print(sha256(response.read()).hexdigest())
for port in (18002,):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
PY
)"
if [[ "$new_static_css" != "$expected_new_css" || "$new_served_css" != "$expected_new_css" ]]; then
  echo STAGING_PASSWORD_CSS_POSTCHECK_FAILED
  exit 1
fi
grep -Fq 'python manage.py collectstatic --clear --noinput' "$compose_file"
echo STAGING_PASSWORD_CSS_HTTP_AND_LOGIN_OK
echo STAGING_PASSWORD_LAYOUT_STATIC_FIXED
