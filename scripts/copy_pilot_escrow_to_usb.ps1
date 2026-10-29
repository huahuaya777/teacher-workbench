param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$DriveLetter
)

$ErrorActionPreference = 'Stop'
if ($PackagePath -cnotmatch '^/home/huahua/teacher-workbench-pilot-offline-escrow-packages/package-([A-Za-z0-9]{8})/teacher-workbench-pilot-escrow-Lx7aqLEz[.]json$') {
    throw '试点加密包路径不符合固定格式；停止'
}
$packageSuffix = $Matches[1]
if ($ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$' -or $DriveLetter -cnotmatch '^[A-Za-z]$') {
    throw '摘要或盘符格式不正确；停止'
}
$driveRoot = "$($DriveLetter):\"
$drive = [System.IO.DriveInfo]::new($driveRoot)
if (-not $drive.IsReady -or $drive.DriveType -eq [System.IO.DriveType]::Network -or
    $drive.DriveType -eq [System.IO.DriveType]::CDRom -or
    $driveRoot.TrimEnd('\') -ieq $env:SystemDrive) {
    throw '所选盘符不可用或不是合适的离线目标；停止'
}
$isUsb = $drive.DriveType -eq [System.IO.DriveType]::Removable
if (-not $isUsb) {
    try {
        $disk = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop | Get-Disk -ErrorAction Stop
        $isUsb = @($disk | Where-Object { $_.BusType -eq 'USB' }).Count -gt 0
    } catch { throw '无法确认所选盘符属于 USB 设备；停止' }
}
if (-not $isUsb) { throw '所选盘符不是 USB 设备；停止' }
$targetDir = Join-Path $driveRoot "teacher-workbench-pilot-escrow-Lx7aqLEz-$packageSuffix"
if (Test-Path -LiteralPath $targetDir) { throw 'U 盘目标目录已存在；停止，避免覆盖' }
New-Item -ItemType Directory -Path $targetDir -ErrorAction Stop | Out-Null
$targetFile = Join-Path $targetDir 'teacher-workbench-pilot-escrow-Lx7aqLEz.json'
& scp -o StrictHostKeyChecking=yes "huahua@10.0.30.5:$PackagePath" $targetFile
if ($LASTEXITCODE -ne 0) { throw '加密包复制失败；保留目标目录供检查，不自动重试' }
$actual = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -cne $ExpectedSha256) { throw 'U 盘加密包摘要不匹配；停止' }
Write-Output 'PILOT_USB_ENCRYPTED_PACKAGE_SHA256_OK'
Write-Output "PILOT_USB_PACKAGE_PATH=$targetFile"
