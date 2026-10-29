param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundleName = 'teacher-workbench-stage2c-guard-v3-source.tar.gz'
$scriptName = 'verify_ubuntu_staging_phase2c_guard_pg_v3.sh'
$bundleHash = '14537acaacc62f0584cd3d567028b158fe3d3cfab501128fdba6a5ba7b1105ca'
$scriptHash = 'd2cd1085f0dcdd0bbc35931bb17a0928ca836a57558744f8dc5fd104d5241366'
$bundle = Join-Path (Join-Path $project 'data\deploy') $bundleName
$script = Join-Path (Join-Path $project 'scripts') $scriptName

foreach ($item in @(@($bundle, $bundleHash), @($script, $scriptHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) {
        throw "Local input missing: $($item[0])"
    }
    $actual = (Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $item[1]) { throw "Local input hash changed: $($item[0])" }
}
Write-Output 'STAGING_2C_GUARD_V3_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/teacher-workbench-stage2c-guard-v3-source.tar.gz && test ! -L /home/huahua/teacher-workbench-stage2c-guard-v3-source.tar.gz && test ! -e /home/huahua/verify_ubuntu_staging_phase2c_guard_pg_v3.sh && test ! -L /home/huahua/verify_ubuntu_staging_phase2c_guard_pg_v3.sh && echo STAGING_2C_GUARD_V3_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote upload target exists or SSH preflight failed; nothing was uploaded.' }

& scp $bundle $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; isolated PostgreSQL test was not started.' }

$run = "cd /home/huahua && echo '$bundleHash  $bundleName' | sha256sum -c - && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_2C_GUARD_V3_REMOTE_INPUTS_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Isolated PostgreSQL test failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_GUARD_V3_PG_WRAPPER_DONE'
