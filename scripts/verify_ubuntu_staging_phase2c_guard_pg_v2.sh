#!/usr/bin/env bash
# Run fictional quota and recovery tests in a fresh internal PostgreSQL network.
# The online application, database, volumes, keyring, and ports are read only.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo STAGING_2C_GUARD_V2_WRONG_HOST_USER_OR_ARGS
  exit 1
fi

source_sha=ee34113e8aa9fe17554b0c19d70f02701c56f8a016a8ce0a7cbed42433e830cc
suffix="${source_sha:0:12}"
bundle="$HOME/teacher-workbench-stage2c-guard-v2-source.tar.gz"
stage="$HOME/teacher-workbench-stage2c-guard-v2-$suffix"
prefix="tw2c-gv2-$suffix"
network="$prefix-net"
volume="$prefix-db-volume"
db="$prefix-db"
probe="$prefix-test"
online_web=teacher-workbench-staging-web-1
online_db=teacher-workbench-staging-db-1
online_config="$HOME/teacher-workbench-staging-phase2c-20261022"

if [[ -L "$bundle" || ! -f "$bundle" || -e "$stage" || -L "$stage" ||
      -L "$online_config" || ! -d "$online_config" ||
      -L "$online_config/APP_IMAGE_ID" || ! -f "$online_config/APP_IMAGE_ID" ]]; then
  echo STAGING_2C_GUARD_V2_SOURCE_OR_TARGET_UNSAFE
  exit 1
fi
[[ "$(sha256sum "$bundle" | cut -d ' ' -f 1)" == "$source_sha" ]] || {
  echo STAGING_2C_GUARD_V2_SOURCE_HASH_MISMATCH
  exit 1
}
python3 - "$bundle" <<'PY'
from pathlib import PurePosixPath
import sys
import tarfile

with tarfile.open(sys.argv[1], 'r:gz') as archive:
    members = archive.getmembers()
    names = [item.name for item in members]
    assert len(names) == 76 and len(set(names)) == len(names)
    assert all(item.isfile() and not item.issym() and not item.islnk() for item in members)
    for name in names:
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts
        assert name in ('manage.py', 'requirements.txt') or path.parts[0] in ('config', 'workbench', 'templates')
        assert path.suffix in ('.py', '.html', '.css', '.js', '.txt')
    assert {
        'workbench/management/commands/reconcile_member_calls.py',
        'workbench/tests_reconcile_member_calls.py',
        'workbench/tests_member_flow.py',
        'workbench/tests_member_tasks.py',
        'workbench/tests_pg_call_gate.py',
    } <= set(names)
print('STAGING_2C_GUARD_V2_SOURCE_MANIFEST_OK')
PY

# The wrapper authenticates sudo in the user's interactive SSH terminal.
sudo -n -v || { echo STAGING_2C_GUARD_V2_SUDO_AUTH_REQUIRED; exit 1; }
old_db=tw2c-guard-cb133427b8f6-db
if [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$old_db")" != exited ]]; then
  echo STAGING_2C_GUARD_V2_PREVIOUS_DB_NOT_STOPPED
  exit 1
fi
echo STAGING_2C_GUARD_V2_PREVIOUS_DB_STOPPED
image="$(cat "$online_config/APP_IMAGE_ID")"
[[ "$image" =~ ^sha256:[0-9a-f]{64}$ ]]
for container in "$online_web" "$online_db"; do
  [[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$container")" == running ]] || {
    echo STAGING_2C_GUARD_V2_ONLINE_SERVICE_NOT_RUNNING
    exit 1
  }
done
[[ "$(timeout 15s sudo -n docker inspect -f '{{.Image}}' "$online_web")" == "$image" ]]
timeout 15s sudo -n docker image inspect "$image" >/dev/null
timeout 15s sudo -n docker image inspect postgres:17 >/dev/null
for item in "container:$db" "container:$probe" "network:$network" "volume:$volume"; do
  kind="${item%%:*}"
  name="${item#*:}"
  if timeout 15s sudo -n docker "$kind" inspect "$name" >/dev/null 2>&1; then
    echo "STAGING_2C_GUARD_V2_TARGET_EXISTS=$kind"
    exit 1
  fi
done
echo STAGING_2C_GUARD_V2_ISOLATION_PREFLIGHT_OK

mkdir -m 700 "$stage"
mkdir -m 700 "$stage/src"
tar -xzf "$bundle" -C "$stage/src" --no-same-owner --no-same-permissions
secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
printf 'POSTGRES_DB=tw_guard\nPOSTGRES_USER=tw_guard\nPOSTGRES_PASSWORD=%s\nDB_NAME=tw_guard\nDB_USER=tw_guard\nDB_PASSWORD=%s\n' "$secret" "$secret" > "$stage/test.env"
chmod 600 "$stage/test.env"
unset secret

db_started=0
probe_started=0
cleanup() {
  rc=$?
  if [[ "$probe_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$probe" >/dev/null 2>&1 || true
  fi
  if [[ "$db_started" == 1 ]]; then
    timeout 40s sudo -n docker stop "$db" >/dev/null 2>&1 || true
    echo STAGING_2C_GUARD_V2_DB_STOP_REQUESTED_VOLUME_PRESERVED
  fi
  if [[ "$rc" != 0 ]]; then echo STAGING_2C_GUARD_V2_ISOLATED_TEST_FAILED; fi
}
trap cleanup EXIT

timeout 20s sudo -n docker network create --internal "$network" >/dev/null
[[ "$(timeout 15s sudo -n docker network inspect -f '{{.Internal}}' "$network")" == true ]]
timeout 20s sudo -n docker volume create "$volume" >/dev/null
timeout 30s sudo -n docker run --pull never -d --name "$db" \
  --network "$network" --network-alias db --env-file "$stage/test.env" \
  --health-cmd='pg_isready -U tw_guard -d tw_guard' \
  --health-interval=3s --health-timeout=3s --health-retries=20 \
  -v "$volume:/var/lib/postgresql/data" postgres:17 >/dev/null
db_started=1
health=starting
for ((index=0; index<60; index++)); do
  health="$(timeout 15s sudo -n docker inspect -f '{{.State.Health.Status}}' "$db")"
  [[ "$health" == healthy ]] && break
  [[ "$health" == unhealthy ]] && { echo STAGING_2C_GUARD_V2_DATABASE_UNHEALTHY; exit 1; }
  sleep 1
done
[[ "$health" == healthy ]] || { echo STAGING_2C_GUARD_V2_DATABASE_TIMEOUT; exit 1; }
echo STAGING_2C_GUARD_V2_FRESH_DATABASE_READY

probe_started=1
timeout 480s sudo -n docker run --pull never --rm --name "$probe" \
  --network "$network" --env-file "$stage/test.env" \
  -e DJANGO_SETTINGS_MODULE=config.settings -e DJANGO_DEBUG=1 -e DB_HOST=db \
  -e AI_ENABLED=0 -e AI_MEMBER_TASKS_ENABLED=0 -e AI_API_KEY= -e MODEL_KEYRING_DIR= \
  -v "$stage/src:/app:ro" "$image" \
  python manage.py test workbench.tests_pg_call_gate workbench.tests_call_gate \
  workbench.tests_member_tasks workbench.tests_member_flow \
  workbench.tests_reconcile_member_calls --verbosity 1 --noinput
probe_started=0
echo STAGING_2C_GUARD_V2_PG_TESTS_OK

python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener

opener = build_opener(ProxyHandler({}))
for port in (18002, 18000):
    with opener.open(f'http://127.0.0.1:{port}/login/', timeout=5) as response:
        assert response.status == 200
print('STAGING_2C_GUARD_V2_ONLINE_LOGINS_STILL_HTTP_200')
PY
timeout 40s sudo -n docker stop "$db" >/dev/null
db_started=0
[[ "$(timeout 15s sudo -n docker inspect -f '{{.State.Status}}' "$db")" == exited ]]
echo STAGING_2C_GUARD_V2_DB_STOPPED_VOLUME_PRESERVED
echo "STAGING_2C_GUARD_V2_ISOLATED_DIR=$stage"
echo STAGING_2C_GUARD_V2_PG_ISOLATED_VERIFIED
