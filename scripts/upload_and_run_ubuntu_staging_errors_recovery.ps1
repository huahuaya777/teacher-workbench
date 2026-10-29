param([switch]$LocalCheckOnly)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$files = [ordered]@{
    'backup_ubuntu_staging_errors.sh' = '17706c1caaa32807079ed22df19a5c4b9801719f1659a2aae022099a07e88c6f'
    'restore_ubuntu_staging_errors.sh' = 'c10b5f255a7563ff957b492bd6423776f525040c3ee031c23e43abc42027a60f'
    'backup_restore_ubuntu_staging_errors.sh' = 'efec9c8b18f3dfd75d46aab5d7999e38f6a28bb552eb3a5fe5d097fa750a6439'
}

foreach ($entry in $files.GetEnumerator()) {
    $path = Join-Path (Join-Path $project 'scripts') $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Local script missing: $($entry.Key)"
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.Value) {
        throw "Local script hash changed: $($entry.Key)"
    }
    if ([System.IO.File]::ReadAllBytes($path) -contains 13) {
        throw "Script must use LF newlines: $($entry.Key)"
    }
}
Write-Output 'STAGING_ERRORS_RECOVERY_LOCAL_HASHES_OK'
if ($LocalCheckOnly) { return }

$remote = 'huahua@10.0.30.5'
$preflight = 'test $(hostname) = teacher-workbench && test $(id -un) = huahua && test ! -e /home/huahua/backup_ubuntu_staging_errors.sh && test ! -L /home/huahua/backup_ubuntu_staging_errors.sh && test ! -e /home/huahua/restore_ubuntu_staging_errors.sh && test ! -L /home/huahua/restore_ubuntu_staging_errors.sh && test ! -e /home/huahua/backup_restore_ubuntu_staging_errors.sh && test ! -L /home/huahua/backup_restore_ubuntu_staging_errors.sh && echo STAGING_ERRORS_RECOVERY_UPLOAD_TARGETS_CLEAR'
& ssh -tt $remote $preflight
if ($LASTEXITCODE -ne 0) { throw 'Remote upload preflight failed; no recovery run started.' }

foreach ($name in $files.Keys) {
    $path = Join-Path (Join-Path $project 'scripts') $name
    & scp $path ('{0}:/home/huahua/' -f $remote)
    if ($LASTEXITCODE -ne 0) { throw "SCP failed for $name; recovery was not started." }
}

$checks = foreach ($entry in $files.GetEnumerator()) {
    "echo '$($entry.Value)  $($entry.Key)' | sha256sum -c -"
}
$remoteCommand = 'cd /home/huahua && ' + ($checks -join ' && ') +
    ' && bash -n backup_ubuntu_staging_errors.sh && bash -n restore_ubuntu_staging_errors.sh && bash -n backup_restore_ubuntu_staging_errors.sh && echo STAGING_ERRORS_RECOVERY_UPLOAD_VERIFIED && sudo -v && bash backup_restore_ubuntu_staging_errors.sh'
& ssh -tt $remote $remoteCommand
if ($LASTEXITCODE -ne 0) {
    throw 'Post-fix backup or isolated restore failed; review the last non-sensitive output before any retry.'
}
Write-Output 'STAGING_ERRORS_RECOVERY_WRAPPER_DONE'
