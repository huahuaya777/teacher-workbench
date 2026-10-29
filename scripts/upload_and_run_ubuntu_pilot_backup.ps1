param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'backup_ubuntu_pilot.sh'
$expectedHash = '788b9209ef807f8e0fde371d3fd96f5863af68d688a3e50a0ae0606978a1d951'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot backup script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot backup script changed; review before upload.'
}
Write-Output 'PILOT_BACKUP_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/backup_ubuntu_pilot.sh && test ! -L /home/huahua/backup_ubuntu_pilot.sh && grep -Fxq PILOT_STARTED_AI_OFF /home/huahua/teacher-workbench-pilot/STATE && echo PILOT_BACKUP_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot backup target or state changed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot backup upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot backup failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_BACKUP_WRAPPER_DONE'
