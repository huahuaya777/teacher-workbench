param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundleName = 'teacher-workbench-stage2c-guard-source.tar.gz'
$scriptName = 'verify_ubuntu_staging_phase2c_guard_pg.sh'
$bundleHash = 'cb133427b8f693582747d708cd4d21f5199f8328da7731e2ee64a01ae4a0799e'
$scriptHash = '8c5535e6be10e0ac4d7ede0cd713f9a9d058a0be674b3fb80544ed3f78beec26'
$bundle = Join-Path (Join-Path $project 'data\deploy') $bundleName
$script = Join-Path (Join-Path $project 'scripts') $scriptName

foreach ($item in @(@($bundle, $bundleHash), @($script, $scriptHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) {
        throw "Local input missing: $($item[0])"
    }
    $actual = (Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $item[1]) { throw "Local input hash changed: $($item[0])" }
}
Write-Output 'STAGING_2C_GUARD_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/teacher-workbench-stage2c-guard-source.tar.gz && test ! -L /home/huahua/teacher-workbench-stage2c-guard-source.tar.gz && test ! -e /home/huahua/verify_ubuntu_staging_phase2c_guard_pg.sh && test ! -L /home/huahua/verify_ubuntu_staging_phase2c_guard_pg.sh && echo STAGING_2C_GUARD_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote upload target exists or SSH preflight failed; nothing was uploaded.' }

& scp $bundle $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; isolated PostgreSQL test was not started.' }

$run = "cd /home/huahua && echo '$bundleHash  $bundleName' | sha256sum -c - && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_2C_GUARD_REMOTE_INPUTS_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL test failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_GUARD_PG_WRAPPER_DONE'
