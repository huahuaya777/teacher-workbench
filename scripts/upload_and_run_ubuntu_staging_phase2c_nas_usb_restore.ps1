param(
    [Parameter(Mandatory = $true)][string]$NasBackupName,
    [switch]$LocalCheckOnly
)

$ErrorActionPreference = 'Stop'
if ($NasBackupName -cnotmatch '^staging-phase2c-allowance-data-j33bqT1R-[0-9a-f]{12}$') {
    throw 'NAS backup name is not the expected fictional 2C snapshot.'
}

$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'restore_ubuntu_staging_phase2c_from_nas_usb.sh'
$expectedHash = '9020a7c7420dd926cf057ec1ca36c517c58b00193df61610f7cbc90367f6637e'
$path = Join-Path (Join-Path $project 'scripts') $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Local script missing: $name" }
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) { throw "Local script hash changed: $name" }
Write-Output 'STAGING_2C_NAS_USB_RESTORE_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_staging_phase2c_from_nas_usb.sh && test ! -L /home/huahua/restore_ubuntu_staging_phase2c_from_nas_usb.sh && echo STAGING_2C_NAS_USB_RESTORE_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'SSH preflight failed; NAS/USB restore was not started.' }

Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'SCP failed; NAS/USB restore was not started.' }
} finally {
    Pop-Location
}

$importDir = "/home/huahua/teacher-workbench-nas-import-$NasBackupName"
$recoveredKeyDir = '/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name $importDir $recoveredKeyDir"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS/USB restore failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_NAS_USB_RESTORE_WRAPPER_DONE'
