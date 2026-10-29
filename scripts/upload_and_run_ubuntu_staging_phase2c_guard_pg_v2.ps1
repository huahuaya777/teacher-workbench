param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundleName = 'teacher-workbench-stage2c-guard-v2-source.tar.gz'
$scriptName = 'verify_ubuntu_staging_phase2c_guard_pg_v2.sh'
$bundleHash = 'ee34113e8aa9fe17554b0c19d70f02701c56f8a016a8ce0a7cbed42433e830cc'
$scriptHash = 'fafeee74194b46d30cbfc232656ba0053317cd2b2281215a9c605552739e8f9c'
$bundle = Join-Path (Join-Path $project 'data\deploy') $bundleName
$script = Join-Path (Join-Path $project 'scripts') $scriptName

foreach ($item in @(@($bundle, $bundleHash), @($script, $scriptHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) {
        throw "Local input missing: $($item[0])"
    }
    $actual = (Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $item[1]) { throw "Local input hash changed: $($item[0])" }
}
Write-Output 'STAGING_2C_GUARD_V2_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/teacher-workbench-stage2c-guard-v2-source.tar.gz && test ! -L /home/huahua/teacher-workbench-stage2c-guard-v2-source.tar.gz && test ! -e /home/huahua/verify_ubuntu_staging_phase2c_guard_pg_v2.sh && test ! -L /home/huahua/verify_ubuntu_staging_phase2c_guard_pg_v2.sh && echo STAGING_2C_GUARD_V2_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote upload target exists or SSH preflight failed; nothing was uploaded.' }

& scp $bundle $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; isolated PostgreSQL test was not started.' }

$run = "cd /home/huahua && echo '$bundleHash  $bundleName' | sha256sum -c - && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_2C_GUARD_V2_REMOTE_INPUTS_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL test failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_GUARD_V2_PG_WRAPPER_DONE'
