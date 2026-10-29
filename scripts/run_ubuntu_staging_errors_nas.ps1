param(
    [Parameter(Mandatory = $true)][ValidateSet('Copy', 'Import')][string]$Mode,
    [string]$NasBackupName,
    [switch]$LocalCheckOnly
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'transfer_staging_errors_nas.py'
$expectedHash = '584cd1aa271dd61caaf5bd39361068a5a22596ddafb4c84b9a56020680e956b9'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Local NAS script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Local NAS script hash changed.'
}
if ($Mode -eq 'Import' -and $NasBackupName -cnotmatch '^staging-errors-data-CLQ37z6Q-[0-9a-f]{12}$') {
    throw 'NAS backup name is unexpected.'
}
Write-Output 'STAGING_ERRORS_NAS_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
if ($Mode -eq 'Copy') {
    $preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/transfer_staging_errors_nas.py && test ! -L /home/huahua/transfer_staging_errors_nas.py && echo STAGING_ERRORS_NAS_UPLOAD_TARGET_CLEAR'
    & ssh -tt $remote $preflight
    if ($LASTEXITCODE -ne 0) { throw 'Remote upload target exists or SSH preflight failed; stop.' }
    Push-Location -LiteralPath $project
    try {
        & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
        if ($LASTEXITCODE -ne 0) { throw 'NAS script upload failed; stop.' }
    } finally { Pop-Location }
    $run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && python3 -m py_compile $name && sudo python3 $name copy"
} else {
    $run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && sudo python3 $name import $NasBackupName"
}
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS transfer failed or SSH disconnected; review output before any retry.' }
Write-Output "STAGING_ERRORS_NAS_$($Mode.ToUpperInvariant())_WRAPPER_DONE"
