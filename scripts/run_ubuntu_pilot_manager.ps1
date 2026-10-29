param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$files = @{
    'create_ubuntu_pilot_manager.sh' = 'DD7998606C387EFBFBDDE3D23F55A1A58A958C8A820E106AC80401DFEBC17F08'
    'prepare_ubuntu_pilot_manager.py' = 'B18A6C0E2809603C573F58F6F327ACA3683E3B742DB72B09E54938727D321CAC'
}
foreach ($name in $files.Keys) {
    $path = Join-Path $PSScriptRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing script: $name" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $files[$name]) {
        throw "Script hash changed: $name"
    }
}
Write-Output 'PILOT_MANAGER_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$command = "cd /home/huahua && echo 'dd7998606c387efbfbdde3d23f55a1a58a958c8a820e106ac80401dfebc17f08  create_ubuntu_pilot_manager.sh' | sha256sum -c - && echo 'b18a6c0e2809603c573f58f6f327aca3683e3b742db72b09e54938727d321cac  prepare_ubuntu_pilot_manager.py' | sha256sum -c - && bash create_ubuntu_pilot_manager.sh"
& ssh -tt $remote $command
if ($LASTEXITCODE -ne 0) {
    throw 'Pilot manager bootstrap did not finish; report only non-sensitive final output.'
}
Write-Output 'PILOT_MANAGER_BOOTSTRAP_WRAPPER_DONE'
