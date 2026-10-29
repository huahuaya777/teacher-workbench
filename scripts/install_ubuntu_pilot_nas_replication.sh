#!/usr/bin/env bash
# One-time installation after the user's explicit recurring NAS authorization.
set -euo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [[ "$(hostname)" != teacher-workbench || "$(id -u)" != 0 || "$#" != 0 ]]; then
  echo PILOT_NAS_INSTALL_WRONG_HOST_OR_USER
  exit 1
fi

source_dir=/home/huahua
program=/usr/local/libexec/teacher-workbench-pilot-nas-replication
policy=/etc/teacher-workbench-pilot-nas-replication.policy
service=/etc/systemd/system/teacher-workbench-pilot-nas-replication.service
timer=/etc/systemd/system/teacher-workbench-pilot-nas-replication.timer

for target in "$program" "$policy" "$service" "$timer"; do
  [[ ! -e "$target" && ! -L "$target" ]] || {
    echo PILOT_NAS_INSTALL_TARGET_EXISTS
    exit 1
  }
done

cd "$source_dir"
printf '%s\n' \
  '4360636fb2ec061211be7739966d9ec7d785ad711f8f4b54e89a2b2440d2a442  replicate_ubuntu_pilot_scheduled_nas_v3.py' \
  'd0ba150687a8b5305cf2e8e75ab50ac9c800507a4704fc2a89e66c0b1de22218  teacher-workbench-pilot-nas-replication.service' \
  '4bbba82b0f67c37919d98a3b04a3daecdd6895c2de0f8974ba575b903823935b  teacher-workbench-pilot-nas-replication.timer' \
  | sha256sum -c -
python3 -m py_compile replicate_ubuntu_pilot_scheduled_nas_v3.py
python3 -B replicate_ubuntu_pilot_scheduled_nas_v3.py verify
/usr/local/libexec/teacher-workbench-pilot-backup-health
[[ "$(systemctl show teacher-workbench-pilot-backup.service -p Result --value)" == success ]]
[[ "$(systemctl is-active teacher-workbench-pilot-backup.timer)" == active ]]
[[ "$(systemctl is-active teacher-workbench-pilot-backup-health.timer)" == active ]]
[[ -z "$(findmnt -rn -o TARGET | grep '^/mnt/teacher-workbench-pilot-nas-' || true)" ]]
echo PILOT_NAS_INSTALL_PREFLIGHT_OK

install -m 700 replicate_ubuntu_pilot_scheduled_nas_v3.py "$program"
install -m 644 teacher-workbench-pilot-nas-replication.service "$service"
install -m 644 teacher-workbench-pilot-nas-replication.timer "$timer"
install -m 600 /dev/null "$policy"
cat > "$policy" <<'POLICY'
VERSION=1
TARGET=10.0.30.6:/teacher-workbench-backup
SCOPE=all-future-pilot-snapshots
COPY_ESCROW=0
POLICY

[[ "$(stat -c '%a:%u' "$program")" == 700:0 ]]
[[ "$(stat -c '%a:%u' "$policy")" == 600:0 ]]
[[ "$(stat -c '%a:%u' "$service")" == 644:0 ]]
[[ "$(stat -c '%a:%u' "$timer")" == 644:0 ]]
systemctl daemon-reload
systemd-analyze verify "$service" "$timer"
echo PILOT_NAS_INSTALL_FILES_VERIFIED

# A controlled run must succeed and unmount before enabling future runs.
systemctl start teacher-workbench-pilot-nas-replication.service
[[ "$(systemctl show teacher-workbench-pilot-nas-replication.service -p Result --value)" == success ]]
[[ "$(systemctl show teacher-workbench-pilot-nas-replication.service -p ExecMainStatus --value)" == 0 ]]
journalctl -u teacher-workbench-pilot-nas-replication.service -n 80 --no-pager \
  | grep -q PILOT_RECURRING_NAS_COPY_DONE
[[ -z "$(findmnt -rn -o TARGET | grep '^/mnt/teacher-workbench-pilot-nas-' || true)" ]]
echo PILOT_NAS_INSTALL_CONTROLLED_COPY_VERIFIED

systemctl enable --now teacher-workbench-pilot-nas-replication.timer
[[ "$(systemctl is-enabled teacher-workbench-pilot-nas-replication.timer)" == enabled ]]
[[ "$(systemctl is-active teacher-workbench-pilot-nas-replication.timer)" == active ]]
[[ "$(curl --noproxy '*' --silent --show-error --max-time 8 \
  --cacert /home/huahua/teacher-workbench-pilot/pilot-root-ca.crt \
  --output /dev/null --write-out '%{http_code}' https://10.0.30.5:18443/login/)" == 200 ]]
[[ "$(curl --silent --show-error --max-time 8 \
  --output /dev/null --write-out '%{http_code}' http://127.0.0.1:18002/login/)" == 200 ]]
echo PILOT_NAS_REPLICATION_TIMER_ENABLED
echo PILOT_NAS_REPLICATION_INSTALL_DONE
