param(
    [Parameter(Mandatory = $true)][string]$DriveLetter,
    [Parameter(Mandatory = $true)][string]$UsbFolder,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
if ($DriveLetter -cnotmatch '^[A-Za-z]$' -or
    $UsbFolder -cnotmatch '^teacher-workbench-pilot-escrow-Lx7aqLEz-[A-Za-z0-9]{8}$' -or
    $ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw '盘符、目录名或摘要格式不正确；停止'
}
$driveRoot = "$($DriveLetter):\"
$drive = [System.IO.DriveInfo]::new($driveRoot)
if (-not $drive.IsReady -or $drive.DriveType -eq [System.IO.DriveType]::Network -or
    $drive.DriveType -eq [System.IO.DriveType]::CDRom -or
    $driveRoot.TrimEnd('\') -ieq $env:SystemDrive) {
    throw '所选盘符不可用或不是合适的离线来源；停止'
}
$isUsb = $drive.DriveType -eq [System.IO.DriveType]::Removable
if (-not $isUsb) {
    try {
        $disk = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop | Get-Disk -ErrorAction Stop
        $isUsb = @($disk | Where-Object { $_.BusType -eq 'USB' }).Count -gt 0
    } catch { throw '无法确认所选盘符属于 USB 设备；停止' }
}
if (-not $isUsb) { throw '所选盘符不是 USB 设备；停止' }
$package = Join-Path (Join-Path $driveRoot $UsbFolder) 'teacher-workbench-pilot-escrow-Lx7aqLEz.json'
if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw 'U 盘内找不到指定加密包；停止' }
$actual = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -cne $ExpectedSha256) { throw 'U 盘加密包摘要不匹配；停止' }
Write-Output 'PILOT_USB_RETURN_SOURCE_SHA256_OK'

$randomBytes = New-Object byte[] 6
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
$suffix = -join ($randomBytes | ForEach-Object { $_.ToString('x2') })
$remoteDir = "/home/huahua/teacher-workbench-pilot-offline-escrow-return-$suffix"
$remoteFile = "$remoteDir/teacher-workbench-pilot-escrow-Lx7aqLEz.json"
& ssh -o StrictHostKeyChecking=yes huahua@10.0.30.5 "test ! -e $remoteDir && mkdir -m 700 $remoteDir"
if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 新接收目录创建失败；停止' }
& scp -o StrictHostKeyChecking=yes $package "huahua@10.0.30.5:$remoteFile"
if ($LASTEXITCODE -ne 0) { throw '加密包返回 Ubuntu 失败；停止' }
$remoteHashLine = & ssh -o StrictHostKeyChecking=yes huahua@10.0.30.5 "chmod 600 $remoteFile && sha256sum $remoteFile"
if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 接收包无法校验；停止' }
$remoteHash = ([string]$remoteHashLine).Split(' ')[0]
if ($remoteHash -cne $ExpectedSha256) { throw 'Ubuntu 接收包摘要不匹配；停止' }
Write-Output 'PILOT_USB_RETURN_PACKAGE_SHA256_OK'
Write-Output "PILOT_USB_RETURN_PACKAGE=$remoteFile"
