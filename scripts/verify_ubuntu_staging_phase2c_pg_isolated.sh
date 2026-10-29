#!/usr/bin/env bash
# Test the reviewed 2C source against a fresh, isolated PostgreSQL 17 volume.
# No online database, private-file volume, keyring, app container, or port is used.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_PG_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

source_sha=36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303
suffix="${source_sha:0:12}"
bundle="$HOME/teacher-workbench-stage2c-pg-source.tar.gz"
stage="$HOME/teacher-workbench-stage2c-pg-$suffix"
network="teacher-workbench-stage2c-pg-$suffix-net"
volume="teacher-workbench-stage2c-pg-$suffix-db"
db_container="teacher-workbench-stage2c-pg-$suffix-db"
test_container="teacher-workbench-stage2c-pg-$suffix-test"
app_tag=teacher-workbench-staging-web:credentials-20261020
online_web=teacher-workbench-staging-web-1
online_db=teacher-workbench-staging-db-1

if [[ -L "$bundle" || ! -f "$bundle" || -e "$stage" || -L "$stage" ]]; then
  echo STAGING_2C_PG_SOURCE_OR_TARGET_UNSAFE
  exit 1
fi
[[ "$(sha256sum "$bundle" | cut -d ' ' -f 1)" == "$source_sha" ]] || {
  echo STAGING_2C_PG_SOURCE_HASH_MISMATCH
  exit 1
}
python3 - "$bundle" <<'PY'
from pathlib import PurePosixPath
import sys
import tarfile

with tarfile.open(sys.argv[1], 'r:gz') as archive:
    members = archive.getmembers()
    names = [item.name for item in members]
    assert len(names) == 74 and len(set(names)) == len(names)
    assert all(item.isfile() and not item.issym() and not item.islnk() for item in members)
    for name in names:
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts
        assert name in ('manage.py', 'requirements.txt') or path.parts[0] in ('config', 'workbench', 'templates')
        assert path.suffix in ('.py', '.html', '.css', '.js', '.txt')
    for needed in ('workbench/tests_pg_call_gate.py',
                   'workbench/migrations/0006_callallowance_callattempt.py',
                   'workbench/migrations/0007_alter_memberaudit_action.py',
                   'workbench/migrations/0008_generationtask_member_credential_and_more.py'):
        assert needed in names
print('STAGING_2C_PG_SOURCE_MANIFEST_OK')
PY

# The user authenticates sudo in an interactive SSH shell before this script.
# A stale credential fails immediately instead of hanging at an unseen prompt.
sudo -n -v || { echo STAGING_2C_PG_SUDO_AUTH_REQUIRED; exit 1; }
for pair in \
  "$online_db:postgres:17" \
  "$online_web:$app_tag"; do
  container="${pair%%:*}"
  image="${pair#*:}"
  running="$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")"
  expected="$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$image")"
  actual="$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$container")"
  [[ "$running" == running && "$actual" == "$expected" ]] || {
    echo "STAGING_2C_PG_ONLINE_IMAGE_CHANGED=$container"
    exit 1
  }
done
for kind_name in "container:$db_container" "container:$test_container" \
                 "network:$network" "volume:$volume"; do
  kind="${kind_name%%:*}"
  name="${kind_name#*:}"
  if timeout 15s sudo -n docker "$kind" inspect "$name" >/dev/null 2>&1; then
    echo "STAGING_2C_PG_TARGET_EXISTS=$kind"
    exit 1
  fi
done
echo STAGING_2C_PG_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$stage"
mkdir -m 700 "$stage/src"
tar -xzf "$bundle" -C "$stage/src" --no-same-owner --no-same-permissions
secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
printf 'POSTGRES_DB=teacher_workbench_stage2c\nPOSTGRES_USER=tw_stage2c\nPOSTGRES_PASSWORD=%s\nDB_NAME=teacher_workbench_stage2c\nDB_USER=tw_stage2c\nDB_PASSWORD=%s\n' "$secret" "$secret" > "$stage/test.env"
chmod 600 "$stage/test.env"
unset secret
echo STAGING_2C_PG_PRIVATE_TEST_SOURCE_READY

db_started=0
test_started=0
cleanup() {
  rc=$?
  if [[ "$test_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$test_container" >/dev/null 2>&1 || true
  fi
  if [[ "$db_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$db_container" >/dev/null 2>&1 || true
    echo STAGING_2C_PG_DB_STOP_REQUESTED_VOLUME_PRESERVED
  fi
  if [[ "$rc" != 0 ]]; then echo STAGING_2C_PG_ISOLATED_TEST_FAILED; fi
}
trap cleanup EXIT

timeout 20s sudo -n docker network create --internal "$network" >/dev/null
[[ "$(timeout 15s sudo -n docker network inspect -f '{{.Internal}}' "$network")" == true ]]
timeout 20s sudo -n docker volume create "$volume" >/dev/null
timeout 30s sudo -n docker run --pull never -d --name "$db_container" \
  --network "$network" --network-alias db --env-file "$stage/test.env" \
  --health-cmd='pg_isready -U tw_stage2c -d teacher_workbench_stage2c' \
  --health-interval=3s --health-timeout=3s --health-retries=20 \
  -v "$volume:/var/lib/postgresql/data" postgres:17 >/dev/null
db_started=1
for ((index=0; index<60; index++)); do
  health="$(timeout 15s sudo -n docker inspect -f '{{.State.Health.Status}}' "$db_container")"
  [[ "$health" == healthy ]] && break
  [[ "$health" == unhealthy ]] && { echo STAGING_2C_PG_DATABASE_UNHEALTHY; exit 1; }
  sleep 1
done
[[ "$health" == healthy ]] || { echo STAGING_2C_PG_DATABASE_TIMEOUT; exit 1; }
echo STAGING_2C_PG_FRESH_DATABASE_READY

common_args=(--pull never --rm --name "$test_container" --network "$network"
  --env-file "$stage/test.env" -e DJANGO_SETTINGS_MODULE=config.settings
  -e DJANGO_DEBUG=1 -e DB_HOST=db -e AI_ENABLED=0 -e AI_API_KEY=
  -e AI_MEMBER_TASKS_ENABLED=0 -e MODEL_KEYRING_DIR=
  -v "$stage/src:/app:ro")
test_started=1
timeout 60s sudo -n docker run "${common_args[@]}" "$app_tag" python -c '
import django
django.setup()
from django.conf import settings
from django.db import connection
assert connection.vendor == "postgresql"
assert settings.DATABASES["default"]["NAME"] == "teacher_workbench_stage2c"
assert settings.DATABASES["default"]["HOST"] == "db"
assert not settings.AI_ENABLED and not settings.AI_MEMBER_TASKS_ENABLED
print("STAGING_2C_PG_TEST_SETTINGS_OFFLINE_OK")
'
test_started=0

test_started=1
timeout 420s sudo -n docker run "${common_args[@]}" "$app_tag" \
  python manage.py test workbench.tests_pg_call_gate workbench.tests_call_gate \
  workbench.tests_member_tasks --verbosity 1 --noinput
test_started=0
echo STAGING_2C_PG_CONCURRENCY_AND_SPECIALIZED_TESTS_OK

[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$online_web")" == \
   "$(timeout 15s sudo -n docker image inspect -f '{{.Id}}' "$app_tag")" ]]
python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_PG_ONLINE_LOGINS_STILL_HTTP_200')
PY
timeout 40s sudo -n docker stop "$db_container" >/dev/null
db_started=0
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db_container")" == exited ]]
echo STAGING_2C_PG_DB_STOPPED_VOLUME_PRESERVED
echo "STAGING_2C_PG_ISOLATED_DIR=$stage"
echo STAGING_2C_PG_ISOLATED_TEST_VERIFIED
