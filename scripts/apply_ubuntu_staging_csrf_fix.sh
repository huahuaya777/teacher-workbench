#!/usr/bin/env bash
# Patch only the mounted staging Nginx config; preserve database and files.
set -euo pipefail

if [[ "$(hostname)" != "teacher-workbench" || "$(id -un)" != "huahua" ]]; then
  echo "WRONG_HOST_OR_USER"
  exit 1
fi
stage="$HOME/teacher-workbench-staging-74586f82"
candidate="$HOME/nginx-staging-csrf-569890e8.conf"
current="$stage/config/nginx-staging.conf"
old_sha="c184ab6be5c68d3e07928eb6039d5e8b64282beb7dd5436825d60d2369c3c76f"
new_sha="569890e8f8829d9f3c1dee8c78e9dcdf66521a3b96951b4566b4579f2a7a6f05"
if [[ -L "$stage" || ! -d "$stage" || -L "$candidate" || ! -f "$candidate" || -L "$current" || ! -f "$current" ]]; then
  echo "STAGING_CSRF_PATH_UNSAFE_OR_MISSING"
  exit 1
fi
if [[ "$(sha256sum "$current" | cut -d ' ' -f 1)" != "$old_sha" ]]; then
  echo "STAGING_CSRF_ORIGINAL_CHANGED_LEAVE_UNTOUCHED"
  exit 1
fi
if [[ "$(sha256sum "$candidate" | cut -d ' ' -f 1)" != "$new_sha" ]]; then
  echo "STAGING_CSRF_CANDIDATE_HASH_WRONG"
  exit 1
fi
cd "$stage"
grep -Fxq 'name: teacher-workbench-staging' compose.staging.yaml
if [[ "$(sudo docker compose --env-file .env.staging -f compose.staging.yaml port gateway 8080)" != "127.0.0.1:18002" ]]; then
  echo "STAGING_GATEWAY_NOT_LOOPBACK"
  exit 1
fi
services="$(sudo docker compose --env-file .env.staging -f compose.staging.yaml ps --status running --services)"
for service in db redis web gateway; do
  if ! grep -Fxq "$service" <<< "$services"; then
    echo "STAGING_SERVICE_NOT_RUNNING: $service"
    exit 1
  fi
done
backup="$stage/config/nginx-staging.conf.before-csrf-569890e8"
if [[ -e "$backup" || -L "$backup" ]]; then
  echo "STAGING_CSRF_BACKUP_EXISTS_LEAVE_UNTOUCHED"
  exit 1
fi
cp -p -- "$current" "$backup"
changed=0
rollback() {
  if [[ "$changed" == "1" ]]; then
    set +e
    if cat "$backup" > "$current" && \
       sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T gateway nginx -t && \
       sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T gateway nginx -s reload; then
      echo "STAGING_CSRF_FIX_FAILED_OLD_GATEWAY_RESTORED"
    else
      echo "STAGING_CSRF_FIX_ROLLBACK_FAILED_REVIEW_REQUIRED"
    fi
  fi
}
trap rollback ERR
changed=1
cat "$candidate" > "$current"  # In-place write preserves the bind-mounted inode.
sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T gateway nginx -t
sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T gateway nginx -s reload

python3 - <<'PY'
import http.cookiejar
import re
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request

base = "http://127.0.0.1:18002"
opener = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
)
for attempt in range(5):
    with opener.open(base + "/login/", timeout=5) as response:
        html = response.read()
    match = re.search(rb'name="csrfmiddlewaretoken" value="([^"]+)"', html)
    if not match:
        raise SystemExit("STAGING_CSRF_TOKEN_MISSING")
    body = urllib.parse.urlencode({
        "username": "staging_csrf_probe_" + secrets.token_hex(8),
        "password": "fictional-wrong-password",
        "csrfmiddlewaretoken": match.group(1).decode("ascii"),
    }).encode()
    request = urllib.request.Request(base + "/login/", data=body, headers={
        "Origin": base,
        "Referer": base + "/login/",
    })
    try:
        with opener.open(request, timeout=5) as response:
            status, answer = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, answer = error.code, error.read()
    if status == 200 and "用户名或密码不正确".encode() in answer:
        print("STAGING_CSRF_ORIGIN_POST_REACHED_LOGIN_HTTP_200")
        break
    if attempt == 4:
        raise SystemExit(f"STAGING_CSRF_POST_STATUS_{status}")
    time.sleep(1)
else:
    raise SystemExit("STAGING_CSRF_POST_NOT_VERIFIED")

for port in (18002, 18000):
    with opener.open(f"http://127.0.0.1:{port}/login/", timeout=5) as response:
        if response.status != 200:
            raise SystemExit("STAGING_OR_SOURCE_LOGIN_NOT_READY")
print("STAGING_AND_SOURCE_LOGIN_HTTP_200_AFTER_CSRF_FIX")
PY

changed=0
trap - ERR
echo "STAGING_CSRF_GATEWAY_RELOAD_VERIFIED"
echo "STAGING_DATA_VOLUMES_NOT_RECREATED"
