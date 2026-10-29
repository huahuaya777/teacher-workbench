param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'backup_ubuntu_staging_phase2c_allowance_v3.sh'
$expectedHash = '2ccf1d8fe99d79107ad350717a2e9e2a31de8236b80887cd4cd310f83a86c531'
$path = Join-Path (Join-Path $project 'scripts') $name

if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Local script missing: $name"
}
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Local script hash changed: $name"
}
Write-Output 'STAGING_2C_BACKUP_V3_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/backup_ubuntu_staging_phase2c_allowance_v3.sh && test ! -L /home/huahua/backup_ubuntu_staging_phase2c_allowance_v3.sh && echo STAGING_2C_BACKUP_V3_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'SSH preflight failed; backup v3 was not started.' }

Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'SCP failed; backup v3 was not started.' }
} finally {
    Pop-Location
}

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Backup v3 failed or SSH disconnected; do not rerun without reviewing output.' }
Write-Output 'STAGING_2C_BACKUP_V3_WRAPPER_DONE'
