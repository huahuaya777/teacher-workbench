param([Parameter(Mandatory = $true)][string]$NasBackupName)

$ErrorActionPreference = 'Stop'
if ($NasBackupName -cnotmatch '^staging-phase2c-allowance-data-j33bqT1R-[0-9a-f]{12}$') {
    throw 'NAS backup name is not the expected fictional 2C snapshot.'
}

$remote = 'huahua@10.0.30.5'
$name = 'transfer_staging_phase2c_allowance_nas.py'
$expectedHash = '8c787c3bbdcae98c56eea8faff3ffee3363a855628c3220fdd9e148c8c854bdd'
$run = "cd /home/huahua && echo '$expectedHash  $name' | sha256sum -c - && sudo python3 $name import $NasBackupName"
& ssh -tt $remote $run
if ($LASTEXITCODE -ne 0) { throw 'NAS import failed or SSH disconnected; review output before retrying.' }
Write-Output 'STAGING_2C_NAS_IMPORT_WRAPPER_DONE'
