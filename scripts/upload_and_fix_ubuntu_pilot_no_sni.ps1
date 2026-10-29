param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$caddyPath = Join-Path $PSScriptRoot '..\config\Caddyfile.pilot'
$fixPath = Join-Path $PSScriptRoot 'fix_ubuntu_pilot_no_sni.sh'
$caddyHash = '65043844312f9454833eece8df8c9abac56765430796b0ef84401ec4a13afe98'
$fixHash = '1ab88f22d2f1f6ae1a5ca86cbb121602bb9f7e4ca63677572682544853dc552f'
foreach ($item in @(@($caddyPath, $caddyHash), @($fixPath, $fixHash))) {
    if (-not (Test-Path -LiteralPath $item[0] -PathType Leaf)) { throw 'Pilot fix file missing.' }
    if ((Get-FileHash -LiteralPath $item[0] -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item[1]) {
        throw 'Pilot fix file changed; review before upload.'
    }
}
Write-Output 'PILOT_NO_SNI_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/Caddyfile.pilot.no-sni-fix && test ! -L /home/huahua/Caddyfile.pilot.no-sni-fix && test ! -e /home/huahua/fix_ubuntu_pilot_no_sni.sh && test ! -L /home/huahua/fix_ubuntu_pilot_no_sni.sh && grep -Fxq PILOT_STARTING /home/huahua/teacher-workbench-pilot/STATE && echo PILOT_NO_SNI_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot fix target not clear or state changed; stop.' }

& scp $caddyPath 'huahua@10.0.30.5:/home/huahua/Caddyfile.pilot.no-sni-fix'
if ($LASTEXITCODE -ne 0) { throw 'Pilot Caddy candidate upload failed; stop.' }
& scp $fixPath 'huahua@10.0.30.5:/home/huahua/fix_ubuntu_pilot_no_sni.sh'
if ($LASTEXITCODE -ne 0) { throw 'Pilot repair script upload failed; stop.' }

$run = "cd /home/huahua && echo '$caddyHash  Caddyfile.pilot.no-sni-fix' | sha256sum -c - && echo '$fixHash  fix_ubuntu_pilot_no_sni.sh' | sha256sum -c - && bash -n fix_ubuntu_pilot_no_sni.sh && bash fix_ubuntu_pilot_no_sni.sh"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot gateway repair failed; inspect non-sensitive output before any retry.' }
Write-Output 'PILOT_NO_SNI_REPAIR_WRAPPER_DONE'
