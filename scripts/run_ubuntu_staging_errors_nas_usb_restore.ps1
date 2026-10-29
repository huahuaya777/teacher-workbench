param(
    [Parameter(Mandatory = $true)][string]$NasBackupName,
    [switch]$LocalCheckOnly
)

$ErrorActionPreference = 'Stop'
if ($NasBackupName -cnotmatch '^staging-errors-data-CLQ37z6Q-[0-9a-f]{12}$') {
    throw 'NAS backup name is unexpected.'
}
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'restore_ubuntu_staging_errors_from_nas_usb.sh'
$expectedHash = 'd52669d7e751f6b2f0347a46b894dc67b4ac1339b3fd472a6a7c82eb16c88843'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Local restore script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Local restore script hash changed.'
}
Write-Output 'STAGING_ERRORS_NAS_USB_RESTORE_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_staging_errors_from_nas_usb.sh && test ! -L /home/huahua/restore_ubuntu_staging_errors_from_nas_usb.sh && echo STAGING_ERRORS_NAS_USB_RESTORE_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote restore upload target exists or SSH preflight failed; stop.' }
Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'Restore script upload failed; stop.' }
} finally { Pop-Location }

$importDir = "/home/huahua/teacher-workbench-nas-import-$NasBackupName"
$recoveredKeyDir = '/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name $importDir $recoveredKeyDir"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS/USB restore failed or SSH disconnected; review output before any retry.' }
Write-Output 'STAGING_ERRORS_NAS_USB_RESTORE_WRAPPER_DONE'
