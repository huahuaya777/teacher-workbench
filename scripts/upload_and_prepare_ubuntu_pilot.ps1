param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$expected = [ordered]@{
    'compose.pilot.yaml' = '19dd9f04a83d258c77465d2ccae348bd39d84f372f41bca6eb2d4c38b58fc7e1'
    'Caddyfile.pilot' = '65043844312f9454833eece8df8c9abac56765430796b0ef84401ec4a13afe98'
    'check_pilot_env.py' = '50eaf5efb8101a869342fa7e0ba20ad443c35a77c04656e629739b39fba3f2c0'
    'prepare_ubuntu_pilot_config.sh' = 'de7d44dbb9e355dc60c3c80da11c02ba3213d5428b2a31eced56150cc5704e18'
    'stop_ubuntu_pilot.sh' = '7623e410ab59498cc4d3c5ca67aa818a645238fd5aaf7ae9fe7285a918ca2f30'
}
$paths = @{
    'compose.pilot.yaml' = (Join-Path $PSScriptRoot '..\compose.pilot.yaml')
    'Caddyfile.pilot' = (Join-Path $PSScriptRoot '..\config\Caddyfile.pilot')
    'check_pilot_env.py' = (Join-Path $PSScriptRoot 'check_pilot_env.py')
    'prepare_ubuntu_pilot_config.sh' = (Join-Path $PSScriptRoot 'prepare_ubuntu_pilot_config.sh')
    'stop_ubuntu_pilot.sh' = (Join-Path $PSScriptRoot 'stop_ubuntu_pilot.sh')
}
foreach ($name in $expected.Keys) {
    $path = $paths[$name]
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing local file: $name" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected[$name]) {
        throw "Local file changed: $name"
    }
}
Write-Output 'PILOT_CONFIG_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$names = @($expected.Keys)
$absent = ($names | ForEach-Object { "test ! -e /home/huahua/$_ && test ! -L /home/huahua/$_" }) -join ' && '
& ssh -tt $remote "test `$(hostname) = teacher-workbench && test `$(id -un) = huahua && $absent && echo PILOT_CONFIG_UPLOAD_TARGET_CLEAR"
if ($LASTEXITCODE -ne 0) { throw 'Remote target exists or SSH failed; stop.' }

$localFiles = @($names | ForEach-Object { $paths[$_] })
& scp @localFiles 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot config upload failed; stop.' }

$checks = ($names | ForEach-Object { "echo '$($expected[$_])  $_' | sha256sum -c -" }) -join ' && '
$run = "cd /home/huahua && $checks && bash -n prepare_ubuntu_pilot_config.sh && bash prepare_ubuntu_pilot_config.sh"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot config preparation failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_CONFIG_PREPARE_WRAPPER_DONE'
