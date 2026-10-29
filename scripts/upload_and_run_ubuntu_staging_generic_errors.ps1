param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script = Join-Path (Join-Path $project 'scripts') 'apply_ubuntu_staging_generic_errors.sh'
$settings = Join-Path (Join-Path $project 'config') 'settings_staging.py'
$command = Join-Path (Join-Path (Join-Path (Join-Path $project 'workbench') 'management') 'commands') 'run_staging_task.py'
$scriptHash = '015075ae205da98671764dc1807acdf76e6f2ae24aa526685666ec20b8f14db2'
$settingsHash = 'ea646093d5c44b8c8f9065e245ab920deaffacefddeec61616d77302c8906b5b'
$commandHash = '2359750301f4343fc30948c64f599d9c04903b42976b5d7c4e1ff8cf4887d02b'

foreach ($item in @(@($script, $scriptHash), @($settings, $settingsHash), @($command, $commandHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) { throw 'Local source missing.' }
    $actual = (Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $item[1]) { throw 'Local source hash changed; stop.' }
}
Write-Output 'STAGING_ERRORS_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/apply_ubuntu_staging_generic_errors.sh && test ! -L /home/huahua/apply_ubuntu_staging_generic_errors.sh && test ! -e /home/huahua/settings_staging_generic_errors.py && test ! -L /home/huahua/settings_staging_generic_errors.py && test ! -e /home/huahua/run_staging_task_generic_errors.py && test ! -L /home/huahua/run_staging_task_generic_errors.py && echo STAGING_ERRORS_UPLOAD_TARGETS_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote target exists or SSH preflight failed; no upload.' }

& scp $script "${remote}:/home/huahua/apply_ubuntu_staging_generic_errors.sh"
if ($LASTEXITCODE -ne 0) { throw 'Script upload failed; staging was not changed.' }
& scp $settings "${remote}:/home/huahua/settings_staging_generic_errors.py"
if ($LASTEXITCODE -ne 0) { throw 'Settings upload failed; staging was not changed.' }
& scp $command "${remote}:/home/huahua/run_staging_task_generic_errors.py"
if ($LASTEXITCODE -ne 0) { throw 'Command upload failed; staging was not changed.' }

$run = "cd /home/huahua && echo '$scriptHash  apply_ubuntu_staging_generic_errors.sh' | sha256sum -c - && echo '$settingsHash  settings_staging_generic_errors.py' | sha256sum -c - && echo '$commandHash  run_staging_task_generic_errors.py' | sha256sum -c - && bash -n apply_ubuntu_staging_generic_errors.sh && echo STAGING_ERRORS_REMOTE_FILES_VERIFIED && sudo -v && bash apply_ubuntu_staging_generic_errors.sh"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Staging generic-error change failed or SSH disconnected; inspect output before retrying.' }
Write-Output 'STAGING_ERRORS_WRAPPER_DONE'
