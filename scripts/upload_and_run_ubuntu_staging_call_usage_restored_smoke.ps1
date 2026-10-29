param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptName = 'verify_ubuntu_staging_call_usage_restored_smoke.sh'
$scriptHash = '001a794a84df0a35e387d1fd1b47ab635514eccb9a6ed54f6f07e6425a378568'
$script = Join-Path (Join-Path $project 'scripts') $scriptName
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'Local smoke script missing.' }
$actual = (Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $scriptHash) { throw 'Local smoke script hash changed.' }
Write-Output 'STAGING_CALL_USAGE_RESTORED_SMOKE_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/verify_ubuntu_staging_call_usage_restored_smoke.sh && test ! -L /home/huahua/verify_ubuntu_staging_call_usage_restored_smoke.sh && echo STAGING_CALL_USAGE_RESTORED_SMOKE_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote target exists or SSH preflight failed; nothing was uploaded.' }

& scp $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; restored smoke test was not started.' }

$run = "cd /home/huahua && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_CALL_USAGE_RESTORED_SMOKE_REMOTE_SCRIPT_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Restored smoke test failed or SSH disconnected; inspect output before retrying.' }
Write-Output 'STAGING_CALL_USAGE_RESTORED_SMOKE_WRAPPER_DONE'
