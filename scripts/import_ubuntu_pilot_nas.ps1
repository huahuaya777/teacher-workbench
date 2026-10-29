param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'transfer_pilot_nas.py'
$expectedHash = 'c9846e57be94c72fad0100eaa29a8e996bb2f0ff824f8d0290850d46a2e35812'
$nasName = 'pilot-data-Wz0wCERi-93f655b6bfe6'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot NAS script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot NAS script changed; review before import.'
}
Write-Output 'PILOT_NAS_IMPORT_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = "test `$(hostname) = teacher-workbench && test `$(id -un) = huahua && cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && test ! -e /home/huahua/teacher-workbench-nas-import-$nasName && test ! -L /home/huahua/teacher-workbench-nas-import-$nasName && echo PILOT_NAS_IMPORT_TARGET_CLEAR"
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS import preflight failed; stop.' }

$run = "cd /home/huahua && sudo -v && sudo -n python3 $name import $nasName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot NAS read-only import failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_NAS_IMPORT_WRAPPER_DONE'
