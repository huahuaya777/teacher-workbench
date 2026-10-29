param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'diagnose_ubuntu_staging_phase2c_backup_v2.sh'
$expectedHash = '73d9f9237916c9fbc055d3f5d8d88cce880252ada34dfd962cff56c938943f7b'
$path = Join-Path (Join-Path $project 'scripts') $name

if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Local diagnostic missing: $name"
}
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Local diagnostic hash changed: $name"
}
Write-Output 'STAGING_2C_BACKUP_DIAG_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/diagnose_ubuntu_staging_phase2c_backup_v2.sh && test ! -L /home/huahua/diagnose_ubuntu_staging_phase2c_backup_v2.sh && echo STAGING_2C_BACKUP_DIAG_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic SSH preflight failed; no diagnostic was run.' }

Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'Diagnostic SCP failed; no diagnostic was run.' }
} finally {
    Pop-Location
}

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Read-only diagnostic found a failed check or SSH disconnected; send the non-sensitive check labels.' }
Write-Output 'STAGING_2C_BACKUP_DIAG_ALL_CHECKS_OK'
