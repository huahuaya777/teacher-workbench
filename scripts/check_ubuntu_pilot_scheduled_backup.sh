#!/usr/bin/env bash
# Read-only check of the most recent scheduled pilot backup and timer.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [[ "$(hostname)" != teacher-workbench || "$(id -u)" != 0 || "$#" != 0 ]]; then
  echo PILOT_BACKUP_HEALTH_WRONG_HOST_OR_USER
  exit 1
fi

base=/var/lib/teacher-workbench-pilot-scheduled
root="$base/backups"
escrow_root="$base/escrow"
[[ ! -L "$base" && ! -L "$root" && ! -L "$escrow_root" ]]
[[ "$(stat -c '%a:%u' "$base")" == 700:0 ]]
[[ "$(stat -c '%a:%u' "$root")" == 700:0 ]]
[[ "$(stat -c '%a:%u' "$escrow_root")" == 700:0 ]]
[[ "$(stat -c '%a:%u' "$root/LAST_SUCCESS")" == 600:0 ]]
mapfile -t record < "$root/LAST_SUCCESS"
[[ "${#record[@]}" == 2 ]]
[[ "${record[0]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
[[ "${record[1]}" =~ ^/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-[A-Za-z0-9]{8}$ ]]
saved_at="$(date -u -d "${record[0]}" +%s)"
now="$(date -u +%s)"
age="$((now - saved_at))"
[[ "$age" -ge 0 && "$age" -le 129600 ]] || {
  echo PILOT_SCHEDULED_BACKUP_STALE
  exit 1
}

backup="${record[1]}"
suffix="${backup##*-}"
escrow="$escrow_root/escrow-$suffix"
[[ ! -L "$backup" && ! -L "$escrow" ]]
[[ "$(stat -c '%a:%u' "$backup")" == 700:0 ]]
[[ "$(stat -c '%a:%u' "$escrow")" == 700:0 ]]
[[ "$(cat "$backup/STATE")" == PILOT_BACKUP_COMPLETE ]]
[[ "$(cat "$escrow/STATE")" == PILOT_ESCROW_COMPLETE ]]
(cd "$backup" && sha256sum -c SHA256SUMS >/dev/null)
(cd "$escrow" && sha256sum -c SHA256SUMS >/dev/null)
[[ "$(sha256sum "$escrow/v1.key" | cut -d ' ' -f 1)" == "$(cat "$backup/KEY_SHA256")" ]]
[[ "$(sha256sum /home/huahua/teacher-workbench-pilot/pilot-root-ca.crt | cut -d ' ' -f 1)" == "$(cat "$backup/CA_SHA256")" ]]
[[ "$(systemctl is-enabled teacher-workbench-pilot-backup.timer)" == enabled ]]
[[ "$(systemctl is-active teacher-workbench-pilot-backup.timer)" == active ]]
[[ "$(systemctl show teacher-workbench-pilot-backup.service -p Result --value)" == success ]]
echo PILOT_SCHEDULED_BACKUP_FRESH_PAIRED_AND_TIMER_ACTIVE
