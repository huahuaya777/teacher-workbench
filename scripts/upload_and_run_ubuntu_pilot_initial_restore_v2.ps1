param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$name = 'restore_ubuntu_pilot_initial_v2.sh'
$expectedHash = '56bced5b354c109672c057266d42e1f510d68b394f3017862a7ecc80527307da'
$path = Join-Path $PSScriptRoot $name
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Pilot restore v2 script missing.' }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Pilot restore v2 script changed; review before upload.'
}
Write-Output 'PILOT_RESTORE_V2_LOCAL_HASH_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
& ssh -tt $remote 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/restore_ubuntu_pilot_initial_v2.sh && test ! -L /home/huahua/restore_ubuntu_pilot_initial_v2.sh && test -f /home/huahua/teacher-workbench-pilot-restore-Wz0wCERi/db.env && test -f /home/huahua/teacher-workbench-pilot-keyring-RWz0wCER/v1.key && echo PILOT_RESTORE_V2_UPLOAD_TARGET_CLEAR'
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore v2 target or prepared state changed; stop.' }
& scp $path 'huahua@10.0.30.5:/home/huahua/'
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore v2 upload failed; stop.' }

$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && bash -n $name && bash $name"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'Pilot restore v2 failed or SSH disconnected; inspect non-sensitive markers before retry.' }
Write-Output 'PILOT_RESTORE_V2_WRAPPER_DONE'
