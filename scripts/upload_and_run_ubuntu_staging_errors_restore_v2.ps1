param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'restore_ubuntu_staging_errors_v2.sh'
$expectedHash = '825deea11fb2db67c3566d07e41c0fbabbc5b8a09ce63a418299db09676e43fc'
$path = Join-Path (Join-Path $project 'scripts') $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Local script missing: $name"
}
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Local script hash changed: $name"
}
if ([System.IO.File]::ReadAllBytes($path) -contains 13) {
    throw "Script must use LF newlines: $name"
}
Write-Output 'STAGING_ERRORS_V2_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_staging_errors_v2.sh && test ! -L /home/huahua/restore_ubuntu_staging_errors_v2.sh && echo STAGING_ERRORS_V2_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) {
    throw 'Remote upload target already exists or SSH preflight failed; no restore was started.'
}

& scp $path ('{0}:/home/huahua/' -f $remote)
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; no restore was started.' }

$backup = '/home/huahua/teacher-workbench-staging-backups/backup-staging-errors-CLQ37z6Q'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && echo STAGING_ERRORS_V2_UPLOAD_VERIFIED && sudo -v && bash $name $backup"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) {
    throw 'Isolated restore v2 failed or SSH disconnected; review the last non-sensitive output before any retry.'
}
Write-Output 'STAGING_ERRORS_V2_WRAPPER_DONE'
