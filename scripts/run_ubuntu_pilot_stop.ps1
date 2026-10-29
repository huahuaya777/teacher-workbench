param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'stop_ubuntu_pilot.sh'
$expectedHash = '7623e410ab59498cc4d3c5ca67aa818a645238fd5aaf7ae9fe7285a918ca2f30'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot stop script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot stop script changed.'
}
Write-Output 'PILOT_STOP_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot stop failed or SSH disconnected; inspect pilot status without deleting volumes.' }
Write-Output 'PILOT_STOP_WRAPPER_DONE'
