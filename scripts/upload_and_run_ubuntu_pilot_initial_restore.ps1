param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'restore_ubuntu_pilot_initial.sh'
$expectedHash = '0697732a0eb039c375810381d1a6e43cedb13b6dc41f4c1b2ee01a6be0f2109d'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot restore script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot restore script changed; review before upload.'
}
Write-Output 'PILOT_RESTORE_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_pilot_initial.sh && test ! -L /home/huahua/restore_ubuntu_pilot_initial.sh && grep -Fxq PILOT_BACKUP_COMPLETE /home/huahua/teacher-workbench-pilot-backups/backup-pilot-Wz0wCERi/STATE && grep -Fxq PILOT_ESCROW_COMPLETE /home/huahua/teacher-workbench-pilot-key-escrow/escrow-Wz0wCERi/STATE && echo PILOT_RESTORE_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore source or target changed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_RESTORE_WRAPPER_DONE'
