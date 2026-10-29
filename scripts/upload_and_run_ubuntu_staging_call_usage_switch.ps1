param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptName = 'apply_ubuntu_staging_call_usage.sh'
$scriptHash = '95311c3a18c9fabadab1517f0a55579bc351b31a84f48ed8bf0a11b20de65a88'
$script = Join-Path (Join-Path $project 'scripts') $scriptName

if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'Local switch script missing.' }
$actual = (Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $scriptHash) { throw 'Local switch script hash changed; stop.' }
Write-Output 'STAGING_CALL_USAGE_SWITCH_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/apply_ubuntu_staging_call_usage.sh && test ! -L /home/huahua/apply_ubuntu_staging_call_usage.sh && echo STAGING_CALL_USAGE_SWITCH_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote target exists or SSH preflight failed; no upload.' }

& scp $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; online switch was not started.' }

$run = "cd /home/huahua && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_CALL_USAGE_SWITCH_REMOTE_SCRIPT_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Staging switch failed or SSH disconnected; inspect output before any retry.' }
Write-Output 'STAGING_CALL_USAGE_SWITCH_WRAPPER_DONE'
