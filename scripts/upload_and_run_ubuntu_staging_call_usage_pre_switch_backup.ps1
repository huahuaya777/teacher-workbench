param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scriptName = 'backup_restore_ubuntu_staging_call_usage_pre_switch.sh'
$expected = @{
    $scriptName = '777d89726c19f169d11a2c96802bea998ee6437539715b285e0e1fdaef1d0eac'
    'backup_ubuntu_staging_phase2c_allowance_v3.sh' = '2ccf1d8fe99d79107ad350717a2e9e2a31de8236b80887cd4cd310f83a86c531'
    'restore_ubuntu_staging_phase2c_allowance.sh' = 'a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d'
}
foreach ($name in $expected.Keys) {
    $path = Join-Path (Join-Path $project 'scripts') $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Local input missing: $name" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected[$name]) { throw "Local input hash changed: $name" }
}
Write-Output 'STAGING_CALL_USAGE_PRE_SWITCH_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/backup_restore_ubuntu_staging_call_usage_pre_switch.sh && test ! -L /home/huahua/backup_restore_ubuntu_staging_call_usage_pre_switch.sh && echo STAGING_CALL_USAGE_PRE_SWITCH_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote upload target exists or SSH preflight failed; nothing was uploaded.' }

$script = Join-Path (Join-Path $project 'scripts') $scriptName
& scp $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; backup and restore were not started.' }

$scriptHash = $expected[$scriptName]
$run = "cd /home/huahua && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_CALL_USAGE_PRE_SWITCH_REMOTE_SCRIPT_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pre-switch backup or independent restore failed; inspect output before retrying.' }
Write-Output 'STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_WRAPPER_DONE'
