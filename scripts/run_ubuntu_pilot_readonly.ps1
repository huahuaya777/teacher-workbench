param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$name = 'check_ubuntu_pilot_readonly.sh'
$expectedHash = '732ee399624ac3584340a6931bc72e8168412ae713817e4ac967ab9fd6511ba7'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Local pilot preflight missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Local pilot preflight hash changed.'
}
Write-Output 'PILOT_PREFLIGHT_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/check_ubuntu_pilot_readonly.sh && test ! -L /home/huahua/check_ubuntu_pilot_readonly.sh && echo PILOT_PREFLIGHT_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote preflight target exists or SSH failed; stop.' }
Push-Location -LiteralPath $project
try {
    & scp ".\scripts\$name" 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'Pilot preflight upload failed; stop.' }
} finally { Pop-Location }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot read-only preflight failed or SSH disconnected; review output before retry.' }
Write-Output 'PILOT_PREFLIGHT_WRAPPER_DONE'
