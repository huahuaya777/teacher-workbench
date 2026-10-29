param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'transfer_staging_phase2c_allowance_nas.py'
$expectedHash = '8c787c3bbdcae98c56eea8faff3ffee3363a855628c3220fdd9e148c8c854bdd'
$path = Join-Path (Join-Path $project 'scripts') $name

if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Local script missing: $name"
}
$actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
    throw "Local script hash changed: $name"
}
Write-Output 'STAGING_2C_NAS_COPY_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/transfer_staging_phase2c_allowance_nas.py && test ! -L /home/huahua/transfer_staging_phase2c_allowance_nas.py && echo STAGING_2C_NAS_COPY_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'SSH preflight failed; NAS copy was not started.' }

Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'SCP failed; NAS copy was not started.' }
} finally {
    Pop-Location
}

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && python3 -m py_compile $name && echo STAGING_2C_NAS_COPY_SCRIPT_VERIFIED && sudo python3 $name copy"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS copy failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_NAS_COPY_WRAPPER_DONE'
