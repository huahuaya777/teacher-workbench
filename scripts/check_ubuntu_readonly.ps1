# 在用户自己的 Windows PowerShell 中运行；只读核查 Ubuntu 257。
# SSH 密码仅在本地终端输入，不写入脚本、命令历史或项目文件。
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$knownHosts = Join-Path $projectRoot 'data/ssh-known-hosts-review'
$expectedFingerprint = 'SHA256:KXlY/A9V7F3cr0bk+83HdtUiVXuZlFjq32W/3kADEFw'

if (-not (Test-Path -LiteralPath $knownHosts -PathType Leaf)) {
    throw '缺少已核对的临时 SSH 主机密钥文件；请让助手重新核对，勿跳过主机校验。'
}
$entries = @(Get-Content -LiteralPath $knownHosts | Where-Object { $_ -and -not $_.StartsWith('#') })
if ($entries.Count -ne 1 -or -not $entries[0].StartsWith('10.0.30.5 ssh-ed25519 ')) {
    throw 'SSH 主机密钥文件内容与预期不符；已停止连接。'
}
$fingerprintResult = & ssh-keygen -lf $knownHosts 2>&1
if ($LASTEXITCODE -ne 0 -or -not (($fingerprintResult -join ' ') -match [regex]::Escape($expectedFingerprint))) {
    throw 'SSH 主机指纹与 Ubuntu 控制台确认值不一致；已停止连接。'
}

$knownHostsOption = 'UserKnownHostsFile=' + ($knownHosts -replace '\\', '/')
$remoteCheck = @'
printf 'HOST='; hostname
printf 'USER='; id -un
. /etc/os-release; printf 'OS=%s\n' "$PRETTY_NAME"
printf 'CPU='; getconf _NPROCESSORS_ONLN
free -h | head -n 2
echo DISK_HOME
df -h "$HOME" | tail -n 1
echo INODES_HOME
df -i "$HOME" | tail -n 1
docker --version
docker compose version
if docker info >/dev/null 2>&1; then echo DOCKER_ACCESS=yes; else echo DOCKER_ACCESS=no; fi
if ss -H -ltn | grep -q ':18000'; then echo PORT_18000=busy; else echo PORT_18000=free; fi
if [ -e "$HOME/teacher-workbench-test" ]; then echo TEST_DIR=exists; else echo TEST_DIR=absent; fi
'@

Write-Host '主机指纹已在本机复核。下一步 SSH 可能提示输入 Ubuntu 用户 huahua 的密码；密码输入时不显示。'
& ssh -T -o StrictHostKeyChecking=yes -o $knownHostsOption -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=8 huahua@10.0.30.5 $remoteCheck
if ($LASTEXITCODE -ne 0) {
    throw '只读 SSH 核查未完成；不要据此判断服务器状态。'
}
