param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundleName = 'teacher-workbench-stage2c-guard-v3-source.tar.gz'
$scriptName = 'build_ubuntu_staging_call_usage_offline.sh'
$bundleHash = '14537acaacc62f0584cd3d567028b158fe3d3cfab501128fdba6a5ba7b1105ca'
$scriptHash = '29b33d3747b698a313fc5bc8d60c9b181a9ef234d46aeec86e6f50e828436f51'
$bundle = Join-Path (Join-Path $project 'data\deploy') $bundleName
$script = Join-Path (Join-Path $project 'scripts') $scriptName

foreach ($item in @(@($bundle, $bundleHash), @($script, $scriptHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) {
        throw "Local input missing: $($item[0])"
    }
    $actual = (Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $item[1]) { throw "Local input hash changed: $($item[0])" }
}
Write-Output 'STAGING_CALL_USAGE_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = "test `$(hostname) = teacher-workbench && test `$(id -un) = huahua && test ! -L /home/huahua/$bundleName && test -f /home/huahua/$bundleName && echo '$bundleHash  $bundleName' | (cd /home/huahua && sha256sum -c -) && test ! -e /home/huahua/$scriptName && test ! -L /home/huahua/$scriptName && echo STAGING_CALL_USAGE_UPLOAD_TARGET_CLEAR"
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote source archive or upload target failed preflight; nothing was uploaded.' }

& scp $script "${remote}:/home/huahua/"
if ($LASTEXITCODE -ne 0) { throw 'SCP failed; offline image build was not started.' }

$run = "cd /home/huahua && echo '$scriptHash  $scriptName' | sha256sum -c - && bash -n $scriptName && echo STAGING_CALL_USAGE_REMOTE_SCRIPT_VERIFIED && sudo -v && bash $scriptName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Offline image build failed or SSH disconnected; inspect output before retrying.' }
Write-Output 'STAGING_CALL_USAGE_OFFLINE_BUILD_WRAPPER_DONE'
