#!/usr/bin/env bash
# Prepare a new disposable staging directory. Does not start containers.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
if [[ $# -ne 2 || ! "$2" =~ ^[0-9a-f]{64}$ ]]; then
  echo "USAGE: bash prepare_ubuntu_staging.sh ARCHIVE EXPECTED_SHA256"
  exit 1
fi
archive="$(realpath -e -- "$1")"
expected="$2"
if [[ -L "$1" || ! -f "$archive" || "$(sha256sum "$archive" | cut -d ' ' -f 1)" != "$expected" ]]; then
  echo "STAGING_ARCHIVE_HASH_OR_PATH_WRONG"
  exit 1
fi
if ! python3 - <<'PY'
from urllib.request import ProxyHandler, build_opener
try:
    with build_opener(ProxyHandler({})).open("http://127.0.0.1:18000/login/", timeout=5) as response:
        assert response.status == 200
except Exception:
    raise SystemExit(1)
PY
then
  echo "SOURCE_TEST_LOGIN_NOT_READY"
  exit 1
fi
if ss -H -ltn '( sport = :18002 )' | grep -q .; then
  echo "STAGING_PORT_18002_IN_USE"
  exit 1
fi
if [[ -n "$(sudo docker ps -aq --filter label=com.docker.compose.project=teacher-workbench-staging)" ]]; then
  echo "STAGING_PROJECT_ALREADY_EXISTS_LEAVE_UNCHANGED"
  exit 1
fi
available_mb="$(free -m | awk '/^Mem:/ {print $7}')"
disk_mb="$(df -Pm "$HOME" | awk 'NR==2 {print $4}')"
if (( available_mb < 700 || disk_mb < 1024 )); then
  echo "STAGING_RESOURCE_PREFLIGHT_FAILED"
  exit 1
fi
target="$HOME/teacher-workbench-staging-${expected:0:8}"
if [[ -e "$target" || -L "$target" ]]; then
  echo "STAGING_TARGET_EXISTS_LEAVE_UNCHANGED"
  exit 1
fi
python3 - "$archive" "$target" <<'PY'
from pathlib import Path
import os
import sys
import tarfile

source, target = Path(sys.argv[1]), Path(sys.argv[2])
with tarfile.open(source, "r:gz") as archive:
    members = archive.getmembers()
    names = [member.name for member in members]
    required = {"compose.staging.yaml", "staging.env.example", "Dockerfile.staging-offline",
                "config/settings_staging.py", "config/nginx-staging.conf",
                "scripts/prepare_ubuntu_staging_env.py", "scripts/verify_staging_http.py"}
    if len(names) != len(set(names)) or not required.issubset(names) or len(names) > 100:
        raise SystemExit("STAGING_ARCHIVE_MANIFEST_WRONG")
    if sum(item.size for item in members) > 30_000_000:
        raise SystemExit("STAGING_ARCHIVE_TOO_LARGE")
    if any(not item.isfile() or item.name.startswith("/") or ".." in Path(item.name).parts
           or "\\" in item.name for item in members):
        raise SystemExit("STAGING_ARCHIVE_UNSAFE")
    target.mkdir(mode=0o700)
    for member in members:
        output = target / member.name
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists() or output.is_symlink():
            raise SystemExit("STAGING_ARCHIVE_DUPLICATE_TARGET")
        with archive.extractfile(member) as input_file:
            descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "wb") as output_file:
                while chunk := input_file.read(1024 * 1024):
                    output_file.write(chunk)
print("STAGING_SOURCE_EXTRACTED_PRIVATE")
PY
cd "$target"
python3 scripts/prepare_ubuntu_staging_env.py
python3 scripts/check_staging_env.py --env-file .env.staging
sudo docker compose --env-file .env.staging -f compose.staging.yaml config --quiet
echo "STAGING_PREFLIGHT_OK"
echo "STAGING_DIR=$target"
echo "NO_CONTAINERS_STARTED"
