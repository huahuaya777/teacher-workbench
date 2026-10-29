#!/usr/bin/env bash
# Create a separate, AI-disabled pilot config. Do not start services or migrate.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_PREPARE_WRONG_HOST_OR_USER
  exit 1
fi

source_dir="$HOME"
target="$HOME/teacher-workbench-pilot"
backup="$HOME/teacher-workbench-staging-backups/backup-staging-errors-CLQ37z6Q"
[[ ! -e "$target" && ! -L "$target" ]]
for name in compose.pilot.yaml Caddyfile.pilot check_pilot_env.py; do
  [[ -f "$source_dir/$name" && ! -L "$source_dir/$name" ]]
done
[[ ! -L "$backup" && -d "$backup" && "$(stat -c %a "$backup")" == 700 ]]
[[ "$(cat "$backup/STATE")" == STAGING_ERRORS_BACKUP_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
app_image="$(cat "$backup/APP_IMAGE_ID")"
[[ "$app_image" =~ ^sha256:[0-9a-f]{64}$ ]]

sudo -v
[[ "$(timeout 10s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$app_image" ]]
if timeout 10s sudo -n docker container ls -a --format '{{.Names}}' |
    grep -Eq '^teacher-workbench-pilot-'; then
  echo PILOT_PREPARE_EXISTING_CONTAINER
  exit 1
fi
if timeout 10s sudo -n docker volume ls --format '{{.Name}}' |
    grep -Eq '^teacher-workbench-pilot_'; then
  echo PILOT_PREPARE_EXISTING_VOLUME
  exit 1
fi
for tag in postgres:17 redis:7-alpine; do
  timeout 10s sudo -n docker image inspect "$tag" >/dev/null || {
    echo PILOT_PREPARE_REQUIRED_IMAGE_MISSING
    exit 1
  }
done
if ! timeout 10s sudo -n docker image inspect caddy:2-alpine >/dev/null 2>&1; then
  echo PILOT_CADDY_IMAGE_PULL_START
  timeout 180s sudo -n docker pull caddy:2-alpine >/dev/null || {
    echo PILOT_CADDY_IMAGE_PULL_FAILED
    exit 1
  }
  echo PILOT_CADDY_IMAGE_PULL_OK
fi
db_image="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' postgres:17)"
redis_image="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' redis:7-alpine)"
caddy_image="$(timeout 10s sudo -n docker image inspect -f '{{.Id}}' caddy:2-alpine)"
for image in "$db_image" "$redis_image" "$caddy_image"; do
  [[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
done
if ss -H -ltn | awk '{print $4}' | grep -Eq '(^|:)18443$'; then
  echo PILOT_PREPARE_PORT_IN_USE
  exit 1
fi
ip -4 -o addr show | awk '{print $4}' | grep -Fxq '10.0.30.5/24'
echo PILOT_PREPARE_PREFLIGHT_OK

keyring="$HOME/teacher-workbench-pilot-keyring-$(python3 - <<'PY'
import secrets
print(secrets.token_hex(4))
PY
)"
[[ ! -e "$keyring" && ! -L "$keyring" ]]
mkdir -m 700 "$keyring"
python3 - "$keyring/v1.key" <<'PY'
import base64
import os
import sys
payload = base64.b64encode(os.urandom(32)) + b'\n'
fd = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, 'wb') as output:
    output.write(payload)
    output.flush()
    os.fsync(output.fileno())
PY

mkdir -m 700 "$target"
install -m 600 "$source_dir/compose.pilot.yaml" "$target/compose.pilot.yaml"
install -m 600 "$source_dir/Caddyfile.pilot" "$target/Caddyfile.pilot"
install -m 600 "$source_dir/check_pilot_env.py" "$target/check_pilot_env.py"
python3 - "$target/.env.pilot" "$keyring" "$app_image" "$db_image" "$redis_image" "$caddy_image" <<'PY'
import os
import secrets
import sys
path, keyring, app_image, db_image, redis_image, caddy_image = sys.argv[1:]
values = {
    'TW_PILOT': '1',
    'DJANGO_SETTINGS_MODULE': 'config.settings',
    'DJANGO_DEBUG': '0',
    'DJANGO_SECRET_KEY': secrets.token_urlsafe(64),
    'DJANGO_ALLOWED_HOSTS': '10.0.30.5',
    'DJANGO_CSRF_TRUSTED_ORIGINS': 'https://10.0.30.5:18443',
    'DJANGO_SECURE_SSL_REDIRECT': '1',
    'DJANGO_TRUST_PROXY_SSL_HEADER': '1',
    'DJANGO_HSTS_SECONDS': '3600',
    'DB_NAME': 'teacher_workbench_pilot',
    'DB_USER': 'teacher_workbench_pilot',
    'DB_PASSWORD': secrets.token_urlsafe(40),
    'DB_HOST': 'db',
    'REDIS_URL': 'redis://redis:6379/0',
    'PRIVATE_FILE_ROOT': '/app/data/private',
    'MODEL_KEYRING_DIR': '/run/model-keyring',
    'MODEL_ACTIVE_KEY_VERSION': '1',
    'PILOT_KEYRING_DIR': keyring,
    'PILOT_APP_IMAGE': app_image,
    'PILOT_DB_IMAGE': db_image,
    'PILOT_REDIS_IMAGE': redis_image,
    'PILOT_CADDY_IMAGE': caddy_image,
    'AI_ENABLED': '0',
    'AI_API_KEY': '',
    'AI_LOCAL_QUEUE': '0',
    'AI_STAGING_MANUAL_QUEUE': '0',
    'AI_MEMBER_TASKS_ENABLED': '0',
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as output:
    output.write(''.join(f'{name}={value}\n' for name, value in values.items()))
    output.flush()
    os.fsync(output.fileno())
PY

cd "$target"
python3 check_pilot_env.py --env-file .env.pilot
timeout 30s sudo -n docker compose --env-file .env.pilot -f compose.pilot.yaml config --quiet
timeout 30s sudo -n docker run --pull never --rm --network none \
  --entrypoint caddy -v "$target/Caddyfile.pilot:/etc/caddy/Caddyfile:ro" \
  "$caddy_image" validate --config /etc/caddy/Caddyfile --adapter caddyfile
(cd "$target" && sha256sum compose.pilot.yaml Caddyfile.pilot check_pilot_env.py .env.pilot > SHA256SUMS)
printf 'PILOT_CONFIG_PREPARED\n' > "$target/STATE"
echo PILOT_CONFIG_AND_CADDY_VALIDATED
echo "PILOT_CONFIG_DIR=$target"
echo PILOT_CONFIG_PREPARED_NO_START
