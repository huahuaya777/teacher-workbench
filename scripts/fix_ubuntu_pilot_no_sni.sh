#!/usr/bin/env bash
# Repair the new pilot gateway when an IP-literal client omits TLS SNI.
# Recreate only the gateway; retain all pilot data, CA, and old staging.
set -euo pipefail
umask 077

if [[ "$(hostname)" != teacher-workbench || "$(id -un)" != huahua ||
      "$HOME" != /home/huahua || "$#" != 0 ]]; then
  echo PILOT_NO_SNI_WRONG_HOST_OR_USER
  exit 1
fi

target="$HOME/teacher-workbench-pilot"
candidate="$HOME/Caddyfile.pilot.no-sni-fix"
old_hash=7cda5e150597b9c6e215b98c3646f730c45571e85298512b3af68f8dfb3b0e59
new_hash=65043844312f9454833eece8df8c9abac56765430796b0ef84401ec4a13afe98
[[ ! -L "$target" && -d "$target" && "$(stat -c %a "$target")" == 700 ]]
[[ "$(cat "$target/STATE")" == PILOT_STARTING ]]
[[ ! -L "$candidate" && -f "$candidate" ]]
[[ "$(sha256sum "$candidate" | cut -d ' ' -f 1)" == "$new_hash" ]]
[[ "$(sha256sum "$target/Caddyfile.pilot" | cut -d ' ' -f 1)" == "$old_hash" ]]
[[ ! -e "$target/Caddyfile.pilot.before-no-sni-fix" ]]
[[ -s "$target/pilot-root-ca.crt" ]]
(cd "$target" && sha256sum -c SHA256SUMS >/dev/null)
python3 "$target/check_pilot_env.py" --env-file "$target/.env.pilot"

caddy_image="$(python3 - "$target/.env.pilot" <<'PY'
from pathlib import Path
import sys
values = dict(line.split('=', 1) for line in Path(sys.argv[1]).read_text().splitlines() if '=' in line)
print(values['PILOT_CADDY_IMAGE'])
PY
)"
[[ "$caddy_image" =~ ^sha256:[0-9a-f]{64}$ ]]

sudo -v
[[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Running}}' teacher-workbench-pilot-web-1)" == true ]]
[[ "$(timeout 10s sudo -n docker inspect -f '{{.State.Running}}' teacher-workbench-pilot-gateway-1)" == true ]]
[[ "$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]

# Validate the exact candidate before touching the running gateway.
timeout 30s sudo -n docker run --pull never --rm --network none \
  --entrypoint caddy -v "$candidate:/etc/caddy/Caddyfile:ro" \
  "$caddy_image" validate --config /etc/caddy/Caddyfile --adapter caddyfile
echo PILOT_NO_SNI_CONFIG_VALIDATED

install -m 600 "$target/Caddyfile.pilot" "$target/Caddyfile.pilot.before-no-sni-fix"
install -m 600 "$candidate" "$target/Caddyfile.pilot.next"
mv -T "$target/Caddyfile.pilot.next" "$target/Caddyfile.pilot"
(cd "$target" && sha256sum compose.pilot.yaml Caddyfile.pilot check_pilot_env.py .env.pilot > SHA256SUMS.next)
mv -T "$target/SHA256SUMS.next" "$target/SHA256SUMS"
(cd "$target" && sha256sum -c SHA256SUMS >/dev/null)

cd "$target"
timeout 30s sudo -n docker compose --env-file .env.pilot -f compose.pilot.yaml config --quiet
sudo -n docker compose --env-file .env.pilot -f compose.pilot.yaml \
  up -d --no-build --no-deps --force-recreate gateway
echo PILOT_NO_SNI_GATEWAY_RECREATED

[[ "$(sha256sum pilot-root-ca.crt | cut -d ' ' -f 1)" == \
   "$(timeout 10s sudo -n docker exec teacher-workbench-pilot-gateway-1 cat /data/caddy/pki/authorities/local/root.crt | sha256sum | cut -d ' ' -f 1)" ]]

login_status=""
static_status=""
for attempt in $(seq 1 30); do
  login_status="$(curl --noproxy '*' --silent --max-time 8 \
    --cacert pilot-root-ca.crt --output /dev/null --write-out '%{http_code}' \
    https://10.0.30.5:18443/login/ 2>/dev/null || true)"
  static_status="$(curl --noproxy '*' --silent --max-time 8 \
    --cacert pilot-root-ca.crt --output /dev/null --write-out '%{http_code}' \
    https://10.0.30.5:18443/static/workbench/site.css 2>/dev/null || true)"
  if [[ "$login_status" == 200 && "$static_status" == 200 ]]; then
    break
  fi
  sleep 2
done
[[ "$login_status" == 200 && "$static_status" == 200 ]] || {
  echo "PILOT_NO_SNI_SMOKE_FAILED login=$login_status static=$static_status"
  exit 1
}
[[ "$(curl --silent --show-error --max-time 8 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
printf 'PILOT_STARTED_AI_OFF\n' > STATE
echo PILOT_HTTPS_LOGIN_AND_STATIC_TRUSTED_LOCALLY_200
echo PILOT_STAGING_LOGIN_STILL_HTTP_200
openssl x509 -in pilot-root-ca.crt -noout -fingerprint -sha256
echo "PILOT_ROOT_CA_PATH=$target/pilot-root-ca.crt"
echo PILOT_NO_SNI_REPAIR_COMPLETE_AI_OFF
