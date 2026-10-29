param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'transfer_pilot_nas.py'
$expectedHash = 'c9846e57be94c72fad0100eaa29a8e996bb2f0ff824f8d0290850d46a2e35812'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot NAS script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot NAS script changed; review before upload.'
}
Write-Output 'PILOT_NAS_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/transfer_pilot_nas.py && test ! -L /home/huahua/transfer_pilot_nas.py && grep -Fxq PILOT_BACKUP_COMPLETE /home/huahua/teacher-workbench-pilot-backups/backup-pilot-Wz0wCERi/STATE && echo PILOT_NAS_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS source or target changed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS script upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && python3 -m py_compile $name && sudo -v && sudo -n python3 $name copy"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS data copy failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_NAS_COPY_WRAPPER_DONE'
