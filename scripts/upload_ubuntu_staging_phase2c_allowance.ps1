param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$backupName = 'backup_ubuntu_staging_phase2c_allowance.sh'
$restoreName = 'restore_ubuntu_staging_phase2c_allowance.sh'
$expected = @{
    $backupName = 'dec1728ae8ab982164f2c48eb80db4f39346a2948831c04a4dc73e4ae2dc58d1'
    $restoreName = 'a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d'
}

foreach ($name in @($backupName, $restoreName)) {
    $path = Join-Path (Join-Path $project 'scripts') $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Local script missing: $name"
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected[$name]) {
        throw "Local script hash changed: $name"
    }
}
Write-Output 'STAGING_2C_UPLOAD_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/backup_ubuntu_staging_phase2c_allowance.sh && test ! -L /home/huahua/backup_ubuntu_staging_phase2c_allowance.sh && test ! -e /home/huahua/restore_ubuntu_staging_phase2c_allowance.sh && test ! -L /home/huahua/restore_ubuntu_staging_phase2c_allowance.sh && echo STAGING_2C_UPLOAD_TARGET_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'SSH preflight failed; stop before upload.' }

Push-Location -LiteralPath $project
try {
    & scp '.\scripts\backup_ubuntu_staging_phase2c_allowance.sh' '.\scripts\restore_ubuntu_staging_phase2c_allowance.sh' 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'SCP failed; stop without running verification or backup.' }
} finally {
    Pop-Location
}

$verify = "cd /home/huahua && echo 'dec1728ae8ab982164f2c48eb80db4f39346a2948831c04a4dc73e4ae2dc58d1  backup_ubuntu_staging_phase2c_allowance.sh' | sha256sum -c - && echo 'a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d  restore_ubuntu_staging_phase2c_allowance.sh' | sha256sum -c - && bash -n backup_ubuntu_staging_phase2c_allowance.sh restore_ubuntu_staging_phase2c_allowance.sh && echo STAGING_2C_ALLOWANCE_SCRIPTS_UPLOAD_VERIFIED"
& ssh -tt $remote $verify
if ($LASTEXITCODE -ne 0) { throw 'Remote script verification failed; do not run backup.' }
