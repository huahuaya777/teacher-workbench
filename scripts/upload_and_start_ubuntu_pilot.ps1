param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'start_ubuntu_pilot.sh'
$expectedHash = '2de398b9a7cb3285966bceef4dc25c52b9ef4f46baf4613daa53b8a758bc4258'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot start script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot start script changed.'
}
Write-Output 'PILOT_START_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/start_ubuntu_pilot.sh && test ! -L /home/huahua/start_ubuntu_pilot.sh && test -f /home/huahua/teacher-workbench-pilot/STATE && grep -Fxq PILOT_CONFIG_PREPARED /home/huahua/teacher-workbench-pilot/STATE && echo PILOT_START_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot config is not ready, target exists, or SSH failed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot start upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot startup failed or SSH disconnected; preserve volumes and review non-sensitive markers before retry.' }
Write-Output 'PILOT_START_WRAPPER_DONE'
