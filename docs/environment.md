# 服务器与网络现场基线

**2026-10-30 Ubuntu 开发机 10.0.30.7 迁移验收：**目标主机 `huahua-Standard-PC-i440FX-PIIX-1996`，Ubuntu 26.04 x86_64，Git 2.53.0、Python 3.14.4；迁移前约 22 GB 可用。SSH 现可登录，开发目录 `/home/huahua/projects/teacher-workbench` 已建并限制为用户 `huahua`。GitHub 私有远端已设置，但目标机 `git ls-remote` 因无 HTTPS 认证失败；SSH 检查未找到 `codex` 命令，用户所述 Codex 桌面登录须在图形界面核验。正式运行站 `10.0.30.5` 不在本次操作范围。

**2026-10-30 新开发机（用户提供与助手连通性检查）：**用户指定 Ubuntu `10.0.30.7`、账号 `huahua`，称已安装并登录 Codex；助手尚未登录该机，操作系统版本和工具版本待核。Windows EasyTier 接口 `et_6_kfsc` 可 ping 目标，TCP 22 失败；从 `10.0.30.5` 可 ping 目标但 22 端口被拒绝。该机规划为后续开发环境，不替换 `10.0.30.5` 线上服务。密码不写入项目文档。

**2026-10-29 私网限定版最新现场（助手直连 Ubuntu 257）：**Web/worker 均运行于 `sha256:1e2906b9799a04638c258eaa585e047abe081608172936e0cd77677f5c870e88`；私网登录页显示 EasyTier 说明，Windows 经 EasyTier 请求 `https://10.0.30.5:18443/login/` 为 HTTP 200、TLS 验证码 0。当前镜像配对快照 `backup-pilot-37aXRxFX`/`escrow-37aXRxFX` 已转存 NAS 十文件副本 `pilot-scheduled-data-37aXRxFX-f0a7fd43c60c`，只读导回并在同机新网络/卷恢复通过，恢复 DB/Redis 已停。三项 timer enabled/active，备份健康通过。旧预发布登录页仍 200；无域名或 Cloudflare。上一条为文案更新前的现场状态。

**2026-10-29 私网限定版现场（助手直连 Ubuntu 257）：**`10.0.30.5:18443` 的试点项目被用户授权作为当前私网正式使用入口，沿用现有五服务和独立数据卷；Web/worker 实际镜像均为 `sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64` 且运行，DB/Redis 健康。真实教师 `huahua` 的模型配置 1、调用额度 10/已用 4/预留 0，任务 3 失败、1 完成。新配对快照 `backup-pilot-kfA4vmDj` 与 `escrow-kfA4vmDj`，NAS 数据副本 `pilot-scheduled-data-kfA4vmDj-8885b673fb19`，只读导回和同机新卷恢复均通过；恢复 DB/Redis 已停。三项备份 timer enabled/active，备份健康检查通过。当前 Windows 经 EasyTier 访问登录页 HTTP 200、TLS 验证码 0。原预发布/旧测试栈保留，未配置域名或 Cloudflare，其他设备与异机灾备未验证。

**2026-10-29 用户 WPS 现场补充：**用户确认重新下载的教师卷“公式可编辑”。这是用户设备上的实际操作反馈；未据此推断服务器状态变化或打印效果。

**2026-10-29 用户 WPS 现场补充：**用户对重新下载的教师答案版 Word 反馈“显示正常”，结合上一轮确认的“答案内容正常”，仅证明该用户设备上的教师卷显示和内容验收；未在本轮重新连接 Ubuntu，也未获得公式编辑或打印反馈。

**2026-10-29 用户浏览器验收补充：**用户反馈教师卷答案内容正常。这是用户对内容的现场核对，不代表本轮再次直连服务器，也不包含 WPS 公式编辑或打印效果确认；服务器技术状态沿用下条助手直连结果。

**2026-10-29 07:54（Asia/Shanghai）助手直连 Ubuntu 257：**教师答案公式修复后试点 Web/worker 切换至镜像 `sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64`，切换脚本验证试点 HTTPS、旧预发布登录页和新 CSS；当前 Windows 经 EasyTier 单独请求 `https://10.0.30.5:18443/login/` 得 200、TLS 证书链验证码 0。只读在线审计：真实教师 `huahua` 额度上限 10/已用 4/预留 0，四条任务依次失败、失败、失败、完成；旧三个调用结果未知，最新一条完成；队列及处理中为 0。切换前配对快照 `backup-pilot-LSlJR5do`/`escrow-LSlJR5do` 与 NAS 十数据文件副本 `pilot-scheduled-data-LSlJR5do-4c549aea2551` 成功；此 NAS 副本尚未只读导回或独立恢复。保存草稿 1 版本的预览和 Word 结构审计通过，用户 WPS 与答案正确性待验证。

**2026-10-29 07:35（Asia/Shanghai）助手直连 Ubuntu 257：**试点 Web/worker 均为精简输出镜像 `sha256:7f81c32b41368bf26c5f85a9f4fd602ee6393360ba1f4a8f8b0a75d93a675bf5` 且运行；进程级旧上限 1500、成员 Qwen 上限 6000。真实账号 `huahua` 有加密配置 1 条，额度上限 10/已用 3/预留 0；任务 3 条失败、调用记录 3 条未知。试点 HTTPS 与旧预发布登录页 200；Windows EasyTier HTTPS 登录页 200、证书链验证码 0。切换前配对快照 `backup-pilot-XgXQqIBU`/`escrow-XgXQqIBU` 和 NAS 十数据文件副本 `pilot-scheduled-data-XgXQqIBU-1c839ac81a6b` 完整校验通过；该 NAS 新副本尚未只读导回或独立恢复。三个备份 timer enabled/active。第 3 次失败来源于用户截图；本版模型调用尚未由用户复验。

**2026-10-29 01:50（Asia/Shanghai）助手直连 Ubuntu 257：**试点 Web 与成员任务 worker 现均为 `sha256:7d85997d168c880e059069b537d5a3b9029b3b8b20682968d98fb408b8fda34f`；worker 只读输出成员专用上限 3000 tokens，旧进程级上限 1500。试点 HTTPS 与旧预发布登录页均 200；真实账号 `huahua` 的加密配置 1 条、额度上限 10/已用 2/预留 0、失败任务 2/未知调用 2，在切换前后保持一致。最新切换前配对快照 `backup-pilot-BQ9zzu8R`、分离托管 `escrow-BQ9zzu8R`；NAS 数据副本 `pilot-scheduled-data-BQ9zzu8R-0dac6332a847` 已转存，但这份新副本尚未只读导回或独立恢复，上一份 `OVALSQWU` 的 NAS 副本已完成独立新卷恢复。付费调用成功仍待用户复验。

**2026-10-28 21:09（Asia/Shanghai）助手直连 Ubuntu 257：**试点 EasyTier HTTPS `10.0.30.5:18443` 的 Web/worker 当前镜像均为 `sha256:8e8bda29bac804dd58a0948b49074242153aa783660d8a8cca6d3eb34a89dba6`，五容器含成员任务 worker；试点和原预发布登录页 HTTP 200。当前真实账号 `huahua` 已由用户在网页创建并设置个人百炼配置；只读审计显示两条失败任务、两次未知调用、上限 10/已用 2。候选错误分类热修复已上线，但尚无修复后新生成任务结果。最新配对快照 `backup-pilot-OVALSQWU`、NAS 数据副本 `pilot-scheduled-data-OVALSQWU-9dd23f3d010b`、只读导回及同机新卷恢复均现场通过；分离托管未复制到 NAS。用户提供的百炼汇总截图显示两次 `qwen-flash` 调用记录，不能据此确认具体两次任务的厂商处理结果。

**2026-10-28 19:55（Asia/Shanghai）助手直连 Ubuntu 257：**服务器当地日期仍为 10 月 28 日。试点本机备份、NAS 转存及本机健康三个 timer 均 enabled/active；三项最近 service 的 `Result=success`、`ExecMainStatus=0`。下次运行依次为 2026-10-29 03:36:52、04:31:54、08:03:21。约 20:02 又以只读 NFS 挂载核对旧 NAS 副本完整性并成功卸载；未见证明日自然执行或产生新副本。

**2026-10-28 08:01（Asia/Shanghai）助手直连 Ubuntu 257：**本机备份健康 timer 首次自然触发于 08:01:57，service success/退出 0，日志确认最新配对备份和备份 timer 正常；下次健康检查 2026-10-29 08:03:21。NAS 转存 timer enabled/active，下次 2026-10-29 04:31:54。此时最新仍为固定首份本机快照；没有宣称今日生成第二份或明日自动 NAS 写入已通过。

**2026-10-28 07:54（Asia/Shanghai）助手直连 Ubuntu 257：**用户本轮授权每日 NAS 转存后，root 固定范围策略文件 600、转存程序 700 已安装，service 首次受控运行 success/状态 0；日志显示从最新本机备份核对已存在 NAS 副本后卸载挂载，未产生新目录。转存 timer enabled/active，计划次日 04:30 后自然运行。当前 Windows 经 EasyTier 严格 TLS 访问试点登录页仍 HTTP 200、证书验证码 0。后续新快照的首次自动写入与恢复未测。

**2026-10-28 07:26（Asia/Shanghai）助手直连 Ubuntu 257：**本机备份 timer 在 03:34 后自然触发，03:35:02 以 success/状态 0 结束，但因最近成功快照不足 18 小时，日志是 `PILOT_SCHEDULED_BACKUP_RECENT_SUCCESS_SKIP`。`LAST_SUCCESS` 仍为 2026-10-27T13:55:11Z 的 `backup-pilot-2kgUgmXV`；只读健康检查及容量审计通过（完整 1、未完成 0、孤立托管 0）。08:00 健康 timer 当时尚未触发。试点四容器运行，Django 迁移已至 `0008`；`check --deploy` 仅报 HSTS 子域和 preload 两项预期警告。当前 Windows 经 EasyTier 请求 HTTPS 登录页返回 200 且证书验证码 0。用于未来复制的 root 授权策略文件不存在，动态脚本只读预检通过，未发生 NAS 写入。

**2026-10-27 22:53（Asia/Shanghai）助手直连 Ubuntu 257 只读容量核对：**备份 timer 下次显示 2026-10-28 03:34:44，健康 timer 下次 08:01:13，均 active；两项服务最近 `Result=success`、`ExecMainStatus=0`。试点 HTTPS 登录页返回 200。root 专用备份目录里的首份数据快照约 278 MiB，配对托管约 28 KiB；新增逐文件只读审计精确统计快照 291,287,453 字节、托管文件 4,383 字节、完整 1、未完成 0、孤立托管 0，根分区可用 46,791,716,864 字节。估算容量只反映这一刻，不证明明日定时运行结果。

**2026-10-27 助手直连 Ubuntu 257 的首份定时快照 NAS 现场：**用户明确授权 `backup-pilot-2kgUgmXV` 固定十个数据文件后，助手把它们写入 `10.0.30.6:/teacher-workbench-backup/pilot-scheduled-data-2kgUgmXV-a557dddc7c8e` 新目录，逐项哈希通过；随后只读挂载导回十二文件至 `/var/lib/teacher-workbench-pilot-scheduled/nas-import-pilot-scheduled-data-2kgUgmXV-a557dddc7c8e`，双清单通过，两次临时 NFS 挂载均卸载。配对此前从 U 盘返回的分离托管，在 `10.251.34.0/28` 新内部网络和新卷完成两名虚构账号、一份 Word、下载哈希及跨账号访问拒绝验证；恢复目录 `/var/lib/teacher-workbench-pilot-scheduled/nas-restore-a557dddc7c8e`，恢复 DB/Redis 停止、卷保留。原试点和预发布登录页 HTTP 200，两项 timer active，根分区约 44G 可用。初次 `copy` 曾因旧授权不足被自动审批在 SSH 前拒绝；该状态已由用户的新固定范围授权和上述成功结果取代。每日自动 NAS 复制与空白主机重建仍未验证。

**2026-10-27 助手直连 Ubuntu 257 试点定时备份现场：**主机时区 Asia/Shanghai、systemd 259；root 专用 service/timer 安装并启用，每日 03:30 起随机延迟最多 10 分钟。首次完整备份生成 `/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-2kgUgmXV` 和分离的 `.../escrow/escrow-2kgUgmXV`，`Result=success`，健康检查配对文件及 timer 均通过；第二次运行因最近成功标记跳过。试点 HTTPS 与原预发布登录页在备份脚本恢复后均为 200。这里只是同机本地定时备份，不代表 NAS 定时转存、告警或异机恢复。

**2026-10-27 首个定时快照恢复现场：**上述新快照及同机分离托管在 `10.251.33.0/28` 新内部网络与新卷完成独立恢复，账号、虚构 Word、下载哈希、CA 及跨账号拒绝通过。恢复目录 `/var/lib/teacher-workbench-pilot-scheduled/restore-2kgUgmXV`；随后助手再次只读确认测试 DB/Redis 均 `false`（已停止）、timer `active`、最新配对备份健康，根分区 63G 中可用约 44G；在线双站登录页仍 HTTP 200。此证据限原 Ubuntu 上已缓存镜像。

**2026-10-27 健康检测定时器现场：**服务器 systemd 又启用每日 08:00 的 `teacher-workbench-pilot-backup-health.timer`，首次 `teacher-workbench-pilot-backup-health.service` 运行成功，timer `active`。检查对象为本机最新配对快照及备份 timer；无外部消息或异机监控。

**状态：用户提供的现场结果，以及助手在已授权范围对 Ubuntu 257 和当前 Windows 用户所做的检查。** `10.0.30.5:18443` 的独立 HTTPS 试点技术栈已启动，原预发布仍运行；试点未接真实账号、资料或 Key，不是正式发布。2026-10-27 用户报告固定指纹 CA 已安装到其 Windows 当前用户根库，助手以该用户身份只读复核，并使用系统证书信任访问试点登录页取得 HTTP 200、TLS 验证码 0。用户本轮澄清这台设备经 EasyTier 访问同一 HTTPS 地址并成功登录、退出；其他客户端和物理家外位置尚无单独反馈。

**2026-10-27 最新双账号 NAS/USB 恢复现场：**按用户新固定快照授权，助手把 `backup-pilot-YvI69NlE` 十个数据文件写入 `10.0.30.6:/teacher-workbench-backup/pilot-two-users-data-YvI69NlE-a9f7376e478c`，只读导回十二文件至 Ubuntu 私有新目录，两次临时 NAS 挂载均卸载。与此前 U 盘返回的独立密钥/CA 托管在 `10.251.32.0/28` 新内部网络与新卷恢复两名虚构账号和一份 Word，内容、下载及权限拒绝通过；恢复 DB/Redis 已停、卷保留。在线试点 HTTPS 与原预发布登录页仍 200；未触及 PVE、LXC 140、空白主机或真实教学数据。

**2026-10-27 在线双账号验收后本机快照：**用户普通成员浏览器确认未见管理账号 Word、直接下载原链接显示 404；助手直接 SSH 只读确认资料 ID=1、所有者 ID=1，在线账号数为 2。新本机配对快照 `backup-pilot-YvI69NlE` 与同机分离托管通过，新网络/新卷独立恢复两账号、资料和跨账号拒绝通过，测试容器已停、卷保留；在线试点和原预发布登录页仍 200。旧 NAS 副本不含第二账号；新 NAS 来源恢复结果见上方最新记录。

**2026-10-27 试点虚构文件与 NAS 最新现场：**用户在当前 EasyTier 客户端确认虚构 Word 上传、刷新列表及下载打开正常。助手对更新后的试点执行本机停写快照和隔离新卷恢复，再经用户针对固定新快照的授权，把十个数据文件转存到 `10.0.30.6:/teacher-workbench-backup/pilot-material-data-6A76GMeO-08582087b8f1` 并只读导回；配对已从 U 盘返回的密钥/CA 托管，在原 Ubuntu 独立 `10.251.30.0/28` Docker 网络和新卷恢复，资料文件及下载响应哈希通过。随后仅启动该恢复副本的 DB/Redis，以事务性虚构第二账号验证资料列表不可见、下载 404、成员页 403，回滚并再次停止恢复容器。在线 `10.0.30.5:18443` 与原预发布 `127.0.0.1:18002` 登录页仍为 200。NAS 两次临时挂载均卸载，恢复卷保留；未涉及 PVE、LXC 140 或空白主机。

**2026-10-27 最新现场：**用户终端报告 U 盘返回的固定试点托管包解密、密钥/CA/环境指纹配对通过。助手直接 SSH 到 Ubuntu 257，将该托管与此前 `10.0.30.6:/teacher-workbench-backup` 只读导回的固定虚构账号数据配对，在新 Docker 网络及卷恢复成功；在线 `10.0.30.5:18443` 和本机预发布 `127.0.0.1:18002` 登录页均保持 HTTP 200。此次恢复仍在原 Ubuntu，不证明服务器丢失后的异机重建；未触及 PVE、LXC 140 或其他设备。

## 虚拟机与系统

**2026-10-27 离线托管临时状态：**用户在可见终端成功从固定试点 escrow 创建密码保护的加密包 `package-KqF0If9u`；助手 SSH 只读复核包文件权限 600、不是软链接且 SHA-256 为 `ed664283c6b78a2f953524c2ddf88ab9ad983e783289abbc493cbb764242c93a`。当前 Windows 环境仅识别 C:/D:，尚无 USB 盘；包还在原 Ubuntu，未离机或返回恢复。用户口令未传给助手。

**2026-10-27 USB 设备与加密包：**稍后 Windows 识别到唯一可移动 `E:`，文件系统 exFAT。助手只将上述加密包复制到其新目录并核对 SHA-256 一致；拔插后持久性、导回解密和恢复仍待验证。明文 escrow 未写入 USB 或 NAS。

**2026-10-27 USB 拔插后结果：**用户报告重新插入后，Windows 仍将该唯一可移动盘识别为 E:；助手从盘内只读核对密文 SHA-256 一致，并仅把密文复制回 Ubuntu 新目录 `teacher-workbench-pilot-offline-escrow-return-bb7686675118`。尚无离线包解密或 NAS 数据配对的验证结果，明文仍未写入 USB/NAS。

**2026-10-27 NAS 新快照现场：**用户明确授权后，Ubuntu 257 用专用 NFS v4 将固定虚构管理账号数据包复制到 `10.0.30.6:/teacher-workbench-backup/pilot-manager-data-Lx7aqLEz-9037d08db8d9`，随后只读挂载导回 `/home/huahua/teacher-workbench-nas-import-pilot-manager-data-Lx7aqLEz-9037d08db8d9`；两次挂载均卸载。NAS 来源数据在同机新 Docker 网络 `10.251.27.0/28` 和新卷恢复通过，测试 DB/Redis 停止、卷保留。单独的模型主密钥、Django/数据库配置和 Caddy CA escrow 保留在原 Ubuntu，未写入 NAS；异机灾备尚未验证。

**2026-10-27 试点账号后现场：**助手 SSH 在 Ubuntu 257 只读核对 `teacher-workbench-pilot` 数据库只有一个虚构管理用户 `pilot_manager_20261026`，启用、非 staff/非 superuser，直接权限仅 `manage_members`；试点配置闸门仍强制 AI 关闭。新本机快照 `backup-pilot-Lx7aqLEz` 和独立 escrow 已创建，在 `10.251.26.0/28` 的新隔离网络与新卷完成恢复，测试容器停止、卷保留。新快照的 NAS 转存与异机恢复尚未执行；原预发布仍在线。

- PVE 虚拟机 ID：257；PVE 显示名称：`Ubuntu.server.teacher-workbench`。
- Ubuntu 主机名：`teacher-workbench`；系统：Ubuntu 26.04.1 LTS。
- 2 vCPU，CPU 类型 `host`，4GB 内存。
- 虚拟机为 1 插槽×2 核，创建时记录为 i440fx、SeaBIOS、VirtIO SCSI single。虚拟磁盘实际为 64GiB，位于 `local-lvm`，SCSI discard 与 IO thread 已开启；Ubuntu 安装未使用系统内 LVM。原先 80GiB 只是提议，最终值为 64GiB；2026-10-16 用户现场 `df -h /` 显示根文件系统为 63G。
- 时区 `Asia/Shanghai`，时间同步正常。
- 系统已更新并重启；`systemctl --failed` 无失败服务。
- QEMU Guest Agent 运行正常。

## 网络与访问

- 网卡 `ens18`，virtio、桥接 `vmbr0`、虚拟机侧无 VLAN 标签、PVE 网卡防火墙勾选；IPv4 `10.0.30.5/24`；默认网关 `10.0.30.254`。
- DNS：`8.8.8.8`、`114.114.114.114`、内网 IPv6 `fd6f:2745:9010::1`。现场当时主要 DNS 为 `8.8.8.8`。
- SSH 用户名 `huahua`；Windows 已成功通过 SSH 连接。
- 2026-10-16 助手从本机到 `10.0.30.5:22` 的 SSH 握手显示 ED25519 指纹 `SHA256:KXlY/A9V7F3cr0bk+83HdtUiVXuZlFjq32W/3kADEFw`；用户随后在 **Ubuntu 257 控制台**运行 `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` 并提供完全相同的指纹。主机公钥存于项目内被 Git 忽略的 `data/ssh-known-hosts-review`，没有读取或保存登录密码。助手的非交互 SSH 因无可用密钥被拒；用户随后在自己的 Windows PowerShell 通过 SSH 登录并执行只读命令，见下方资源结果。助手没有取得登录凭据或可复用会话。
- **用户现场已验证（2026-10-16）：**登录后的 `hostname` 为 `teacher-workbench`、`id -un` 为 `huahua`；说明这次密码登录和只读命令运行成功。
- 虚拟机现场记录有内网 IPv6 `fd6f:2745:9010:0:be24:11ff:fe25:311a/64` 和链路本地地址；这不证明该虚拟机有公网 IPv6。
- 用户有域名 `huahuaya.top`；家庭无公网 IPv4、有公网 IPv6，但不默认学校网络支持 IPv6。用户于 2026-10-16 提供现有 EasyTier Compose 配置，说明服务运行在 PVE 的 LXC 140，外部设备装客户端后可访问家庭网络。配置向虚拟网络发布包含 Ubuntu `10.0.30.5` 所在 `10.0.30.0/24` 的多个私网段。**这是用户提供的配置与使用说明，不是助手对 LXC 140 或学校/手机设备的现场测试。**工作台专用域名、可信 HTTPS 与远程网页仍未验证。EasyTier 入网密钥不记录在项目文档；详细边界见 [网络入口方案](network-access-plan.md)。
- **本机只读 DNS 查询（2026-10-17）：**`Resolve-DnsName huahuaya.top -Type NS -DnsOnly` 返回 Cloudflare 名称服务器 `kobe.ns.cloudflare.com` 和 `cecelia.ns.cloudflare.com`。仅证明查询时公开 NS 指向 Cloudflare；不证明账号授权、工作台子域名或证书已配置。
- **用户现场只读监听结果（2026-10-17）：**Ubuntu 257 的 `hostname` 返回 `teacher-workbench`；`ss -H -ltn` 显示测试站仅监听 `127.0.0.1:18000`，另有本机 DNS 的 53 端口及 111、22 端口监听。输出中没有 TCP 80、443 或 18080 的监听行。**这只证明执行时刻没有对应监听，不代表端口获防火墙放行、EasyTier 外部客户端可达、HTTPS 已配置或工作台已发布。**结果来自用户粘贴的 SSH 终端输出；助手仍无可复用登录会话。
- **本机只读 DNS 查询（2026-10-17）：**本机解析器对方案中的 `workbench.huahuaya.top` 返回一条公网 AAAA，随机探测子域名返回同一 AAAA；对 `workbench` 的 A 查询未返回 A。由此**推测**该区域可能有通配 IPv6 记录，不能把候选域名直接视为指向 Ubuntu/EasyTier。直接查询权威服务器超时，Cloudflare 控制台记录尚未核对；没有改 DNS、访问该公网 IPv6 或验证其服务身份。
- **用户确认的当前网络用法（2026-10-17）：**暂不使用工作台域名或 Cloudflare 代理；用户说明未新增 `workbench` 记录，只用 EasyTier 做私网异地组网。此前 DNS 查询是历史线索，不再要求用户核对或修改 Cloudflare；可信 HTTPS/PWA 后移。
- **用户现场 TCP 结果（2026-10-17）：**按前述家外网络、EasyTier 已连接的 Windows 测试步骤，用户返回 `ComputerName=10.0.30.5`、`RemotePort=22`、`TcpTestSucceeded=True`。该输出证明执行设备到 Ubuntu SSH 端口的 TCP 连接成功；输出本身不显示所在网络或 EasyTier 状态，这两项沿用用户按步骤操作的上下文。未测试 SSH 登录、网页端口、手机、学校网络或 HTTPS。
- **用户现场浏览器结果（2026-10-17）：**按先前 SSH 本地端口转发步骤，用户反馈正常看到教师工作台登录页。这是既有回环测试站经临时隧道的页面可见性结果，不表示 Ubuntu 对 EasyTier 直接开放网页端口，也不证明账号登录、正式服务、HTTPS 或手机访问。
- **用户现场建号结果（2026-10-17）：**在 Ubuntu 257 的既有隔离测试栈中，用户返回 `PREVIEW_TEST_ACCOUNT_READY username=browser_preview_20261017 staff=False; password hidden` 与 `PREVIEW_LOGIN_HTTP_200`。按已核对脚本，新增的是普通虚构测试账号，随后服务器本机登录页返回 HTTP 200；密码没有发给助手。用户浏览器随后报 `127.0.0.1` 拒绝连接；助手在当前 Windows 电脑只读检查 `18001` 无监听，与当时的临时 SSH 隧道已关闭相符。后续登录结果见下条。
- **用户现场浏览器登录结果（2026-10-17）：**用户重新打开临时 SSH 隧道后反馈可用虚构普通账号进入首页。这只验证该账号和既有 Ubuntu 测试站首页的实际浏览器路径；手机、管理员拒绝、HTTPS/PWA 和正式服务仍未验证。后续资料功能结果见下条。
- **用户现场资料结果（2026-10-17）：**虚构普通账号在既有测试站上传项目内的虚构 Word 后，用户反馈资料出现在“我的资料”，下载的 Word 能打开。记录为当前浏览器的上传列表与原文件下载效果；未直接核对服务器提取字段、下载哈希或他人账号访问边界。
- **用户现场预发布结果（2026-10-17）：**独立 `teacher-workbench-staging` 启动脚本返回 `STAGING_HTTP_TECHNICAL_VERIFICATION_OK` 和 `SOURCE_TEST_LOGIN_STILL_HTTP_200`，表示脚本内新站登录页、CSS/JS、虚构错误登录第 9 次 HTTP 429 与旧站登录页核对均执行成功。用户经 SSH 临时转发 `127.0.0.1:18002` 反馈新网页正常显示。新站仍只作为回环 HTTP 测试，不表示 EasyTier 直连网页、可信 HTTPS、PWA 或正式发布；助手无可复用服务器会话。
- **助手本机隧道 HTTP 复核（2026-10-17）：**用户仍保持 `18002` SSH 本地转发时，助手在当前 Windows 电脑对新站登录页及 CSS/JS 发出只读 GET，三项均 HTTP 200，文件类型分别为 HTML/CSS/JavaScript。此连接仅经现有 SSH 隧道，不是服务器 SSH 登录权限或外部设备直连网页证据。
- **预发布建号后本地转发状态（2026-10-17）：**用户反馈新栈虚构普通账号创建成功标记，服务器回环新旧登录页均 HTTP 200。随后 Windows 浏览器显示 `127.0.0.1:18002` 拒绝连接；助手在当前 Windows 只读检查该回环端口无监听、GET 不可达。应先重新建立临时 SSH 转发，再验收账号登录；不据此宣称服务器服务中断。
- **预发布浏览器登录结果（2026-10-17）：**隧道恢复后用户截图显示 `127.0.0.1:18002` 表单 POST 返回 Django 403、Origin mismatch。助手经当前隧道的虚构 POST 复现同一 403；此时 GET 登录页 HTTP 200。预发布网关 Host 丢端口已在本地配置修正，但用户服务器尚未应用该热重载；不得把新账号成功登录写为通过。
- **预发布修复后的现场与本机复核（2026-10-17）：**上条为历史故障。用户新截图显示虚构普通账号进入独立预发布首页，资料页显示上传成功并提取文字；用户确认虚构 DOCX 上传与下载打开正常。助手通过仍可用的 Windows SSH 本地隧道，以全新虚构错误登录请求复核带 `Origin: http://127.0.0.1:18002` 的 POST，得到 HTTP 200 和预期错误密码提示，旧 403 不再复现。这是临时隧道下的回环 HTTP 结果；没有获得服务器热重载脚本输出，也没有证明 EasyTier 直连网页、可信 HTTPS、PWA 或正式发布。
- **预发布虚构配对备份现场结果（用户 2026-10-17 输出）：**Ubuntu 257 的 `teacher-workbench-staging` 已完成虚构样例安全检查、PostgreSQL 转储和私有文件归档校验；Web/网关短暂停止后四服务重新启动，新站回环登录页 HTTP 200，最后输出 `STAGING_BACKUP_FILES_VERIFIED` 和私有目录 `/home/huahua/teacher-workbench-staging-backups/backup-cxi7XtWw`。助手未直连服务器或读取备份；恢复到新卷、NAS 转存、定时备份尚未验证。
- **预发布独立恢复现场结果（用户 2026-10-17 输出）：**上述配对备份已恢复到全新网络和数据库/私有文件卷，输出 `STAGING_RESTORE_FIXTURE_AND_ACCESS_OK`、`STAGING_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-restore-20261017`，临时恢复容器已停止，卷保留。脚本核对原所有者下载及其他账号 404；新旧站登录页结束时均为 HTTP 200。输出里的 `Not Found: /materials/1/download/` 是预期跨账号拒绝。助手未直接登录服务器；新栈 NAS 来源恢复与自动周期未验证。
- **预发布手动排队更新现场结果（用户 2026-10-17 输出）：**Ubuntu 257 更新脚本返回 `STAGING_MANUAL_QUEUE_AI_OFF_VERIFIED`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_UPDATE`、`STAGING_MANUAL_QUEUE_DEPLOYED_AI_OFF`；新代码目录 `/home/huahua/teacher-workbench-staging-1d3ed18b`。按已核对脚本，独立预发布 Web/网关切换成功，配置仍关闭 AI 和持久 Key，新旧测试站登录页回环 HTTP 200。用户未提供页面排队或模型处理结果；助手本轮未直接登录服务器，不能推断长期运行状态或正式可用。
- **预发布浏览器排队现场结果（用户 2026-10-17 截图）：**在新站任务详情页可见“生成：排队中”、“任务 1 · 2026-10-17 11:32”及手动启动说明。这是浏览器创建排队任务的页面证据，不包含刷新持久性或后台任务记录核对，也不代表模型已运行。助手没有服务器会话或该账号凭据。
- **预发布任务只读预检现场结果（用户 2026-10-17 终端输出）：**独立预发布容器的任务 1 仍在排队，资料编号 1 为虚构 `离线排版样例-学生卷.docx`，提取文字 153 字；输出明确表示没有付费确认参数、未读取 Key、未发送模型请求。按项目命令守卫，资料文件 SHA-256 与既定虚构样例一致。助手未登录服务器；这不表示草稿已生成。
- **预发布任务 1 模型处理现场结果（用户 2026-10-17 反馈）：**用户在独立预发布容器显式运行单任务命令后反馈“该预发布任务已完成”。按本地已核对命令，只有任务变为 `done` 才返回该标记，处理路径先保存草稿；该次操作针对虚构资料和临时输入的千问 Key。用户未提供页面、Word 或账单结果，助手未直连服务器或获取 Key；不把任务完成扩大为教学内容验收。
- **预发布成果现场结果（用户 2026-10-17 反馈）：**用户按页面和 WPS 验收步骤回复“均正常”，范围为草稿预览、学生/教师双 Word、题目答案、公式编辑、排版及打印预览；助手没有看到该文件。实际纸张打印与账单仍未核对。
- **生成后预发布备份现场结果（用户 2026-10-17 终端输出）：**已出现 `STAGING_GENERATED_SOURCE_VERIFIED`、`STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`、`STAGING_WEB_RESTARTED_HTTP_200` 与 `STAGING_GENERATED_BACKUP_FILES_VERIFIED`。Ubuntu 私有备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-generated-wmPvKqmx`；按脚本核对范围，包含任务 1 已生成草稿的数据库、私有原件和匹配代码包。助手未连接服务器或读取备份；这份备份的独立恢复和 NAS 转存未执行。
- **生成后预发布恢复现场结果（用户 2026-10-17 终端输出）：**全新隔离卷的 PostgreSQL 与私有文件恢复、草稿内容和跨账号拒绝检查通过，最终 `STAGING_GENERATED_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-generated-restore-20261017`，容器停止、卷保留。源预发布和旧测试站登录页均 HTTP 200。三条 `Not Found` 是预期跨账号 404。助手未直接登录或读取文件；NAS 来源恢复和正式环境未验证。
- **生成后预发布备份 NAS 转存现场结果（用户 2026-10-17 终端输出）：**已出现 `GENERATED_STAGING_SOURCE_BACKUP_VERIFIED`、专用 NFS 挂载核对、七个文件逐项校验、`NAS_GENERATED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED` 和 `NAS_GENERATED_STAGING_COPY_DONE`。NAS 副本名 `staging-generated-wmPvKqmx-0d63b4ce3f0e`。助手未直接登录 Ubuntu 或 NAS；该副本的只读导入及新卷恢复待验。
- **生成后预发布备份 NAS 来源恢复现场结果（用户 2026-10-17 终端输出）：**上条为转存时状态。随后从该专用 NAS 副本只读导入，九个文件逐项校验，`NAS_LOCAL_IMPORT_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_GENERATED_STAGING_IMPORT_DONE` 均出现。导入目录 `/home/huahua/teacher-workbench-nas-import-staging-generated-wmPvKqmx-0d63b4ce3f0e`。在另一套新卷恢复后返回 `STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_GENERATED_NAS_SOURCE_RESTORE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-generated-nas-restore-20261017`。三条 `Not Found` 是预期跨账号 404；新容器已停、新卷保留。助手未直接连接服务器；应用镜像与检查器仍来自现有 Ubuntu。
- **预发布浏览器修改任务（用户 2026-10-17 截图）：**独立预发布站显示任务 2“修改：排队中”，时间 22:37，并提示“修改任务已排队。”。这是页面状态证据，不是服务器只读预检、模型处理或新版本验收；助手未登录 Ubuntu，也未获取该虚构账号凭据。
- **预发布任务 2 只读预检（用户 2026-10-17 终端输出）：**Ubuntu 独立预发布容器显示任务仍排队，资料编号 1 为虚构 DOCX，提取文字 153 字；命令守卫还核对固定文件哈希与归属，未读取 Key、未发送模型请求。助手未直接连接服务器；新版本和费用尚无结果。
- **预发布任务 2 模型处理（用户 2026-10-17 终端与截图）：**用户主动执行单次付费命令并返回完成标记；页面显示任务 2 已完成、草稿第 2 版和双 Word 下载入口。第 1 题答案截图出现字面 `\n` 排版问题。助手未直接登录 Ubuntu、未查看实际 Word 或账单；本地换行修复尚未部署，现有 NAS 副本发生在任务 2 之前。

## 容器能力

- 用户先前现场记录：Docker Engine 客户端/服务端 `29.9.0`、containerd `2.4.2`、runc `1.5.2`；以 `sudo docker run --rm hello-world` 下载与运行成功。这只证明当时基础 Docker 能用，不证明所有模型域名或 GitHub 可达。
- **用户现场已验证（2026-10-16）：**`docker --version` 输出 29.9.0，`docker compose version` 输出 v5.6.0；普通用户运行 `docker info` 未成功，命令给出 `DOCKER_ACCESS=no`。随后用户提供 `id -nG` 输出，`huahua` 在 `sudo` 组，但不在 `docker` 组；`/var/run/docker.sock` 权限为 `srw-rw----:root:docker`，故普通用户按文件权限无法访问 Docker socket。用户进一步运行 `sudo docker info --format '{{.ServerVersion}}'`，输出 `29.9.0`，证明该次 `sudo` 可访问 Docker daemon。命令结束时的 `Connection to 10.0.30.5 closed.` 是 SSH 会话正常关闭，不是 Docker 错误。未改变组或 socket 权限，尚未验证 Compose 栈启动。
- **用户现场已验证（2026-10-16）：**`free -h` 显示内存总量 3.3Gi、可用 2.8Gi，Swap 总量 3.8Gi、已用 0；`df -h /` 显示根分区 `/dev/sda2` 总量 63G、已用 7.4G、可用 53G、使用率 13%；`df -i /` 显示 inode 总量 4,194,304、已用 110,967、使用率 3%。`ss -H -ltn` 在该次检查中未发现 18000 监听，命令输出 `PORT_18000=free`；这只代表检查时刻，不保留端口。
- **用户现场已验证（2026-10-16）：**白名单测试代码包已复制到 `huahua` 家目录的 `teacher-workbench-test-9e29fddf.tar.gz`，用户提供服务器端 `sha256sum` 为 `9e29fddfbf6bd33674406aa0e77155574d69cd09557edc0998ce95ea1104bb4c`，与本地包一致。尚未解压、生成服务器 `.env` 或启动容器。
- **用户现场已验证（2026-10-16）：**在 `huahua` 家目录创建 `teacher-workbench-test-9e29fddf` 独立测试目录并解压后，检查命令输出 `TEST_SOURCE_READY`；Ubuntu 宿主机 `python3 --version` 输出 `Python 3.14.4`。这只证明目录和必需源文件存在；尚未生成服务器 `.env`、解析 Compose 或运行容器。
- **用户现场已验证（2026-10-16）：**测试环境准备程序在该独立目录生成随机 `.env` 后，用户反馈 `TEST_ENV_CREATED`、安全检查器通过和 `TEST_CONFIG_READY`；`docker compose config --quiet` 解析成功。密钥内容未发给助手；容器、PostgreSQL、Redis 和网页服务尚未启动或验证。
- **用户现场已验证（2026-10-16）：**首次启动脚本在 Ubuntu 257 通过预检并输出 `TEST_FIRST_START_PREFLIGHT_OK`，Redis 镜像拉取成功；构建 Python 镜像时 `pip` 读取 `files.pythonhosted.org` 的 Django wheel 超时，Docker build 退出码 2。没有登录页响应或 Compose 服务状态证据；同名容器/卷是否留下仍待核对。本地已准备离线依赖重试包，但 Ubuntu 运行结果未知。
- **用户现场已验证（2026-10-16）：**离线重试后，用户提供 `docker compose ps` 输出：`teacher-workbench-test-db-1` 为 PostgreSQL 17、healthy；`teacher-workbench-test-redis-1` 为 Redis 7、healthy；Web 与 worker 均为 Up。Web 仅映射 `127.0.0.1:18000->8000/tcp`，脚本输出 `TEST_LOGIN_HTTP_200`。这是刚启动时的一次状态与本机回环登录页检查；业务流程、持续健康、迁移版本、备份恢复和对外访问仍待分别验证。助手没有可复用 SSH 登录会话。
- **用户现场已验证（2026-10-16）：**之后运行核验脚本仍得到四服务运行及仅回环绑定，Django 系统检查无问题、迁移检查通过。原 35 项测试在 PostgreSQL 环境有 5 项失败、16 项报错，输出含 SQLite 专用命令限制和数据库连接关闭；登录页静态资源检查因前面失败未执行。不能把原测试集的失败等同于数据库服务不可用，也不能标记业务流程通过。助手仍无可复用 SSH 会话。
- **用户现场已验证（2026-10-16）：**独立 PostgreSQL 虚构资料检查输出 1 项测试 `OK`、`POSTGRES_SMOKE_WORKFLOW_OK`、`TEST_LOGIN_AND_STATIC_HTTP_200`、`TEST_POSTGRES_SMOKE_OK`；Django 测试数据库在结束时删除。四服务仍运行，登录页和 CSS/JS 由 Ubuntu 回环访问成功。这是测试数据库中的技术流程，不代表持久测试卷备份或 NAS 已验证。
- **用户现场已验证（2026-10-16）：**新版一次性 PostgreSQL 完整回归输出末尾 `OK (skipped=11)`、`Destroying test database for alias 'default'...`、`POSTGRES_REGRESSION_SUITE_OK`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_REGRESSION`。按脚本顺序，临时测试数据库已销毁，原测试站登录页仍返回 HTTP 200；用户未提供 `Ran ... tests` 行，现场总数不单独声明。旧版 35 项的失败保留为历史记录，新版回归是隔离测试栈的技术结果，正式环境仍未部署。助手无可复用 SSH 登录会话。
- **用户现场已验证（2026-10-16）：**新版登录限速的一次性脚本输出 `OK (skipped=11)`、临时测试库销毁、`LOGIN_THROTTLE_POSTGRES_REGRESSION_OK`、`REDIS_SHARED_COUNTER_OK` 和 `SOURCE_TEST_LOGIN_HTTP_200_AFTER_LOGIN_THROTTLE`。测试代码在独立容器运行，虚构 Redis 键由两个独立进程读写，原测试站回环登录页仍 HTTP 200。运行中的 Web/worker 仍为旧代码；真实 HTTP 登录限速、浏览器与 HTTPS 未验证。结果来自用户粘贴输出，助手无可复用 SSH 会话。
- **用户现场已验证（2026-10-16）：**首次测试卷备份脚本建立虚构记录并停止 Web/worker 后未完成；诊断时 `db.dump` 为 0 字节，db/redis healthy，Web/worker 未运行。随后用户运行 `sudo docker compose start web worker`，现场四服务再次运行，db/redis healthy，Web 仍仅绑定 `127.0.0.1:18000`，回环登录页输出 `TEST_LOGIN_HTTP_200`。这是故障后的服务恢复证据，不代表备份已完成；NAS 仍未连接或验证。
- **用户后续现场输出（2026-10-16）：**四服务仍运行，db/redis healthy，Web/worker 显示已运行约 8 分钟，回环登录页再次输出 `TEST_LOGIN_HTTP_200`。提供的输出未包含旧备份脚本的进程检查标记，不能据此断定旧进程已退出。
- **用户现场结果（2026-10-16）：**修订版备份脚本最终报告 `TEST_WEB_RESTARTED_HTTP_200`、`TEST_BACKUP_FILES_VERIFIED`，配对备份存于 Ubuntu 用户家目录的 `teacher-workbench-test-backups/backup-NX5wqA1m`。这属于本 VM 的隔离测试数据，不在 OMV NAS；独立卷恢复尚未验证。
- **用户现场结果（2026-10-16）：**上述配对备份已恢复到单独的测试网络、PostgreSQL 卷与私有文件卷；输出 `RESTORE_FIXTURE_AND_ACCESS_OK`、`RESTORE_LOGIN_HTTP_200`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`INDEPENDENT_RESTORE_VERIFIED`。恢复目录 `/home/huahua/teacher-workbench-restore-nx5wqa1m`；新容器已停止，恢复卷保留，原测试站仍响应。三条 `Not Found` 为预期的跨账号 404。此结果来自用户粘贴的现场输出，助手没有直接 SSH 登录；未涉及 OMV NAS、真实账号或密钥恢复。
- **用户现场结果（2026-10-16）：**用户在 Ubuntu 257 运行已校验 SHA-256 的只读 NAS 检查脚本，输出 `NAS_TARGET=10.0.30.6`、`NAS_NFS_TCP_2049=reachable`、`NAS_SMB_TCP_445=reachable`、`NETWORK_MOUNT_COUNT=0`、`NAS_IP_MOUNT_COUNT=0`、`NAS_READONLY_SURVEY_DONE`。这说明检查时 Ubuntu 可建立到该 IP 的 NFS/SMB TCP 连接，且 Ubuntu 当前没有 NFS/CIFS 挂载；不证明具体共享对 Ubuntu 开放、拥有写权限或已备份。脚本没有读取或写入 NAS 文件；助手没有直接登录服务器。
- **用户现场结果（2026-10-16）：**后续只读 NFS 导出检查脚本的 SHA-256 校验输出 `OK`，在 Ubuntu 返回 `NAS_TARGET=10.0.30.6`、`NFS_MOUNT_HELPER=absent`、`NFS_EXPORT_LIST=tool_absent`、`NFS_EXPORT_SURVEY_DONE`。这只说明该 VM 当前没有 `mount.nfs` 和 `showmount` 工具，未取得 OMV 导出列表；不能由此推断 OMV 没有共享或 Ubuntu 已获/未获访问权限。没有安装软件、挂载或写入 NAS。
- **用户现场截图（2026-10-16，OMV「服务 → NFS → 共享」）：**可见 `backup` 与 `share` 两条 NFS 共享，均允许客户端 `10.0.30.0/24`，选项显示 `insecure, no_root_squash, no_subtree_check, rw, sync`；列表中没有教师工作台专用 NFS 共享。这是用户提供的管理页面截图，助手未登录 OMV；该张截图未显示共享文件夹的设备、路径和权限，后续截图另记于下条。现有条目不改动，也未给 Ubuntu 挂载或写入权限做实际测试。
- **用户现场截图（2026-10-16，OMV「存储器 → 共享文件夹」）：**列表可见 `backup`、`share` 位于 `/dev/sda`，相对路径分别为 `backup/`、`share/`；`Photos`、`family` 位于 `/dev/sdb1`。四项均显示 Available，列表中没有名称明确的教师工作台专用文件夹。截图没有展示文件所有者、访问控制列表或剩余空间；助手没有直接登录 OMV，也没有创建文件夹。
- **用户现场截图（2026-10-16，新建后）：**OMV 共享文件夹列表新增 `teacher-workbench-backup`，设备 `/dev/sda`，相对路径 `teacher-workbench-backup/`，状态 Available；其绝对路径显示在与现有 `backup`、`share` 相同的 `/srv/dev-disk-by-uuid-c7d96f31-75c2-4ca4-97b2-2ac4809faadd/` 文件系统下。这证明列表中已存在目标共享文件夹；截图没有显示 POSIX 模式、所有者、服务授权或目录内容，也没有证明 Ubuntu 已能访问。
- **用户现场截图（2026-10-16，新文件夹 ACL 页面）：**`teacher-workbench-backup/` 顶层的所有者为 `root [0]`、所属组为 `users [100]`；所有者权限“读/写/执行”，用户组“无”，其他人“无”，对应 POSIX `700`。截图中“递归”未勾选；下方只展示 ACL 列表的一部分，不能断言不存在额外的命名 ACL 条目，也不能推断 SMB 服务权限。用户只展示页面，未报告保存或应用 ACL 更改。
- **用户现场截图（2026-10-16，OMV「服务 → SMB/CIFS → 共享」）：**列表有四个已启用共享：`Photos`、`backup`、`family`、`share`，每项“公开”显示 No、“可浏览”有勾选；列表未见 `teacher-workbench-backup`。该页没有显示各账号或 `users` 组的服务级权限，不能仅凭“公开 No”推断新建账号无权登录这些共享，也不能凭“只读”列判断实际写权限。助手没有登录 OMV 或修改共享。
- **用户现场截图（2026-10-16，四个现有共享文件夹的「权限」页面）：**四张截图都只显示现有用户 `huahua` 一行，未出现 `users` 组；其中两张 `huahua` 为 Read/Write，两张三个权限按钮均未选中。截图裁掉了共享文件夹名称，不能将四个画面分别对应到 `Photos`、`backup`、`family`、`share`。未选中不能解释为拒绝所有未来账号访问；没有新增账号、改动权限或测试登录。
- **用户现场截图（2026-10-16，OMV「服务 → NFS → 共享 → 创建」）：**表单可选共享文件夹、填写单一客户端、选择只读/读写、输入扩展选项；截图中的初始值为“只读”及 `subtree_check,insecure`，文件夹和客户端尚未选择。此为表单预检，不能说明专用导出已保存、已生效或 Ubuntu 已挂载。
- **用户现场截图（2026-10-16，OMV「服务 → NFS → 共享」新增后）：**第三行显示 `teacher-workbench-backup`，客户端为单个 IP `10.0.30.5`，选项含 `all_squash,anongid=65534,anonuid=65534,no_subtree_check,root_squash,rw,secure,sync`，未见 `insecure` 或 `no_root_squash`。这是管理页面中的保存结果；截图未证明待处理更改已应用、导出可挂载或目录可写。原 `backup`、`share` 两行仍可见。
- **用户现场截图（2026-10-16，专用文件夹 ACL 页面）：**名称为 `teacher-workbench-backup`、相对路径 `/`；所有者显示 `nobody [65534]`、组 `users [100]`，仅所有者为读/写/执行，组和其他人为“无”，递归未勾选。第二张截图只展示命名 ACL 列表前几行，不能判断全部命名项；截图也未显示保存/应用状态。Ubuntu 挂载和实际读写仍待验证。
- **用户现场输出（2026-10-16，Ubuntu 257 临时只读探测）：**专用导出挂载后的脚本输出 `DEDICATED_NFS_READONLY_MOUNT_OK`、`NFS_ROOT_UID=65534`、`NFS_ROOT_MODE=2700`、`PROBE_MOUNT_CLEANED`。`2700` 为所有者 `700` 加目录 setgid，组和其他人仍无权限；新建子项可能继承目录组 `users [100]`，后续写入必须验证新文件模式。初版脚本因仅接受恰好 `700` 输出 `DEDICATED_NFS_METADATA_UNEXPECTED`，没有末尾成功标记。临时挂载已按脚本清理，未向 NAS 写文件；助手没有直接连接 Ubuntu 或 OMV。
- **用户现场输出（2026-10-16，Ubuntu 257 临时写入探测）：**专用 NFS 读写挂载检查输出 `DEDICATED_NFS_WRITE_MOUNT_OK`，顶层 UID `65534`、模式 `2700`；新建虚构探测文件 UID `65534`、模式 `600`，读回内容一致，随后输出 `NFS_PROBE_FILE_REMOVED`、`PROBE_MOUNT_CLEANED`、`NFS_WRITE_PROBE_DONE`。这证明该次从 Ubuntu 到专用导出的单文件写入、读回、删除与临时挂载清理；不证明完整配对备份、NAS 保留版本或从 NAS 恢复。结果来自用户粘贴的终端输出，助手没有直接连接服务器。
- **用户现场输出（2026-10-16，Ubuntu 257 虚构备份转存）：**`FICTIONAL_SOURCE_BACKUP_VERIFIED`、六个 `NAS_COPY_FILE_VERIFIED=...`、`NAS_FICTIONAL_BACKUP_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_FICTIONAL_COPY_DONE` 均出现；完成目录名为 `fictional-backup-NX5wqA1m-dab1c5b855e1`。按已核对脚本，Ubuntu 本机的虚构 PostgreSQL 导出、私有文件归档、两个校验清单、状态文件和匹配测试代码包已复制并在 NAS 副本逐文件校验。结果由用户终端提供，助手未直接读取 NAS；仍未从 NAS 副本独立恢复，也未配置每日自动备份。
- **用户现场输出（2026-10-16，NAS 副本只读导入）：**从上述专用 NAS 副本看到 `NAS_SOURCE_BACKUP_VERIFIED`、八个 `NAS_IMPORT_FILE_VERIFIED=...`、`NAS_LOCAL_IMPORT_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_IMPORT_DONE`；本机新私有目录 `/home/huahua/teacher-workbench-nas-import-dab1c5b855e1`。这是用户终端输出，助手未直接挂载 NAS。
- **用户现场输出（2026-10-16，NAS 来源独立恢复）：**`NAS_IMPORTED_BACKUP_VERIFIED`、`RESTORE_EMPTY_DATABASE_READY`、`RESTORE_POSTGRES_READY`、`RESTORE_PRIVATE_READY`、`RESTORE_FIXTURE_AND_ACCESS_OK`、`RESTORE_LOGIN_HTTP_200`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。新目录 `/home/huahua/teacher-workbench-nas-restore-dab1c5b855e1`；三条 `Not Found` 是预期跨账号 404。此结果验证虚构数据从 NAS 副本恢复到新卷的脚本流程，新增容器已停、卷保留；真实账号、密钥与正式服务未验证。

## PVE、网络与 NAS 边界（交接包提供的现场记录）

- PVE 宿主机 `10.0.30.3`、节点 `pve`；Ryzen 7 255、约 27GiB 内存。宿主机与本项目 Ubuntu 虚拟机须严格区分；本项目开发不操作 PVE 宿主机、其他虚拟机或 GPU 直通。
- 网关 `10.0.30.254` 是 ImmortalWrt/OpenClash 旁路由；交换机端口为 VLAN30 untagged/PVID30，虚拟机网卡不另加 VLAN30 标签。网络细节是现场基线，不授权修改旁路由、PVE 网桥或 VLAN。
- OMV 地址 `10.0.30.6`。PVE 现场已有 backup NFS 挂载 `/mnt/pve/backup`，导出 `/export/backup`；约 13TiB 总量、79.2% 已用、约 2.64TiB 可用。share 与 backup 显示相同底层容量，不能相加算额外空间。用户截图显示现有 `backup`、`share` NFS 条目及其 `/dev/sda` 文件夹；随后新增了 `/dev/sda` 上的 `teacher-workbench-backup/`。Ubuntu 临时挂载后实测顶层 UID `65534`、模式 `2700`，虚构文件模式 `600` 并已清理；命名 ACL 和跨客户端拒绝效果未完整核对。最初 Ubuntu 缺少 NFS 客户端，后来已能完成临时 NFS 挂载，测试后脚本已卸载；一份虚构整组 NAS 备份及来源独立恢复通过，自动周期未配置。
- PVE 的虚拟机/磁盘备份与工作台的数据库和文件业务备份是不同层次；当前完成 Ubuntu 本机虚构测试数据的手动配对备份、NAS 副本转存及独立卷恢复，业务自动备份与真实数据恢复未验证。

- **用户现场输出（2026-10-17，第 2 版预发布配对备份）：**Ubuntu 257 返回 `STAGING_REVISED_SOURCE_VERIFIED`、`STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`、`STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_REVISED_BACKUP_FILES_VERIFIED`，私有目录为 `/home/huahua/teacher-workbench-staging-backups/backup-revised-X7Bv9cfE`。按已核对脚本，这是虚构资料两版草稿的本机 PostgreSQL/私有文件配对备份与文件校验；助手未直接登录或读取文件。全新卷恢复、NAS 新副本和实际 WPS 仍未验证。

- **用户现场输出（2026-10-17，第 2 版新卷恢复）：**Ubuntu 257 返回 `STAGING_REVISED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_REVISED_INDEPENDENT_RESTORE_VERIFIED`，新目录 `/home/huahua/teacher-workbench-staging-revised-restore-20261017`。按隔离检查器，虚构原件哈希、两版预览与各自学生/教师 Word 及另一账号四处 404 通过；四条 `Not Found` 为预期拒绝。恢复容器已停、新卷保留，源两站登录页 HTTP 200。助手未直接登录；NAS 第 2 版副本及预发布换行修复尚未验证。

- **用户现场输出（2026-10-17，预发布换行修复）：**Ubuntu 257 上新镜像 `teacher-workbench-staging-web:linebreak-20261017` 构建完成，预发布 Web/网关启动；输出 `STAGING_LINEBREAK_RENDER_AND_AI_OFF_VERIFIED`、`STAGING_LINEBREAK_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_LINEBREAK_FIX_DEPLOYED_AI_OFF`，新代码目录 `/home/huahua/teacher-workbench-staging-linebreak-7198283e`。按已核对脚本，只有预发布 Web/网关被切换，数据库与私有卷沿用，AI 配置继续关闭。此结论来自用户粘贴日志，助手未直接连接 Ubuntu；实际第 2 版页面/WPS 效果待用户检查。

## 待验证假设与后续检查

- **用户现场输出（2026-10-17，NAS 渲染代码重建预检）：**Ubuntu Docker 返回 `No such image: python:3.12-slim`，说明该镜像标签当时在本地不可用；这不代表 Ubuntu 没有 Python，也不影响已运行的应用容器。旧重建脚本在使用该镜像前退出，未返回隔离预检成功标记。新脚本将核对备份中的 `APP_IMAGE_ID` 与本地配对应用镜像；实际重建仍待验证。
- **用户现场输出（2026-10-17，配对镜像续接）：**Ubuntu 返回 `NAS_RENDERER_PAIRED_OFFLINE_IMAGE_BUILT`、`NAS_RENDERER_REVISED_PREVIEW_AND_WORD_VERIFIED`、`NAS_RENDERER_SOURCE_LOGIN_HTTP_200`、`NAS_RENDERER_RESTORE_DATABASE_STOPPED` 与最终 `NAS_RENDERER_FROM_NAS_PAIRED_REBUILD_VERIFIED`。按已核对脚本，这验证该机当时保有与备份 `APP_IMAGE_ID` 一致的旧应用镜像，NAS 代码及补丁可在隔离恢复副本构建渲染镜像并完成虚构第 2 版检查；助手未直接连接服务器。缺少 Python 基础镜像标签的旧错误仍是真实历史结果，不等于空白主机的恢复能力已验证。

- 用户已通过经主机指纹核对的 SSH 登录并提供资源、测试栈启动与端口输出；普通用户 Docker socket 权限不足已由组与 socket 权限解释，`sudo` 下的 Docker 服务端版本已现场验证。隔离测试栈的针对性 PostgreSQL 虚构流程及新版完整回归已通过；原 35 项失败是历史记录，正式环境未部署。
- EasyTier 产品和 LXC 140 的配置来源已由用户说明；当前只需先核对家外设备经 EasyTier 到 Ubuntu 的实际路径。工作台域名、可信 HTTPS 证书和 PWA 安装已由用户暂缓，后续重启该阶段时再验证。
- OMV 专用导出、工作台目标目录及一份虚构数据备份的独立恢复已现场技术验证；保留数量、每日自动备份、完整命名 ACL 和跨客户端拒绝效果仍需核对。
- Ubuntu 到 NAS 的 NFS/SMB TCP 端口可达，专用 NFS 单文件读写、数据库与原件的虚构备份转存及 NAS 来源独立恢复已验证；真实资料、完整访问边界和密钥恢复能力仍待验证。PVE 已挂载 NFS 不代表工作台正式业务数据已受保护。
- 开发测试与正式环境须隔离，并在部署前明确实际主机目录、数据卷、密钥存放与回退方案。

## 2026-10-18 阶段 2A 预发布现场基线（用户终端输出）

- Ubuntu 257 的预发布配对备份返回 `STAGING_PHASE2A_PRE_BACKUP_FILES_VERIFIED`，目录为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-l1gxAffX`；原登录页恢复 HTTP 200。
- 该备份在新隔离卷恢复并返回 `STAGING_PHASE2A_PRE_INDEPENDENT_RESTORE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-phase2a-pre-restore-20261018`；恢复容器已停止、卷保留，跨账号访问预期 404，新旧站登录页当时 HTTP 200。
- 随后 2A 预发布部署返回 `STAGING_PHASE2A_NEW_AND_OLD_LOGIN_HTTP_200` 与 `STAGING_PHASE2A_DEPLOYED_AI_OFF`，新代码目录 `/home/huahua/teacher-workbench-staging-phase2a-1bf5a500`。按已核对脚本控制流，恢复副本 PostgreSQL 迁移和专项测试先通过，在线预发布 Web/网关后切换；AI 调用保持关闭。**以上是用户现场技术结果，助手未直接连接 Ubuntu；管理页面与正式环境未由此验收。**
- **2026-10-18 预发布静态样式修复：**用户现场终端返回固定样式修复脚本的完整成功标记；助手经已有 Windows→Ubuntu 18002 隧道只读核对实际 CSS 为 HTTP 200、SHA-256 `e69350c56233cc5adb34dd7ba2719abdb4378c17d90c85022f0ec8b317b9326b`。修复仅针对预发布静态卷与该预发布目录中的 Compose 配置，未由助手直连 Ubuntu；浏览器排版仍待用户检查，正式环境未更新。

## 2026-10-20 阶段 2B 预发布前现场检查（用户终端输出）

- 固定只读脚本的最终输出为 `STAGING_PHASE2B_READONLY_PREFLIGHT_OK`。用户同时提供四服务与镜像匹配、主密钥目录尚未创建、虚构账号和既有第 2 版草稿存在，以及预发布 18002 与旧测试站 18000 登录页 HTTP 200 的标记。
- 这是用户提供的 Ubuntu 257 现场结果；助手本轮未直接连接服务器。它不证明备份、独立恢复、新镜像部署、主密钥创建或真实 Key 可用。下一步只执行当前 2A 虚构预发布状态的配对备份。
- **2026-10-20 后续用户终端输出：**当前 2A 虚构预发布数据库、私有文件、旧镜像与源码的配对备份脚本完成，返回 `STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED` 和 `STAGING_PHASE2B_WEB_RESTARTED_HTTP_200`，目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-lESMk1Nj`。这是用户提供的技术标记；助手未直接查看备份，独立恢复尚未执行。
- **2026-10-20 后续用户终端输出：**上述备份在 Ubuntu 257 的全新隔离网络/卷恢复，返回 `STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK`、`STAGING_PHASE2B_SOURCE_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`。恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj`；两条 `Not Found` 是跨账号 404。按脚本，恢复容器已停，新卷保留。此为用户现场结果，非助手直接访问；不证明 2B 新代码或主密钥恢复。
- **2026-10-20 后续用户终端输出：**离线镜像构建返回 `STAGING_PHASE2B_CRYPTOGRAPHY_IMPORT_OK`、`STAGING_PHASE2B_OLD_SITES_UNCHANGED_HTTP_200` 与 `STAGING_PHASE2B_OFFLINE_IMAGE_BUILT_NO_SWITCH`；新源码目录 `/home/huahua/teacher-workbench-staging-phase2b-20261020`。此为用户现场标记，助手未直连 Ubuntu；新镜像尚未切换，原站当时仍响应，密钥目录和在线数据库未由这一步处理。
- **2026-10-20 后续用户终端输出：**隔离假 Key 恢复脚本返回随机主密钥生成、权限检查、`workbench.0005_modelcredential` 在隔离恢复库迁移、9 项测试通过、正确主密钥恢复、错误/缺失主密钥拒绝，以及最终 `STAGING_PHASE2B_FICTIONAL_KEY_RESTORE_VERIFIED_NO_ONLINE_SWITCH`。虚构恢复目录为 `/home/huahua/teacher-workbench-staging-phase2b-fictional-recovery-lESMk1Nj`；两个原站登录页当时 HTTP 200。按脚本，主密钥位于 Ubuntu 家目录外部代码路径，同机私有恢复目录有一份副本；助手未直接检查文件。主密钥没有异机或离线副本的验收，在线预发布未切换。
- **2026-10-20 后续用户终端输出：**新切换前配对备份返回 `STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED`，目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-3D3OilvA`；对应独立卷恢复返回 `STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK`、`STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED` 和包装脚本最终 `STAGING_PHASE2B_FRESH_PRE_SWITCH_BACKUP_AND_RESTORE_OK`，目录 `/home/huahua/teacher-workbench-staging-phase2b-pre-restore-3D3OilvA`。两条 `Not Found` 是预期跨账号 404；按脚本恢复容器已停、卷保留。原站登录页当时 HTTP 200，在线 2B 尚未切换。此为用户终端结果，助手未直连 Ubuntu。
- **2026-10-20 后续用户终端输出：**预发布 2B 切换脚本完成 `STAGING_PHASE2B_ONLINE_SCHEMA_KEYRING_AND_FIXTURE_OK`、`STAGING_PHASE2B_NEW_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_DEPLOYED_FICTIONAL_KEYS_ONLY_AI_OFF`。按固定脚本，在线 Web 使用新镜像、主密钥目录以只读方式挂载、AI 调用关闭；预发布 18002 和旧测试站 18000 登录页当时 HTTP 200。源码目录 `/home/huahua/teacher-workbench-staging-phase2b-20261020`，备份仍为 `backup-phase2b-pre-3D3OilvA`。此为用户提供的现场技术标记，助手未直连服务器或登录浏览器；正式环境未部署。
- **2026-10-20 用户浏览器反馈与截图：**预发布 18002 的本人模型配置页可保存虚构配置；刷新后列表显示元数据和“已保存 Key”，完整 Key 未回显。仅为用户实际页面验收结果，不代表助手本轮直连服务器；跨账号可见范围尚待验收。
- **2026-10-20 用户后续浏览器反馈：**预发布 18002 虚构管理员自己的列表未见普通教师配置，管理员预配后 Key 不回显，普通教师刷新后可见两条本人配置且 Key 均不回显。三项由用户报告正常；助手本轮未直接连接 Ubuntu。
- **2026-10-20 用户备份终端反馈：**首次保存后备份在容器内 Python 的配置名称断言处报 `AssertionError`，SSH 随后关闭；PowerShell 按非零退出码提示备份未完成。按原脚本顺序，尚未创建备份目录、停 Web/网关或导出数据。助手未直接登录 Ubuntu，修正版尚待现场验证。
- **2026-10-21 用户备份终端反馈：**Ubuntu 257 上修正版保存后备份返回 2 条虚构配置、Web 重启 HTTP 200 和 `STAGING_2B_PAIRED_FILES_VERIFIED`；备份目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-X6F4w9bJ`，同机独立密钥副本目录 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-X6F4w9bJ`。仅为用户终端结果，助手未直连；新卷恢复尚未进行。
- **2026-10-21 用户恢复终端反馈：**从上述配对目录在 Ubuntu 257 建立新隔离卷恢复，返回 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2B_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 和 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-keys-restore-X6F4w9bJ`。四条 `Not Found` 是预期的跨账号 404。来源仅为用户终端输出，助手未直连；未验证 NAS/异机副本与主密钥离线保管。
- **2026-10-21 用户 NAS 转存终端反馈：**专用导出 `10.0.30.6:/teacher-workbench-backup` 的新目录 `staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b` 收到八项虚构数据文件逐个校验及 `STAGING_2B_NAS_DATA_COPY_DONE`；临时挂载已清理。此为用户终端标记，助手未直连 Ubuntu/NAS；仅证明转存，NAS 只读导入、来源恢复及异机主密钥保管待验证。
- **2026-10-21 用户 NAS 只读导入终端反馈：**上述 NAS 目录的十个文件经只读挂载导入 `/home/huahua/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b`，返回本机目录校验、`NAS_MOUNT_CLEANED` 和 `STAGING_2B_NAS_DATA_IMPORT_DONE`。这是用户现场输出，助手未直连；还未用该导入目录在新卷恢复，主密钥仍依赖原 Ubuntu 主机。
- **2026-10-21 用户 NAS 来源恢复终端反馈：**从该导入目录在 Ubuntu 257 新卷恢复，返回虚构配置及跨账号访问核对、原站登录 HTTP 200、恢复容器停止且卷保留和 `STAGING_2B_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-nas-restore-c9e68dfefb4b`。四条 `Not Found` 为预期拒绝。仅为用户现场输出，助手未直连；主密钥仍来自原 Ubuntu 同机副本，非异机恢复。
- **2026-10-21 用户离线包首次导出终端反馈：**Ubuntu 257 的源站登录页返回 HTTP 200，离线主密钥导出预检通过；两次隐藏口令输入后程序返回 `PASSPHRASE_TOO_SHORT` 并退出。按本地脚本顺序尚未写出加密包；可能留下空的私有随机目录。此为用户提供的现场输出，助手未直连服务器或读取口令；U 盘与恢复演练尚未开始。
- **2026-10-21 用户离线包第二次导出终端反馈：**预发布虚构主密钥加密 JSON 已生成于 `/home/huahua/teacher-workbench-staging-offline-key-packages/package-X0ad1NB4/teacher-workbench-staging-model-key-v1.json`，两次 SHA-256 一致，最终 `OFFLINE_KEY_ENCRYPTED_EXPORT_READY`。该路径和摘要仅来自用户终端；助手未读取文件或解锁口令，也未直连 Ubuntu。U 盘复制和恢复未执行。
- **2026-10-21 Windows U 盘现场尝试：**用户输入 `U` 作为盘符，系统报告 `U:` 不存在，复制命令仍因逐行执行被启动；助手本机只读 `DriveInfo` 返回 `E:\` 类型 Removable、卷标“U盘”，`U:\` 不在驱动器列表。项目根目录暂未见同名加密 JSON；`scp` 进程运行，助手试图停止时 Windows 拒绝访问，已要求用户在原窗口 Ctrl+C。上述 E 盘判定只是当前机器读数，最终是否用户打算使用的专用 U 盘及复制结果仍待现场确认。
- **2026-10-21 Windows 复查：**稍后本机只读确认 `scp` 进程已不在、项目根目录与 `E:\teacher-workbench-offline-key-X0ad1NB4` 均无加密包。`E:\` 保持 Removable，但卷标读数变为“huahua”；没有原因证据，不能判断是否同一设备，已向用户求证。U 盘复制尚未验收。
- **2026-10-21 用户设备身份确认：**用户明确回复“是的”，确认当前 `E:\`（本机复核 Removable、卷标“huahua”）为离线备份目标 U 盘。助手再查未见误启动的 `scp` 或项目误落文件；U 盘复制尚未执行成功，最终摘要仍待核对。
- **2026-10-21 用户 U 盘复制结果及本机只读核对：**用户返回 `USB_ENCRYPTED_PACKAGE_SHA256_OK`，路径 `E:\teacher-workbench-offline-key-X0ad1NB4\teacher-workbench-staging-model-key-v1.json`；助手只读看到 `E:\` 仍为可移动盘、卷标“huahua”，349 字节文件的 SHA-256 与 Ubuntu 导出值相同。未读取加密包内容，尚未验证弹出/重插及返回 Ubuntu 的恢复。
- **2026-10-21 用户报告 U 盘已重新插入；本机只读复核：**唯一匹配的可移动盘为 `E:\`、卷标“huahua”，原加密文件 349 字节，SHA-256 再次与 Ubuntu 导出值一致。物理弹出/重插仅由用户报告，助手未读取包内容；从 U 盘返回 Ubuntu 的步骤尚未执行。
- **2026-10-21 用户终端返回 Ubuntu 核对标记：**`USB_RETURN_FILE_SHA256_OK`，返回文件 `/home/huahua/teacher-workbench-staging-offline-key-return-ddfae9d5abc1/teacher-workbench-staging-model-key-v1.json`。按预先核对的 PowerShell 命令，此文件从摘要匹配的可移动盘复制，目标目录新建并限制权限，Ubuntu 再次核对 SHA-256。助手未直连 Ubuntu；独立解密尚未执行。
- **2026-10-22 用户终端独立解密反馈：**Ubuntu 容器提示输入恢复包解锁口令，随后返回 `PASSPHRASE_OR_PACKAGE_INVALID`，没有恢复成功标记。脚本此前创建目标目录 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1`；其当前实际内容尚未现场读取，后续重试必须先核对目录为空。助手未直连服务器、未接触口令或明文密钥；预发布服务状态未由这次输出重新核验。
- **2026-10-22 用户终端安全重试反馈：**`OFFLINE_KEY_RESTORED_TO_NEW_DIRECTORY`、`OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA`、`OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED`，新密钥目录 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1`。这是用户现场输出；脚本在原失败目标为空时恢复虚构主密钥并与 NAS 导入数据摘要核对。助手未直连 Ubuntu、未读取口令或 `v1.key`，尚未用此密钥对 NAS 数据执行独立新卷恢复。
- **2026-10-22 用户终端 NAS 配对恢复反馈：**隔离网络及新卷预检通过，PostgreSQL 与私有文件恢复，虚构配置可解密及跨账号拒绝通过，源预发布登录页恢复后 HTTP 200；最终 `STAGING_2B_USB_KEY_NAS_DATA_RESTORE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-usb-restore-ddfae9d5abc1`。恢复容器已停，卷按脚本保留。四条 `Not Found` 为预期 404。证据仅为用户现场输出，助手未直连服务器；未验证旧测试站本轮状态或空白主机恢复。
- **2026-10-22 用户现场 2C 预检进行中：**预发布只读预检脚本上传、摘要核对通过，输出 `STAGING_2C_SOURCE_CONFIG_AI_OFF`，随后停在 sudo 身份验证前后。四服务状态、在线迁移与双登录页尚无本次完整成功标记；助手未连接 Ubuntu。
- **2026-10-22 用户现场预检中断：**原 SSH 窗口等待超过 60 秒未再输出，用户报告不能输入密码并按 Ctrl+C。当前没有四服务、在线迁移或双登录页的本次成功标记；拟由用户在新交互式 SSH 会话单独检查 sudo 身份验证，助手未直连服务器。
- **2026-10-22 用户现场新会话：**交互式 SSH 中单独执行 `sudo -v` 后返回 shell 提示符；本次完整预检尚未运行完成，助手未直连 Ubuntu 或取得密码。
- **2026-10-22 用户终端只读预检完成：**`STAGING_2C_FOUR_SERVICES_MATCH_IMAGES`、`STAGING_2C_ONLINE_SCHEMA_2B_AI_OFF`、`STAGING_2C_NEW_AND_OLD_LOGIN_HTTP_200`、`STAGING_2C_READONLY_PREFLIGHT_OK` 均出现。当前虚构预发布仍是 2B 镜像、AI 关闭、迁移止于 `0005`；2C 未部署。助手未直连服务器。
- **2026-10-22 用户终端 2C 文件上传结果：**`/home/huahua/teacher-workbench-stage2c-pg-source.tar.gz` 和 `/home/huahua/verify_ubuntu_staging_phase2c_pg_isolated.sh` 的远端摘要检查均为 `OK`，最终 `STAGING_2C_PG_UPLOAD_VERIFIED`。仅证明测试材料在 Ubuntu 257 用户目录且语法检查完成；未由此创建新 Docker 网络、卷或容器，亦未切换在线预发布。助手未直连服务器。
- **2026-10-22 用户终端 2C 隔离 PostgreSQL 测试结果：**最终 `STAGING_2C_PG_ISOLATED_TEST_VERIFIED`，测试目录 `/home/huahua/teacher-workbench-stage2c-pg-36c91614eb03`；按脚本在独立内部 Docker 网络/新卷完成专项测试，测试库容器停止、卷保留，新旧在线登录页仍 HTTP 200。此为用户提供的现场结果，助手未直连服务器；在线预发布仍未由该脚本切换或迁移。
- **2026-10-22 用户终端当前 2B 预发布快照：**数据备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-F6yZnxfi` 与配对同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-F6yZnxfi`，终端返回 `STAGING_2B_PAIRED_FILES_VERIFIED` 和 Web 重启 HTTP 200。助手未直连服务器；从这次新快照的独立恢复尚未执行。
- **2026-10-22 用户终端新快照独立恢复：**`/home/huahua/teacher-workbench-staging-phase2b-keys-restore-F6yZnxfi` 由新隔离网络/卷恢复，`STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK` 与最终 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`；恢复容器已停止、卷保留，源预发布登录页仍 HTTP 200。仅据用户终端记录，助手未直连 Ubuntu；在线 2C 迁移和切换未由此发生。
- **2026-10-22 用户终端 2C 迁移演练脚本上传：**`/home/huahua/verify_ubuntu_staging_phase2c_restored_migration.sh` 的远端摘要和 Bash 语法检查通过，最终 `STAGING_2C_RESTORE_MIGRATION_UPLOAD_VERIFIED`。这是用户提供的文件上传结果；脚本尚未运行，Ubuntu 上还没有由该脚本进行的新数据库迁移。助手未直连服务器。
- **2026-10-22 用户终端 2C 恢复副本迁移：**`/home/huahua/teacher-workbench-staging-phase2c-migration-F6yZnxfi` 对应的隔离恢复库完成 `0006`～`0008`，旧数据与权限检查通过；隔离容器已停止、卷保留，在线双登录页仍 HTTP 200，最终 `STAGING_2C_RESTORE_MIGRATION_VERIFIED`。仅据用户输出记录，助手未直连 Ubuntu；在线预发布数据库与镜像没有被该脚本切换。
- **2026-10-22 用户终端 2C 离线构建脚本上传：**`/home/huahua/build_ubuntu_staging_phase2c_offline.sh` 的远端 SHA-256 与 Bash 语法检查通过，最终 `STAGING_2C_IMAGE_UPLOAD_VERIFIED`。仅记录用户提供的上传结果，助手未直连 Ubuntu；新 2C 镜像尚未由此构建，在线预发布未切换。
- **2026-10-22 用户终端 2C 新镜像隔离烟测：**新标签 `teacher-workbench-staging-web:member-quota-20261022` 的镜像 ID 为 `sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a`；用户返回源码匹配、旧内容烟测、在线双登录页 HTTP 200、隔离容器停止和最终 `STAGING_2C_OFFLINE_IMAGE_BUILT_SMOKE_VERIFIED_NO_SWITCH`。助手未直连 Ubuntu；当前在线预发布没有由此切换到新镜像。
- **2026-10-22 用户终端 2C 配置目录准备：**`prepare_ubuntu_staging_phase2c_source.py: OK`、`STAGING_2C_CONFIG_PREPARED_AI_OFF`，生成 `/home/huahua/teacher-workbench-staging-phase2c-20261022`。此结论仅据用户现场输出；助手未直接查看 Ubuntu 文件，也未在新目录运行 Compose 配置预检或切换在线站点。
- **2026-10-22 用户终端 2C 只读预检中止：**新旧 Compose 内容核对返回 `STAGING_2C_CONFIG_CONTENT_MATCH_OK`，下一步 `sudo -n -v` 返回 `interactive authentication is required`，脚本最终标记为 `STAGING_2C_CONFIG_PREFLIGHT_SUDO_REQUIRED`。未取得容器、数据库或 HTTP 的本次完整检查结果；助手未直连 Ubuntu。需交互式 SSH 先 `sudo -v` 再运行同一脚本，无需重新上传。
- **2026-10-22 用户终端 2C 只读预检复验：**用户提供 `STAGING_2C_CONFIG_COMPOSE_VALID`、`STAGING_2C_CONFIG_ONLINE_STILL_2B_AI_OFF`、`STAGING_2C_CONFIG_BOTH_LOGINS_HTTP_200` 和最终 `STAGING_2C_CONFIG_READONLY_PREFLIGHT_OK`。仅据终端输出记录新配置可解析、在线仍为 2B 且 AI 关闭、两登录页响应；助手未直连 Ubuntu，在线 2C 尚未部署。
- **2026-10-22 用户终端 2C 备份包装器上传：**`prepare_ubuntu_staging_phase2c_switch_snapshot.sh: OK` 且用户确认最终 `STAGING_2C_SNAPSHOT_UPLOAD_VERIFIED` 已显示，仅代表远端摘要及 Bash 语法核对通过。助手未直连 Ubuntu；尚无该包装器运行、配对备份或独立恢复的现场标记，在线预发布仍未由此切换。
- **2026-10-22 用户终端 2C 包装器执行部分输出：**用户再次返回脚本摘要 `OK`，未提供后续预检、备份或恢复标记，也未确认终端是否返回提示符。按运行命令只能确定开头的哈希校验输出，不能推断 Ubuntu 当前 Docker 或服务状态。助手未直连服务器。
- **2026-10-22 用户终端确认提前返回提示符：**单行脚本摘要 `OK` 后 Ubuntu shell 已返回提示符，未出现包装器预检、备份或恢复输出。实际退出码待用户读取；不可据此判断线上站点状态或备份文件是否存在。助手未直连服务器。
- **2026-10-22 用户终端返回码：**在原 Ubuntu 窗口查询到 `SNAPSHOT_LAST_EXIT=1`；失败点还需只读诊断。助手未直连服务器，不能由此推断 18002 当前状态、数据库迁移或新备份是否存在。
- **2026-10-22 用户终端只读诊断与版本来源：**上传包装器 `bash -n` 通过；预检摘要 `92b6c91a...`、旧文件名备份脚本摘要 `4dc7bc83...`、恢复摘要 `a0a3e402...`，备份根目录 0700、`huahua` 所有、普通目录。项目记录说明 `4dc7...` 为初版备份脚本，修正版 `15f1...` 在服务器使用 `_v2.sh` 文件名。助手未直连服务器或读取脚本内容；该输出没有在线服务状态标记。
- **2026-10-22 用户终端 v2 包装器上传：**用户提供新包装器和修正版备份依赖的远端 SHA-256 `OK` 与 `STAGING_2C_SNAPSHOT_V2_UPLOAD_VERIFIED`。该标记仅证明文件就绪和包装器语法通过；助手未直连 Ubuntu，无法据此断言新备份或服务状态。
- **2026-10-22 用户终端 2C 切换前新备份/恢复：**新配对备份数据目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-N1yfMAgN`，同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-N1yfMAgN`，独立恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-keys-restore-N1yfMAgN`。用户终端出现 `STAGING_2B_PAIRED_FILES_VERIFIED`、`STAGING_2B_INDEPENDENT_RESTORE_VERIFIED` 和最终 `STAGING_2C_FRESH_2B_BACKUP_RESTORE_OK`，源预发布 Web 重启登录页 HTTP 200。四条 `Not Found` 是预期 404；助手未直连，在线 2C 切换尚无执行证据。
- **2026-10-22 用户终端 2C 切换脚本上传：**`apply_ubuntu_staging_phase2c.sh: OK` 和 `STAGING_2C_SWITCH_UPLOAD_VERIFIED` 已出现，只证明上传后的摘要与语法检查通过。助手未直连服务器；尚无该脚本执行、在线迁移或镜像切换的现场结果。
- **2026-10-22 用户终端 2C 虚构预发布切换：**`STAGING_2C_ONLINE_SCHEMA_AI_OFF_AND_OLD_CONTENT_OK`、`STAGING_2C_NEW_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_2C_DEPLOYED_AI_OFF`；新源码/配置目录 `/home/huahua/teacher-workbench-staging-phase2c-20261022`，配对旧状态备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-N1yfMAgN`。仅据用户现场终端，在线预发布已按脚本完成 2C 迁移及镜像切换且 AI 关闭；正式环境未涉及。助手当前本机 18002/18000 回环地址不可达，未建立 SSH 隧道，不能以本机 HTTP 复核现场。
- **2026-10-22 用户浏览器额度页反馈：**用户通过预发布页面查看 `staging_teacher_a_20261018` 的调用次数页，报告用户名、未设置提示和表单正常，且未显示教学资料或模型 Key；截图显示该表单。该结果来自用户浏览器，不表示额度已保存或成员模型调用已启用。
- **2026-10-22 用户后续额度页截图：**同一虚构成员的管理页显示累计上限 0、已使用 0、已预留 0、有效期 `2026-10-30 23:00`，表单值一致。来源为用户浏览器截图及上一项操作上下文；未由助手直连 Ubuntu 复核数据库或刷新过程。零额度仍不开放成员实际模型调用。
- **2026-10-22 用户刷新反馈：**用户明确表示该虚构成员额度页“刷新后仍正常”；与前一张截图合并，确认浏览器刷新后仍显示 0/0/0 及 `2026-10-30 23:00`。来源为用户现场操作报告，助手未直连 Ubuntu、数据库或模型厂商。
- **2026-10-22 用户两窗口权限反馈：**用户称新无痕窗口可进入、非无痕窗口显示 403 Forbidden；两窗口各自账号和无痕窗口实际地址尚未核对。仅记录浏览器报告，不视为服务器权限漏洞或权限验收通过；助手未直连现场。
- **2026-10-22 用户无痕窗口地址补充：**最终地址为 `http://127.0.0.1:18002/members/3/allowance/`；窗口登录账号尚未知，不能判断权限结果。仅为用户浏览器反馈，助手未直连。
- **2026-10-22 用户无痕窗口身份确认：**该窗口登录 `staging_manager_20261018`，管理者可见额度页符合预期；非无痕窗口报告 403 的账号尚未核对。来源为用户浏览器反馈，助手未直连。
- **2026-10-22 用户非无痕窗口身份确认：**该窗口首页账号为 `staging_teacher_a_20261018`，此前访问管理页返回 403；与管理者窗口可访问结果结合，浏览器权限路径符合预期。来源仅为用户现场反馈，助手未直连。
- **2026-10-22 用户普通教师页面截图：**预发布“模型状态”显示旧手动排队模式已启用、管理员人工审核并临时输入 Key 后才可能发送资料；不是成员调用自动启用的证据。来源为用户截图，助手未直连或触发任务。
- **2026-10-22 用户脚本上传顺序纠正：**用户完整 PowerShell 历史显示远端 `sha256sum` 校验先于 `scp`，校验失败抛错后 `scp` 未运行；原“传输失败”判断撤回。没有远端上传成功或备份/恢复标记，助手未直连服务器。已在本机准备单入口上传器，现场执行仍待用户完成。
- **2026-10-22 用户单入口上传器部分输出：**只收到 `STAGING_2C_UPLOAD_LOCAL_HASHES_OK`；这不是 Ubuntu 上传或校验结果。终端是否等待 SSH 密码/仍运行待用户确认，助手未直连。

- **2026-10-22 SSH 连通性待核（用户终端与助手本机）：**用户运行单入口上传器时在首次远端预检收到 `Connection closed by 10.0.30.5 port 22`，脚本未进入 `scp`。助手当前执行环境只读 `Test-NetConnection 10.0.30.5 -Port 22` 返回 `TcpTestSucceeded=False`；不能据此判断用户 Windows 网络或 Ubuntu SSH 服务的当前状态。待用户在其原 PowerShell 窗口复核 TCP 22；目前不记录服务器文件已上传或 2C 备份已创建。

- **2026-10-22 用户 Windows 端口复核：**用户回复 `Test-NetConnection 10.0.30.5 -Port 22` 结果 `True`。仅为用户会话当时的 TCP 可达性；SSH 认证、Ubuntu 主机名和上传目标状态仍待只读命令核查。助手当前执行环境此前为 `False`，不把两处环境结果视为相同。无文件上传或服务修改证据。

- **2026-10-22 用户 SSH 只读登录成功：**用户输出 `teacher-workbench`、`huahua` 和 `STAGING_2C_SSH_DIAGNOSTIC_DONE`，两个拟上传脚本路径均报不存在。说明该次从用户 Windows 经 EasyTier 到 Ubuntu 257 的 SSH 认证与远端只读命令执行成功；不能保证之后每次连接均成功，也未证明文件已上传。助手未直接连接 Ubuntu。

- **2026-10-22 用户端脚本上传成功：**用户终端出现两份 2C 脚本的 SHA-256 `OK` 与 `STAGING_2C_ALLOWANCE_SCRIPTS_UPLOAD_VERIFIED`；按本地上传器流程，远端文件已核对哈希和 Bash 语法。尚无 2C 在线快照、同机密钥副本或新卷恢复成功输出；助手未直接连接 Ubuntu，正式环境不受此次上传影响。

- **2026-10-22 用户备份预检失败：**原备份脚本摘要显示 `OK`，随即因 2C 配置目录缺少 `scripts/check_staging_env.py` 退出。按本地脚本顺序，尚未执行 `sudo -v`、停止预发布服务或创建新备份目录。修正版 `_v2.sh` 仅本机验证，仍待上传和运行；助手未直连 Ubuntu，不能从此错误单独证明当前 HTTP 健康状态。

- **2026-10-22 用户 v2 备份输出（未通过）：**用户终端仅见 v2 脚本远端摘要 `OK`，随后 SSH 关闭、包装器报 `Backup v2 failed or SSH disconnected`。尚无首个配置/源码标记、停服或备份成功标记；助手未连接 Ubuntu，不能断言失败原因、预发布当前 HTTP 状态或目录内容。已准备只读预检诊断，现场待执行。

- **2026-10-22 用户只读诊断定位：**用户提供完整非敏感诊断标签，只有 `STAGING_2C_DIAG_CONFIG_STATE=FAIL`，其余目录权限、Compose 固定设置、环境检查、源码摘要和两个镜像 ID 一致性均 `OK`。本地部署脚本显示成功切换后状态文件应为 `STAGING_2C_ONLINE_SWITCH_COMPLETE`，旧备份脚本却要求切换前的准备状态；新 v3 脚本本机已修正，现场未执行。助手未读取服务器状态文件内容或连接 Ubuntu，也没有新备份成功标记。

- **2026-10-22 用户终端 2C 配对备份成功：**v3 输出 `STAGING_2C_PAIRED_FILES_VERIFIED`、`STAGING_2C_WEB_RESTARTED_HTTP_200` 与 `STAGING_2C_BACKUP_V3_WRAPPER_DONE`。备份位于 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-j33bqT1R`，同机密钥副本位于 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-j33bqT1R`。这些为用户现场终端结果，助手未直接连接 Ubuntu；新卷独立恢复和本次 NAS/异机恢复尚未验证。
- **2026-10-22 用户终端 2C 独立恢复成功：**从本机配对备份和同机密钥副本恢复至 `/home/huahua/teacher-workbench-staging-phase2c-allowance-restore-j33bqT1R`，最终 `STAGING_2C_INDEPENDENT_RESTORE_VERIFIED`；源站登录页恢复后仍 HTTP 200。恢复容器已停止，卷保留。此为用户现场终端输出，助手未直连服务器；NAS 来源与异机密钥恢复未验证。
- **2026-10-22 用户终端 2C NAS 数据复制成功：**专用 NFS 挂载验证、八个数据文件逐项校验、`STAGING_2C_NAS_DATA_FILES_VERIFIED`、`NAS_MOUNT_CLEANED` 与 `STAGING_2C_NAS_DATA_COPY_DONE` 均出现；NAS 名称 `staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0`。此为用户现场输出，助手未直连；未复制主密钥，NAS 只读导入及与离线密钥配对恢复仍待验证。

- **2026-10-22 用户终端 2C NAS 只读导入成功：**10 个文件逐项验证，`STAGING_2C_NAS_LOCAL_IMPORT_VERIFIED`、`NAS_MOUNT_CLEANED` 和 `STAGING_2C_NAS_DATA_IMPORT_DONE` 均出现；本地导入目录 `/home/huahua/teacher-workbench-nas-import-staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0`。来源为用户现场输出，助手未直连；NAS+USB 配对新卷恢复仍待验证。


- **2026-10-22 用户终端 NAS+USB 首次恢复失败：**隔离 PostgreSQL 与私有文件导入成功标记已出现，应用内容核验阶段因过长 `DB_HOST` Docker 名称触发 `UnicodeError: label too long`，没有最终恢复成功标记。原隔离资源状态尚未现场确认，在线站点失败后状态亦未由用户复核；助手未直连。


- **2026-10-22 用户终端 2C NAS＋U 盘返回密钥恢复成功：**v2 确认首次失败隔离容器已停，再在短 Docker 名称的新隔离卷恢复，最终 `STAGING_2C_NAS_USB_V2_INDEPENDENT_RESTORE_VERIFIED`；恢复后源站登录页 HTTP 200。新目录 `/home/huahua/teacher-workbench-staging-phase2c-nas-usb-restore-35ee25496ce0-v2`，恢复容器停止、卷保留。此为用户终端输出，助手未直连；整机更换和定时备份未验证。
- **2026-10-22 用户终端 2C 安全闸门隔离测试结果：**Ubuntu 257 上新建内部网络和全新 PostgreSQL 测试库后，40 项回归有 1 项队列测试断言失败；脚本请求停止隔离 DB 并保留卷，未输出已停止状态的最终确认。按本地脚本，首次隔离资源前缀为 `tw2c-guard-cb133427b8f6`；修订版将先核对旧 DB 为 `exited`，再使用新前缀。用户输出不包含在线双登录页检查结果，助手未直接连接服务器。
- **2026-10-22 用户终端 2C 安全闸门 v2 结果：**旧隔离 DB 已确认为 `exited`；v2 在内部网络与新卷的 PostgreSQL 中运行 40 项虚构测试全部通过，在线两个登录页随后返回 HTTP 200。v2 隔离目录 `/home/huahua/teacher-workbench-stage2c-guard-v2-ee34113e8aa9`，测试 DB 已停止、卷保留。助手未直接连接 Ubuntu；不据此推断在线应用代码已更新或成员调用已开启。
- **2026-10-22 用户终端 2C 调用记录 v3 隔离结果：**v2 DB 已停止，v3 在新内部网络与 PostgreSQL 测试库运行 42 项虚构测试全部通过；在线两个登录页随后 HTTP 200。v3 隔离目录 `/home/huahua/teacher-workbench-stage2c-guard-v3-14537acaacc6`，测试 DB 已停止、卷保留。助手未直连 Ubuntu；不能据此推断新调用记录页面已经在线部署。
- **2026-10-22 用户终端调用记录候选镜像构建结果：**以在线旧 2C 镜像为基础禁网构建新标签，镜像内源码摘要和 Django 检查通过；新镜像 ID `sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26`，目录 `/home/huahua/teacher-workbench-staging-call-usage-14537acaacc6`。构建后原 18002/18000 登录页 HTTP 200，旧 Web 镜像未切换。证据来自用户终端，助手未直接连接 Ubuntu；下一步新配对备份与独立恢复尚未现场执行。
- **2026-10-22 用户终端调用记录上线前备份与恢复结果：**新配对备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-szRPlLy0` 与同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-szRPlLy0` 均通过摘要及完成标记；新卷恢复目录 `/home/huahua/teacher-workbench-staging-phase2c-allowance-restore-szRPlLy0`，内容/虚构 Key/0 额度/权限断言通过，恢复容器停止、卷保留。原 18002/18000 登录页随后 HTTP 200。来源为用户终端，助手未直连；候选镜像尚未对新恢复数据测试或上线。

- **2026-10-22 用户终端候选镜像新恢复副本烟测：**候选镜像在 `szRPlLy0` 的隔离恢复卷通过 Django 检查、旧内容与调用记录页面断言；隔离 DB/Redis 已停止且卷保留，原 18002/18000 登录页 HTTP 200，最终 `STAGING_CALL_USAGE_CANDIDATE_RESTORED_SMOKE_VERIFIED_NO_SWITCH`。来源为用户终端，助手未直连 Ubuntu；这一步未更改在线镜像。

- **2026-10-22 用户终端预发布调用记录镜像切换：**`STAGING_CALL_USAGE_DEPLOYED_AI_OFF` 与包装器完成标记出现；配置目录 `/home/huahua/teacher-workbench-staging-call-usage-online-14537acaacc6`，即时备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-DgfGf130`，同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-DgfGf130`。用户终端显示新旧登录页 HTTP 200、旧内容和新模板断言通过、AI 关闭。助手未直连 Ubuntu；浏览器及这份即时备份的独立恢复待验，正式环境不变。

- **2026-10-22 用户浏览器作业与拒绝检查：**本机隧道地址 `127.0.0.1:18002` 已可访问原作业；用户报告第 1/2 版与两份 Word 正常。另一虚构教师访问 `/worksheets/1/` 得到 404 且无作业内容。该错误页截图显示 Django `DEBUG=True` 详细路由信息；预发布目前的错误页修复仅为本机代码准备，尚未收到 Ubuntu 切换结果。助手未直连服务器。
- **2026-10-22 用户终端预发布错误页镜像切换结果：**最终 `STAGING_ERRORS_DEPLOYED_AI_OFF` 和包装器完成标记出现，在线配置目录为 `/home/huahua/teacher-workbench-staging-errors-20261022`；旧内容、AI 关闭、普通 404、静态 CSS 和两个登录页的脚本检查通过。保留的切换前备份为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-DgfGf130`。助手未直接连接 Ubuntu，Windows 浏览器的普通教师 404 显示仍待用户复核；正式环境不变。

- **2026-10-22 用户浏览器复验：**对普通教师访问 `127.0.0.1:18002/worksheets/1/` 的指定检查回复“页面结果正常”，据此将普通 404 与作业跨账号拒绝记为用户验收通过。助手未直接访问浏览器或 Ubuntu；正式环境仍未改变。

- **2026-10-24 用户终端新配对备份结果：**错误页版本的数据、私有文件、镜像及源码归档成功，目录 `/home/huahua/teacher-workbench-staging-backups/backup-staging-errors-CLQ37z6Q`；独立同机密钥副本目录 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-CLQ37z6Q`。预发布 Web 在备份后 HTTP 200。首次隔离恢复导入数据库与私有文件后于内容断言失败，未收到隔离容器停止或最终恢复成功标记。来源为用户终端；助手未直连，在线站点失败后状态未再次现场核对。

- **2026-10-24 用户终端同机独立恢复 v2 结果：**同一备份和独立密钥在另一套新隔离卷恢复通过，目录 `/home/huahua/tw-errors-v2-CLQ37z6Q`；内容/权限/虚构 Key/零额度断言通过，两个恢复容器停止、卷保留，源站登录页 HTTP 200。旧失败容器也已确认停止。助手未直连 Ubuntu；NAS 来源恢复尚未进行。

- **2026-10-24 本机准备，现场待验证：**针对错误页版本快照的专用 NAS 转存、只读导回和已返回 USB 密钥配对恢复脚本已在项目中写好；当前尚无本次 NAS 名称或现场结果。NAS 目标沿用先前已现场验证的 `10.0.30.6:/teacher-workbench-backup`，但不能据旧结果宣称本次挂载成功。助手未直接连接 Ubuntu、NAS 或 PVE。

- **2026-10-24 用户终端 NAS 数据转存结果：**本次专用 NFS 挂载和卸载、八个文件逐项校验以及 `STAGING_ERRORS_NAS_DATA_COPY_DONE` 均有成功标记；NAS 目录为 `staging-errors-data-CLQ37z6Q-d9bd461df68a`。来源为用户终端，助手未直连；只读导回及 NAS 来源恢复待验证。

- **2026-10-24 用户终端 NAS 只读导回结果：**同一 NAS 目录的十个文件逐项校验、私有导入及 NFS 卸载均有成功标记；本地导入目录为 `/home/huahua/teacher-workbench-nas-import-staging-errors-data-CLQ37z6Q-d9bd461df68a`。来源为用户终端，助手未直连；新卷恢复与离线主密钥配对待验证。

- **2026-10-24 用户终端 NAS/USB 来源恢复结果：**上述导回数据配对先前 U 盘返回的虚构主密钥，在新隔离卷完成数据库和私有文件恢复，联合内容/密钥/额度/访问检查、原站登录页 HTTP 200、测试容器停止及最终独立恢复标记通过。目录 `/home/huahua/twerr-nas-d9bd461df68a`；卷保留。助手未直连 Ubuntu/NAS；本项不能证明原服务器丢失后的空白主机重建。

- **2026-10-24 待验证假设：**拟在 Ubuntu 257 的 `10.0.30.5:18443` 运行独立 IP HTTPS 试运行，Caddy 内部 CA 证书需由每台客户端单独信任。Ubuntu 上该地址是否仍配置、端口是否空闲、Docker 是否有 Caddy 镜像、Caddyfile 能否解析、防火墙和家外 EasyTier 客户端能否访问，均须由只读预检与后续现场验证。助手本轮未连接服务器、NAS 或 PVE，也未改原站。

- **2026-10-24 助手本机只读连接尝试：**默认受限环境中的 `ssh` 到 `10.0.30.5:22` 返回本地连接 `Permission denied`；申请受控网络权限后，以 `BatchMode=yes`、严格核对既有主机密钥的只读 `hostname` 尝试可达 SSH，但远端返回 `Permission denied (publickey,password)`。因此没有完成身份验证或执行任何 Ubuntu 命令；后续现场预检需要用户在 Windows 终端输入自己的 SSH/sudo 密码。此结果不代表站点或 EasyTier 故障。

- **2026-10-24 用户终端只读预检结果：**Ubuntu 257 当前预发布 Web 镜像与来源快照固定 ID 匹配，`10.0.30.5:18443` 当时没有监听，`teacher-workbench-pilot` 目标目录及对应容器/卷不存在，`127.0.0.1:18002/login/` 返回 HTTP 200；最终 `PILOT_READONLY_PREFLIGHT_OK` 与 Windows 包装器完成标记出现。`caddy:2-alpine` 镜像未在该 Ubuntu 本地缓存。来源为用户粘贴的终端输出，助手没有 SSH 登录；后续拉取是否成功和远端 HTTPS 可达仍待验证。

- **2026-10-24 助手直接 SSH 现场核验：**用户明确授权后，助手登录 `huahua@10.0.30.5`，确认主机名 `teacher-workbench`。Ubuntu `ens18` 为 `10.0.30.5/24`；试点 Docker 网关监听 `10.0.30.5:18443`，UFW 为 inactive，Windows 在受控网络权限下直连 18443 成功。默认受限环境的端口检测曾显示失败，不能把它当成实际客户端不通。Windows 使用指定试点 CA 并关闭内部 CA 不可用的撤销状态检查后严格证书链和 IP 验证返回登录页 200；当前用户根证书库尚无该 CA。试点 Caddy、Web、PostgreSQL、Redis 均运行；后两者 healthy，原预发布 `18002/login/` 仍 200。试点新库的用户、资料、作业、配置、额度记录均为 0，AI 关闭。
- **2026-10-24 Docker 网络现场限制：**已有大量历史隔离测试网络，占满 Docker 默认 IPv4 地址池。初次试点恢复在 `docker network create` 前后因 `all predefined address pools have been fully subnetted` 退出；未删旧网络。只读核对已分配网段及 Ubuntu 路由后，续版恢复使用新的 `10.251.24.0/28` 内部网络，完成新卷恢复并停止测试容器，保留卷和网络。试点在线网络仍是 `192.168.240.0/20`，原测试/预发布未动。

- **2026-10-26 助手 NAS 操作尝试（自动审批前置拒绝）：**本地包装器核对 `transfer_pilot_nas.py` SHA-256 为 `c9846e57be94c72fad0100eaa29a8e996bb2f0ff824f8d0290850d46a2e35812`。提交的远端命令拟连接 `10.0.30.5`，把固定试点空库备份复制到 `10.0.30.6:/teacher-workbench-backup` 的新目录。自动审批在创建进程前拒绝，理由是当前可见授权未明确覆盖数据库/私有归档/镜像/源码文件及目标 NAS。脚本未上传，SSH/SCP/sudo 未开始，NAS 未挂载，现场无变化。

- **2026-10-26 明确授权后助手 SSH 现场：**源 `10.0.30.5` 通过专用 NFS v4 将固定初始空库数据写入 `10.0.30.6:/teacher-workbench-backup/pilot-data-Wz0wCERi-93f655b6bfe6`，再以只读挂载导回 Ubuntu 私有目录；两次挂载均按脚本卸载。NAS 来源在同机新 Docker 网络 `10.251.25.0/28` 与新卷恢复，测试容器停止、卷保留。在线 `https://10.0.30.5:18443/login/` 和原预发布 `http://127.0.0.1:18002/login/` 在恢复后均返回 200。Windows 当前用户对试点 CA 的只读检查仍显示未信任，浏览器与家外客户端待验。

- **2026-10-26 Windows 当前用户根 CA：**用户授权固定试点公有根 CA 后，助手两次尝试安装均在 Windows 证书导入阶段等待；已停止挂起进程。只读复查仍为 `PILOT_CA_NOT_TRUSTED_FOR_CURRENT_USER_NO_CHANGE`，所以该 Windows 用户的浏览器信任仍未通过。下一步在用户可见终端由用户本人处理系统确认，再复查；其他设备的证书信任与 EasyTier 家外连通各自待验。
