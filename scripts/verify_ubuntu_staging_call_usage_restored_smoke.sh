#!/usr/bin/env bash
# Smoke-test the candidate image with the fresh fictional restored data.
# The online stack remains on the old image; no model request is enabled.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_CALL_USAGE_SMOKE_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

suffix=szRPlLy0
candidate="$HOME/teacher-workbench-staging-call-usage-14537acaacc6"
record="$HOME/teacher-workbench-staging-call-usage-pre-switch-14537acaacc6"
backup="$HOME/teacher-workbench-staging-backups/backup-phase2c-allowance-$suffix"
escrow="$HOME/teacher-workbench-staging-key-escrow/keyring-$suffix"
restore="$HOME/teacher-workbench-staging-phase2c-allowance-restore-$suffix"
prefix="teacher-workbench-staging-phase2c-allowance-restore-$suffix"
network="$prefix-net"
db="$prefix-db"
redis="$prefix-redis"
private_volume="$prefix-private"
probe="tw-call-usage-$suffix-probe"
old_id=sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a
candidate_id=sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26
candidate_tag=teacher-workbench-staging-web:call-usage-14537acaacc6

for directory in "$candidate" "$record" "$backup" "$escrow" "$restore"; do
  [[ ! -L "$directory" && -d "$directory" && "$(stat -c %a "$directory")" == 700 ]] || {
    echo STAGING_CALL_USAGE_SMOKE_DIRECTORY_UNSAFE
    exit 1
  }
done
for file in "$candidate/APP_IMAGE_ID" "$candidate/STATE" \
            "$candidate/SOURCE_SHA256SUMS" "$record/STATE" \
            "$record/BACKUP_DIR" "$record/RESTORE_DIR" \
            "$restore/.env.staging" "$escrow/v1.key"; do
  [[ ! -L "$file" && -f "$file" && "$(stat -c %a "$file")" == 600 ]] || {
    echo STAGING_CALL_USAGE_SMOKE_FILE_UNSAFE
    exit 1
  }
done
[[ "$(cat "$candidate/APP_IMAGE_ID")" == "$candidate_id" ]]
[[ "$(cat "$candidate/STATE")" == STAGING_CALL_USAGE_OFFLINE_IMAGE_COMPLETE ]]
[[ "$(cat "$record/STATE")" == STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_COMPLETE ]]
[[ "$(cat "$record/BACKUP_DIR")" == "$backup" ]]
[[ "$(cat "$record/RESTORE_DIR")" == "$restore" ]]
[[ ! -e "$record/SMOKE_STATE" && ! -L "$record/SMOKE_STATE" ]]
(cd "$candidate/src" && sha256sum -c ../SOURCE_SHA256SUMS >/dev/null)
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
echo STAGING_CALL_USAGE_SMOKE_BACKUP_IMAGE_AND_KEY_VERIFIED

sudo -n -v || { echo STAGING_CALL_USAGE_SMOKE_SUDO_AUTH_REQUIRED; exit 1; }
[[ "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$candidate_tag")" == "$candidate_id" ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_id" ]]
for container in "$db" "$redis"; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == exited ]]
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.HostConfig.NetworkMode}}' "$container")" == "$network" ]]
done
timeout 15s sudo -n docker network inspect "$network" >/dev/null
timeout 15s sudo -n docker volume inspect "$private_volume" >/dev/null
if timeout 15s sudo -n docker container inspect "$probe" >/dev/null 2>&1; then
  echo STAGING_CALL_USAGE_SMOKE_PROBE_EXISTS
  exit 1
fi
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_SMOKE_ONLINE_BEFORE_HTTP_200')
PY
echo STAGING_CALL_USAGE_SMOKE_ISOLATION_PREFLIGHT_OK

started=1
probe_started=0
cleanup() {
  rc=$?
  if [[ "$probe_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$probe" >/dev/null 2>&1 || true
  fi
  if [[ "$started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null 2>&1 ||
      echo STAGING_CALL_USAGE_SMOKE_STOP_NEEDS_REVIEW >&2
  fi
  if [[ "$rc" != 0 ]]; then echo STAGING_CALL_USAGE_SMOKE_FAILED; fi
}
trap cleanup EXIT

timeout 60s sudo -n docker start "$db" "$redis" >/dev/null
ready=0
for ((index=0; index<45; index++)); do
  if timeout 8s sudo -n docker exec "$db" psql -U teacher_workbench_staging \
      -d teacher_workbench_staging -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq 1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" == 1 ]] || { echo STAGING_CALL_USAGE_SMOKE_DB_NOT_READY; exit 1; }
ready=0
for ((index=0; index<20; index++)); do
  if timeout 8s sudo -n docker exec "$redis" redis-cli ping 2>/dev/null | grep -Fxq PONG; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo STAGING_CALL_USAGE_SMOKE_REDIS_NOT_READY; exit 1; }
echo STAGING_CALL_USAGE_SMOKE_RESTORED_SERVICES_READY

common_args=(--pull never --rm --name "$probe" --network "$network"
  --env-file "$restore/.env.staging" -e DB_HOST="$db"
  -e REDIS_URL="redis://$redis:6379/0" -e PRIVATE_FILE_ROOT=/app/data/private
  -e MODEL_KEYRING_DIR=/run/model-keyring -e MODEL_ACTIVE_KEY_VERSION=1
  -e AI_ENABLED=0 -e AI_API_KEY= -e AI_LOCAL_QUEUE=0
  -e AI_STAGING_MANUAL_QUEUE=1 -e AI_MEMBER_TASKS_ENABLED=0
  -v "$private_volume:/app/data/private:ro" -v "$escrow:/run/model-keyring:ro")
probe_started=1
timeout 90s sudo -n docker run "${common_args[@]}" "$candidate_id" python manage.py check
probe_started=0
probe_started=1
timeout 90s sudo -n docker run "${common_args[@]}" "$candidate_id" python manage.py migrate --check --noinput
probe_started=0
probe_started=1
timeout 90s sudo -n docker run -i "${common_args[@]}" "$candidate_id" python - <<'PY'
from types import SimpleNamespace
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.template.loader import get_template, render_to_string
from django.test import Client, override_settings
from django.urls import reverse
from django.utils import timezone
from workbench.credential_vault import unseal_key_for_owner, vault_ready
from workbench.models import CallAllowance, CallAttempt, ModelCredential, Worksheet, WorksheetVersion

assert settings.DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql'
assert settings.DATABASES['default']['HOST'] == 'teacher-workbench-staging-phase2c-allowance-restore-szRPlLy0-db'
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED and not settings.AI_API_KEY
assert settings.AI_STAGING_MANUAL_QUEUE and vault_ready()
users = get_user_model().objects
preview = users.get(username='staging_preview_20261017')
owner = users.get(username='staging_teacher_a_20261018', is_active=True)
worksheet = Worksheet.objects.get(owner=preview, pk=1)
assert WorksheetVersion.objects.filter(worksheet=worksheet, number=2).exists()
credentials = list(ModelCredential.objects.filter(owner=owner))
assert len(credentials) >= 2
assert all(unseal_key_for_owner(item, owner.pk).startswith('sk-fictional-') for item in credentials)
allowance = CallAllowance.objects.get(owner=owner)
assert (allowance.max_calls, allowance.used_calls, allowance.reserved_calls) == (0, 0, 0)
assert not CallAttempt.objects.exists()
get_template('workbench/_task_call_usage.html')
sent = SimpleNamespace(status='completed', sent_at=timezone.now(), input_tokens=0, output_tokens=7)
rendered = render_to_string('workbench/_task_call_usage.html', {'attempt': sent})
assert '输入 0' in rendered and '输出 7' in rendered and '已计入 1 次' in rendered
unknown = SimpleNamespace(status='unknown', sent_at=timezone.now(), input_tokens=None, output_tokens=None)
rendered_unknown = render_to_string('workbench/_task_call_usage.html', {'attempt': unknown})
assert '用量未知' in rendered_unknown and '厂商账单' in rendered_unknown
with override_settings(ALLOWED_HOSTS=['testserver']):
    browser = Client()
    browser.force_login(preview)
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 200
    browser.force_login(owner)
    assert browser.get(reverse('worksheet_detail', args=[worksheet.pk])).status_code == 404
print('STAGING_CALL_USAGE_CANDIDATE_RESTORED_CONTENT_AND_PAGE_OK')
PY
probe_started=0

timeout 40s sudo -n docker stop "$redis" "$db" >/dev/null
started=0
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$redis")" == exited ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_CALL_USAGE_SMOKE_ONLINE_AFTER_HTTP_200')
PY
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' teacher-workbench-staging-web-1)" == "$old_id" ]]
printf 'STAGING_CALL_USAGE_RESTORED_SMOKE_COMPLETE\n' > "$record/SMOKE_STATE"
echo STAGING_CALL_USAGE_RESTORED_CONTAINERS_STOPPED_VOLUMES_PRESERVED
echo STAGING_CALL_USAGE_CANDIDATE_RESTORED_SMOKE_VERIFIED_NO_SWITCH
