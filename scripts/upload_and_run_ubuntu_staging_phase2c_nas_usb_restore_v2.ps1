param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'restore_ubuntu_staging_phase2c_from_nas_usb_v2.sh'
$expectedHash = '68ad19950ad5880ecbaa3be2398e9c997c31d6f722bdd4530fb57422eea564e8'
$path = Join-Path (Join-Path $project 'scripts') $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Local script missing: $name" }
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) { throw "Local script hash changed: $name" }
Write-Output 'STAGING_2C_NAS_USB_V2_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_staging_phase2c_from_nas_usb_v2.sh && test ! -L /home/huahua/restore_ubuntu_staging_phase2c_from_nas_usb_v2.sh && echo STAGING_2C_NAS_USB_V2_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'SSH preflight failed; v2 restore was not started.' }

Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'SCP failed; v2 restore was not started.' }
} finally {
    Pop-Location
}

$importDir = '/home/huahua/teacher-workbench-nas-import-staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0'
$recoveredKeyDir = '/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name $importDir $recoveredKeyDir"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS/USB v2 restore failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_NAS_USB_V2_WRAPPER_DONE'
