# EasyTier 私网 HTTPS 试运行

**2026-10-29 当前状态：**在真实教师账号、主动生成和教师卷 WPS 验收后，用户明确要求上线；保留本页所述独立私网 HTTPS 栈原项目名与数据卷，指定为[私网限定正式使用版](release-2026-10-29.md)。本页较早的“仅虚构账号、AI 关闭”句子是历史阶段记录，不代表当前线上状态。

**2026-10-28 08:01 后续核对：**本机备份健康 timer 首次自然触发并于 08:01:58 成功结束，日志确认最新配对快照与备份 timer 健康。已授权 NAS 转存 timer 仍 active，下次计划 2026-10-29 04:31:54；首份后续新快照的 NAS 写入与独立恢复仍待实际验收。

**2026-10-28 每日 NAS 转存更新：**用户明确授权后，助手已安装 root 专用转存服务与每日 04:30 定时器。07:54 受控运行只核对已有固定快照的 NAS 副本并卸载挂载，service success/状态 0；尚未见证第一份后续新快照的自然写入和恢复。试点 HTTPS 登录页在 Windows 严格 TLS 检查仍 200。分离的模型主密钥、环境配置和 CA 托管不写 NAS。

**2026-10-28 安装前进度（历史状态）：**本机备份 timer 于凌晨自然触发且 service 成功，但因上一份快照不足 18 小时，按预期跳过生成第二份；手动只读健康检查通过，上午健康 timer 当时尚未自然触发。试点四容器运行、迁移至 `0008`、Windows 经 EasyTier 严格 TLS 登录页 HTTP 200。后续快照 NAS 复制程序已完成代码和只读预检，授权策略文件不存在、没有安装自动复制 timer，也没有新的 NAS 写入。

**2026-10-27 容量进度：**本机定时备份和健康定时器均 active，最近服务结果 success；新增只读容量审计在 Ubuntu 返回完整配对快照 1、未完成 0、孤立托管 0、约 44 GiB 可用。基于当前约 278 MiB 的快照，扣除 12 GiB 停止阈值后静态估计还能容纳约 116 份同等大小副本。资料增长会改变该估计；未启用自动清理、每日 NAS 复制或外部告警。

**2026-10-27 首份定时快照 NAS 结果：**用户对 `backup-pilot-2kgUgmXV` 的十个数据文件、指定 NAS 目标、只读导回和 U 盘返回托管配对新卷恢复给出固定范围授权。助手直连 Ubuntu 完成 NAS 新目录 `pilot-scheduled-data-2kgUgmXV-a557dddc7c8e` 的十文件转存、十二文件只读导回及独立恢复；两名虚构账号、一份 Word、下载哈希及跨账号拒绝通过，恢复容器已停，在线双站登录页仍 HTTP 200。首次 `copy` 因旧授权不足被自动审批拒绝，随后在新授权下成功。每日自动 NAS 转存、版本清理、外部通知与空白主机重建仍未完成；详见[运行手册](runbook.md)。

**2026-10-27 新增现场结果：**试点已启用每天 Asia/Shanghai 03:30（最多随机延迟 10 分钟）的 root 私有本机配对备份，以及每天 08:00 的本机备份健康检测。首次完整备份、分离托管哈希和定时器检查通过，重复触发安全跳过；该新快照又在新网络和新卷独立恢复两账号、一份 Word 与权限隔离，详情见[运行手册](runbook.md)。下文旧进度语句中“无周期备份”指此前状态；目前尚无自动 NAS 转存、多版本清理、外部故障通知或空白主机重建，不能据本机备份宣布正式发布。

更新：2026-10-27。目标是让已验收的有限功能在独立地址上接受网络与浏览器核验。**技术试点已在 Ubuntu 257 的独立数据库启动，AI 关闭；目前接入两名虚构账号及一份虚构 Word，无真实账号或教学资料，不能称为正式上线。**当前 Windows 用户已信任固定指纹 CA，用户浏览器已验收虚构管理账号登录、成员页和退出；用户进一步澄清当前设备正经 EasyTier 访问试点地址，并在该地址确认虚构 Word 上传、刷新后仍在列表、下载打开三项正常。用户又以普通成员登录，确认不见管理账号资料且原下载链接返回普通 404；助手只读核对该链接的资料 ID 正确。旧单账号快照 `backup-pilot-6A76GMeO` 的本机恢复、NAS 数据往返及 U 盘托管配对恢复通过。新增成员后的 `backup-pilot-YvI69NlE` 也完成本机配对备份、独立新卷恢复、用户固定范围授权的 NAS 十文件转存与只读导回，并用 U 盘返回托管完成 NAS 来源新卷恢复；两账号、资料内容和权限隔离通过。仍无空白主机重建、周期备份/告警、其他客户端及物理家外位置的单独验收。此方案不改变现有 `127.0.0.1:18002` 预发布，也不改 PVE、LXC 140、Cloudflare 或 DNS。

**现场进度（助手直接 SSH，2026-10-24）：**只读预检来自用户终端；随后助手获用户授权连接 Ubuntu 257，拉取 Caddy、准备独立配置、迁移空库并启动四服务。首次严格 HTTPS 探针因 IP 客户端没有 TLS SNI 而失败；仅重建试点 Caddy 网关、设置 `default_sni 10.0.30.5` 后，服务器用试点 CA 严格验证登录页与静态文件均为 HTTP 200，原预发布登录页仍为 200。Windows 到 18443 的 TCP 通、使用指定 CA 的证书链和 IP 校验通过；Windows 内部 CA 没有撤销服务，curl 检查时使用 `--ssl-no-revoke`。Windows 当前用户根证书库尚未信任此 CA，浏览器登录未验收。

试点初始配对备份 `/home/huahua/teacher-workbench-pilot-backups/backup-pilot-Wz0wCERi` 与分开的本机密钥/CA 托管 `/home/huahua/teacher-workbench-pilot-key-escrow/escrow-Wz0wCERi` 已由助手直接执行并校验。首次独立恢复因 Docker 默认网段池耗尽，在创建网络前停止；续版使用独立 `10.251.24.0/28` 小网段，在新卷恢复数据库、Redis、私有文件和 Caddy CA，核对空库迁移与登录页，测试容器停止、卷保留。**这证明同机初始空库可恢复，不证明有用户内容的恢复或整机灾备。**NAS 数据转存曾被自动审批阻止，用户 2026-10-26 明确授权固定源和目标后已完成 NAS 数据复制、只读导回及同机新卷恢复；细节见下方记录。

## 范围

- 地址固定为 `https://10.0.30.5:18443/`，只使用现有 EasyTier 私网路由，不需要域名。Docker 网关只绑定 Ubuntu 的 `10.0.30.5`，Web 和数据库不发布宿主端口。Caddy 为 IP 签发内部 CA 证书，服务器端先用该 CA 严格验证登录页及静态文件；每台客户端仍须单独安全导入并验证 CA，才能正常登录。来源：[Caddy 内部证书](https://caddyserver.com/docs/caddyfile/directives/tls)、[其他设备信任要求](https://caddyserver.com/docs/running)。
- `teacher-workbench-pilot` 使用全新数据库、Redis、私有文件、静态资源、Caddy 数据卷、Django 密钥和模型密钥目录；不复制预发布用户、资料或 Key。应用镜像锁定到已备份的当前预发布镜像 ID，正式 Django 配置关闭 DEBUG，所有 AI 模式关闭，数据库迁移只对试运行新库执行。不能把此项理解为完整第一版或真实 AI 已可用。
- `compose.production.yaml` 的域名方案仍是另一个未发布草案。此次选择独立 IP HTTPS 试运行，不把旧测试栈改名为正式站。

## 本地准备与现场顺序

以下三个 Windows 入口脚本是首次部署的历史操作，已执行，**不要重跑一次性准备或启动**。实际 SSH 密码及 sudo 密码只在交互终端输入，未写入命令或项目文件。

1. 只读预检：在 Windows PowerShell 执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_pilot_readonly.ps1"`。它只在 Ubuntu `/home/huahua` 上传一个检查脚本，不改容器、数据库或网关。成功需见 `PILOT_READONLY_PREFLIGHT_OK` 和 `PILOT_PREFLIGHT_WRAPPER_DONE`。若报告 `PILOT_PREFLIGHT_CADDY_IMAGE_MISSING`，准备步骤会尝试只拉取 `caddy:2-alpine`，随后锁定镜像 ID；若网络拉取失败则停下。
2. 准备配置：执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_prepare_ubuntu_pilot.ps1"`。仅在独立私有目录生成随机凭据、独立密钥、固定镜像配置并让 Docker/Caddy 校验配置；**不启动站点**。成功需见 `PILOT_CONFIG_AND_CADDY_VALIDATED`、`PILOT_CONFIG_PREPARED_NO_START` 和包装器完成标记。不得把 `.env.pilot`、`v1.key` 或 Docker 展开配置贴到聊天。
3. 启动技术试运行：执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_start_ubuntu_pilot.ps1"`。仅创建独立卷，在空库执行迁移并启动独立 HTTPS 网关。成功需见 `PILOT_DATABASE_AND_REDIS_HEALTHY`、`PILOT_HTTPS_LOGIN_AND_STATIC_TRUSTED_LOCALLY_200`、`PILOT_STAGING_LOGIN_STILL_HTTP_200`、`PILOT_STARTED_SEPARATE_AI_OFF` 和包装器完成标记。脚本输出内部 CA 的 SHA256 指纹及服务器上的公有根证书路径；不输出密钥。

执行位置、用户名、端口和源备份均由脚本固定。现有试点若需停机，可运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_pilot_stop.ps1"`，仅停止试运行容器并保留卷和密钥。已成功运行的预发布不受此操作影响。**不要执行 `docker compose down -v`。**

## 接入真实用户前的闸门

1. 在家外实际 EasyTier Windows 设备确认 `10.0.30.5:18443` 可达；公有根证书本地副本为 `D:\Projects\teacher-workbench\data\pilot-public-ca.crt`（被 Git 忽略）。助手已核对其 X.509 SHA-256 指纹为 `1BD4D9B8393BFCBCB3E9FF03C3236E47810F91D852E907ED91CE38C0F6944789`。从可信通道领取并在另一设备先核对指纹，再安装到该设备的受信任根证书库。浏览器需要显示证书有效、IP 匹配，不能通过“忽略证书错误”来登录。Firefox 或其他设备的信任库须分别核对；Caddy 的内部 CA 不会自动被远端设备信任。
2. 以虚构账号在该 HTTPS 入口完成登录、登出、上传与下载、跨账号拒绝及 CSRF POST 复核；检查旧预发布和旧测试站仍可用。手机、学校电脑和 WPS 的效果由用户现场验收。
3. 为试运行独立数据、应用镜像及独立密钥制定配对备份，并从 NAS 副本在新卷恢复成功；另定自动周期、保留与失败告警。当前预发布的 NAS 恢复**不能**代替试运行新库的备份与恢复。完成前不迁入真实账号、教学资料或真实 Key。
4. 实际启用 AI 还需单独完成密钥授权、额度闸门、厂商账单核对和付费调用授权。本方案保持 AI 关闭。

此页用于降低部署动作的遗漏。它没有替代 [需求](requirements.md)、[正式发布闸门](production-readiness.md) 或 [验收记录](acceptance.md)。

**2026-10-24 客户端证书待办：**已把服务器公有根证书复制到当前 Windows 的临时目录，并核对上文运行手册记录的 SHA256 指纹。`scripts/trust_pilot_ca_current_user.ps1` 默认只读检查，现场返回 `PILOT_CA_NOT_TRUSTED_FOR_CURRENT_USER_NO_CHANGE`。它的 `-Install` 模式只给当前 Windows 用户安装这张 CA，但安装根证书会扩大该用户的信任范围，尚未获得明确授权，也未执行。浏览器页面、登录和异地设备不能以服务器 curl 成功替代。

**2026-10-26 NAS 操作重审：**用户回复“允许”后，助手提交了固定试点空库数据包复制脚本。自动审批仍拒绝，因为它认为当前可见授权未具体指明传输内容和 NAS 目标。该拒绝发生在命令启动前；脚本未上传，NAS 未挂载或写入。当前要继续 NAS 步骤，用户需一次性明确授权只转存 `/home/huahua/teacher-workbench-pilot-backups/backup-pilot-Wz0wCERi` 的固定初始空库数据文件到 `10.0.30.6:/teacher-workbench-backup` 新建目录，排除同机密钥/CA escrow，并允许后续只读导回校验。

**2026-10-26 NAS 来源空库恢复完成：**用户随后明确授权上述固定源、NAS 目的地与只读导回。复制的新目录为 `pilot-data-Wz0wCERi-93f655b6bfe6`，全部 10 个数据文件逐项通过 SHA-256；只读导回到 `/home/huahua/teacher-workbench-nas-import-pilot-data-Wz0wCERi-93f655b6bfe6`，12 个文件核对通过。新隔离网络和卷的恢复演练核对数据库迁移、业务表为空、Redis/私有文件/CA 和登录页；测试容器停、卷保留，在线试点与预发布登录页仍 200。配对密钥与 CA 只留在 Ubuntu 的分离托管。仍需实际浏览器信任及用户流程、周期备份和异机重建证据；此空库演练不代表真实资料恢复。

**2026-10-26 当前 Windows 用户证书安装待系统确认：**用户授权安装上文固定指纹的 CA。助手脚本已核对指纹及 CA 属性，但 `Import-Certificate` 在两种终端调用中等待、没有成功标记；两次挂起进程均已终止，`Cert:\CurrentUser\Root` 只读复核未见证书。须在用户可见的 Windows PowerShell 运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\trust_pilot_ca_current_user.ps1" -Install` 并由用户本人处理 Windows 系统安全确认。完成标记应为 `PILOT_CA_TRUSTED_FOR_CURRENT_USER`，随后助手再核对系统信任及 HTTPS 页面。不要点浏览器证书错误的“继续访问”。

**2026-10-27 当前 Windows 用户证书信任技术通过：**用户在可见终端返回 `PILOT_CA_PUBLIC_CERT_FINGERPRINT_AND_TYPE_OK`、`PILOT_CA_TRUSTED_FOR_CURRENT_USER`。助手随后在用户实际 Windows 账号下只读复核 `PILOT_CA_ALREADY_TRUSTED_FOR_CURRENT_USER`；固定公有 CA SHA-256 为 `1BD4D9B8393BFCBCB3E9FF03C3236E47810F91D852E907ED91CE38C0F6944789`。不指定 CA 文件且不跳过 TLS 校验的 Windows 系统信任请求返回 `PILOT_WINDOWS_SYSTEM_TRUST_HTTP=200 SSL_VERIFY=0`。此前助手受限进程运行在另一 Windows 沙盒账号，该账号的 CurrentUser 根证书库不是用户的根证书库。浏览器页虽已请求在应用面板打开，但尚无用户实际登录、上传或下载结果；其他设备仍须分别核对 CA 信任与 EasyTier 连通。

**2026-10-27 虚构试点管理账号准备：**本机新增 `scripts/prepare_ubuntu_pilot_manager.py` 和 `scripts/create_ubuntu_pilot_manager.sh`，只接受独立试点空库、固定镜像、AI 关闭和交互式终端；在密码输入前检查试点库没有用户，成功时创建非 staff、非 superuser、仅有成员管理权限的虚构账号 `pilot_manager_20261026`。两文件已上传 Ubuntu `/home/huahua/`，远端 SHA-256、Bash/Python 语法和试点配置检查通过。**脚本尚未执行，账号尚未创建；密码只能由用户在自己可见的 Ubuntu 终端输入。**账号一旦创建，之前的初始空库备份及其 NAS 副本就不再反映当前试点数据，需另做新的配对备份和恢复验收；既有 NAS 授权只覆盖固定初始空库数据包。

**2026-10-27 账号及备份现场结果：**用户终端确认脚本创建 `pilot_manager_20261026` 完成，密码未发给助手；用户浏览器确认登录、成员账号页和退出均正常。助手 SSH 只读核对试点仅有此一用户、启用、非 staff/非 superuser、仅授予 `manage_members`，AI 关闭。新本机配对备份 `backup-pilot-Lx7aqLEz` 与独立 escrow 完成校验；在隔离新卷恢复账号、权限、迁移、CA 和登录页通过。用户随后对这份含虚构账号密码哈希的固定数据包单独授权 NAS 转存及只读导回。新 NAS 目录 `pilot-manager-data-Lx7aqLEz-9037d08db8d9` 的 10 个白名单文件校验通过，只读导回的 12 文件校验通过；使用导回数据与原 Ubuntu 本机 escrow 在新隔离卷恢复通过。两次测试恢复容器均停止、卷保留，在线试点和预发布登录页保持 200。**escrow 未离机；同机恢复不等于原主机丢失后的灾备。**仍需定时备份/告警、异机密钥恢复、其他 EasyTier 客户端与真实业务验收。

**2026-10-27 密钥托管准备：**固定 escrow 的离线加密包和 USB 往返脚本已写，Ubuntu 上只上传了不含秘密的代码；本机及固定试点镜像均通过虚构内容的加解密测试。真实 escrow 的导出与 USB 操作尚未执行，须按[运行手册](runbook.md)取得该项单独授权并由用户输入离线口令。包会含数据库/Django 配置、模型主密钥及 Caddy CA 私钥；绝不把明文包写入 NAS。
