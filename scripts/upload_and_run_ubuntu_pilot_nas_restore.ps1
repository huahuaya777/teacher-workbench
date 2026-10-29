param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'restore_ubuntu_pilot_nas.sh'
$expectedHash = 'df1982dbb5085cdf9ccccb39d9f54aa928df5ece5567ded3be262a0ba20d0458'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot NAS restore script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot NAS restore script changed; review before upload.'
}
Write-Output 'PILOT_NAS_RESTORE_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = "test `$(hostname) = teacher-workbench && test `$(id -un) = huahua && test ! -e /home/huahua/$name && test ! -L /home/huahua/$name && test -f /home/huahua/teacher-workbench-nas-import-pilot-data-Wz0wCERi-93f655b6bfe6/NAS_TRANSFER_STATE && test ! -e /home/huahua/teacher-workbench-pilot-nas-restore-93f655b6bfe6 && echo PILOT_NAS_RESTORE_UPLOAD_TARGET_CLEAR"
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS restore source or target changed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS restore script upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS restore failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_NAS_RESTORE_WRAPPER_DONE'
