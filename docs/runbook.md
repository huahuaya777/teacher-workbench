# 运行手册

## 2026-11-08 资料库和 AI 出题版本

**本机操作。**在 Ubuntu 开发机的独立 rootless Docker 上以应用允许清单构建 `huahua777/teacher-workbench:2026.11.08`。通用镜像的原地升级须按[双卷备份与升级](docker-deployment.md#数据备份和升级)操作；启动新镜像时显式设 `TW_APPLY_MIGRATIONS=1`，确认健康后恢复为 `0`。通用旧镜像会拒绝较新的数据库架构；如需降级，使用升级前匹配的双卷快照。 另从同一提交构建本机分服务应用候选 `teacher-workbench-pilot-web:release-20261108`，以禁网容器运行 Django 检查和 23 项资料、成员及正式成果专项，全部通过。候选尚未传输到线上。

**Docker Hub 发行，已执行。**用户在本人 Chrome 完成设备登录后推送固定版 `2026.11.08`，用空登录配置拉取确认摘要，再更新并匿名验证 `latest`。两标签摘要均为 `sha256:994027c3814a6026c94b402478f43a035cea0d7f7f5ba5181cac6194bc7f92ef`。

**Ubuntu 257 上线准备，尚未执行。**使用项目中已核对的 SSH 主机公钥验证 `10.0.30.5`，非交互登录被拒。恢复 SSH 管理访问后，先只读确认线上 Web、worker 镜像、DB 迁移、空任务队列、HTTPS 和备份健康。按[私网上线记录](release-2026-10-29.md)继续使用原分服务 Compose、数据库、Redis、私有文件卷、密钥和 CA。仅使用候选代码离线重建应用镜像并跑隔离验证。正式切换前，在维护窗口用现有 `/usr/local/libexec/teacher-workbench-pilot-backup --force` 建立新配对快照，核对数据库、原件、旧镜像及分离托管清单，记录旧镜像 pin；保持私网入口暂停写入并再次确认队列为空。仅在验证后的候选镜像中对原 DB 执行 `python manage.py migrate --noinput` 并核对 `0009`、`0010`，然后同步切换 Web 和 worker，复核成员模式闸门、HTTPS、静态资源、迁移与旧资料。失败先保留原快照并停写，根据失败点恢复旧应用 pin 或配对数据；恢复快照会回到备份时间点。正式站无需导入通用单容器镜像的 PostgreSQL 或 Redis。

**2026-11-06 通用 Docker 独立部署与发行：**在 Ubuntu 开发机使用本项目独立的无 root Docker 29.9.2 和 Compose v5.7.0，从应用允许清单构建新镜像。在新双卷及本机回环 18880、18881 分别完成 `docker run` 与 Compose 首次启动、健康检查和虚构内容验证。Compose 以同一对卷重建后复验通过，随后停止两个验收容器并保留测试卷。部署命令、管理员初始化及配对卷备份见[通用 Docker 部署](docker-deployment.md)。 两个标签已上传 Docker Hub，空登录配置拉取和摘要核对成功，公开仓库已填写部署说明。

**2026-10-30 迁移文档 GitHub 同步：**首次两次推送因 Windows 到 github.com:443 连接失败而停止；网络恢复后，将已审查的迁移结果和 Ubuntu Codex 项目验收提交推送至现有私有仓库 main。Ubuntu 目标机的本地提交仍通过已校验 Git bundle 同步；该机自身 GitHub HTTPS 认证尚未配置。

**2026-10-30 Ubuntu 开发机迁移实际操作：**Windows 经 SSH/SCP 将 Git bundle、55 文件的私有归档和逐文件摘要清单传至目标机 `/home/huahua/teacher-workbench-migration-20261030-3194b3f`，三份文件的远端 SHA-256 与源端一致。目标机从 bundle 克隆到 `/home/huahua/projects/teacher-workbench`，设置私有 GitHub HTTPS `origin`，解包私人文件并逐文件校验，权限仅限 `huahua`，Git 工作区干净。使用目标机 Python 3.14.4 新建 `.venv`，从公开 PyPI 安装锁定依赖；`DJANGO_DEBUG=1 AI_ENABLED=0` 下 Django 检查和 108 项业务测试通过（4 项跳过）。仅对复制的开发 `data/dev.sqlite3` 做备份并应用未执行的 `workbench.0004`～`0008` 迁移，完成后迁移状态与 SQLite 完整性核验通过。**未复制 Codex 凭据/聊天数据库，未连接线上数据库，未执行付费调用。**目标机 GitHub 登录与 Codex 图形界面项目打开待完成。

**2026-10-30 Ubuntu 开发机迁移预检（仅只读，无部署）：**按用户授权尝试从 Windows SSH 连接 `huahua@10.0.30.7`，在进入密码提示前超时；Windows TCP 22 探测失败。再通过既有 `10.0.30.5` SSH 只读运行 ping 与 TCP 22 测试：ping 1/1 成功，`nc` 报 `Connection refused`。因此未在目标机创建目录、上传文件或改变服务。后续步骤与验收界限见[迁移说明](migration-ubuntu-dev-2026-10-30.md)。

**2026-10-29 GitHub 私有仓库发布（本机已执行）：**用户明确要求发布到 GitHub，覆盖此前暂不建远程的计划。已初始化本地 `main`，在 `huahuaya777` 账号创建 Private 仓库 [teacher-workbench](https://github.com/huahuaya777/teacher-workbench)；Git Credential Manager 既有登录仅在内存中用于 GitHub API 建仓，没有输出或存储访问令牌。暂存清单经忽略规则、文件类型、疑似密码/Token/私钥扫描，教学样本、数据、密钥、证书和备份未纳入；`git diff --cached --check` 通过。首次提交 `d0c023a05faa764363c498ce59399f6cec651b9f` 推送到 `origin/main`；GitHub API 返回 Private、默认分支 `main`、远端提交与本地一致、378 个文件且禁入路径 0。后续文档状态补记作为单独提交同步，不触及服务器业务数据。

**2026-10-29 私网正式入口文案修复与最终恢复演练（助手直连现场已执行）：**本机[登录模板](../templates/registration/login.html)和[公共模板](../templates/base.html)与原线上文件摘要一致后只改两处文案。最小源包 `scripts/teacher-workbench-pilot-release-copy-20261029.tar.gz` SHA-256 `89261758aeefaca195b3f804892853f21f698e91a5be49fc013936097321206a`，远端校验后由[断网构建脚本](../scripts/build_ubuntu_pilot_release_copy.sh)生成镜像 `sha256:1e2906b9799a04638c258eaa585e047abe081608172936e0cd77677f5c870e88`，Django 检查及 106 项测试运行（102 项通过、4 项条件跳过）。切换前停写配对备份 `backup-pilot-i6EcyzB8`/`escrow-i6EcyzB8`，由[切换脚本](../scripts/apply_ubuntu_pilot_release_copy.sh)核对摘要、队列、在线 HTTPS 后切换 Web/worker，输出 `PILOT_RELEASE_COPY_DEPLOYED_HTTPS_AND_OLD_STAGING_HTTP_200`。切换后强制备份 `backup-pilot-37aXRxFX`/`escrow-37aXRxFX`；NAS 服务 success/0，十文件副本 `pilot-scheduled-data-37aXRxFX-f0a7fd43c60c`，读挂载导回十二文件且 `NAS_MOUNT_CLEANED`。固定[独立恢复脚本](../scripts/restore_ubuntu_pilot_release_copy_nas_20261029.sh) SHA-256 `9d626005921ca3255c87c38ce758380aa6f3d1cd221e792e0cfe7c586291a3dd`，远端摘要与语法通过，在 `10.251.40.0/28` 新内网和新卷恢复账号、Key、私有边界、草稿、Word 公式及新登录文案；最终 `PILOT_RELEASE_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`，目录 `/var/lib/teacher-workbench-pilot-scheduled/release-restore-f0a7fd43c60c`，恢复 DB/Redis 已停、卷保留。线上双镜像运行，Windows EasyTier HTTPS 200/TLS 验证码 0，三 timer enabled/active、备份健康通过。本次无数据库迁移，无付费 AI 请求。文案代码回退可用上一镜像 `sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64`；数据回退单独依配对备份与托管，不能混为一谈。

**2026-10-29 私网限定版发布（助手直连现场已执行）：**用户要求上线，采用已通过真实账号与教师卷验收的 `teacher-workbench-pilot` 独立 HTTPS 栈，保留现有项目名/数据卷/端口，未运行域名版 `compose.production.yaml`。发布前存储只读审计为完整配对快照 8、未完成 0、孤立托管 0、根分区约 41 GiB 可用；五服务、三项 timer 和备份健康检查通过。执行已安装 `/usr/local/libexec/teacher-workbench-pilot-backup --force`，短暂停写并重启五服务，生成新快照 `/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-kfA4vmDj` 与分离托管 `.../escrow/escrow-kfA4vmDj`，最终 `PILOT_SCHEDULED_LOCAL_BACKUP_VERIFIED`。已授权 NAS service `Result=success`、退出 0，十文件校验及挂载清理，副本 `pilot-scheduled-data-kfA4vmDj-8885b673fb19`。本地[只读导回脚本](../scripts/import_ubuntu_pilot_scheduled_nas.py) SHA-256 `e624a9e3f711197a8381e4e91cc9212045e68c85a6c075ecc1a31031f98f0e82` 上传至新文件，远端摘要/语法核对后导回十二文件到 root 私有目录，`PILOT_RECURRING_NAS_IMPORT_DONE`、`NAS_MOUNT_CLEANED`。专用[隔离恢复脚本](../scripts/restore_ubuntu_pilot_release_nas_20261029.sh) SHA-256 `ba75db36949724214aa8beebdbce6843baa128854159da6425a8d0e3cc2ccc49`，远端摘要/Bash 语法通过；使用本机配对托管和新卷恢复，得到 `PILOT_RELEASE_RESTORE_ACCOUNTS_KEY_DRAFT_AND_ACCESS_OK`、教师卷无原始数学标记、10 个 OMML 分式及 `PILOT_RELEASE_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`，恢复 DB/Redis 停止、卷保留，目录 `.../release-restore-8885b673fb19`。最后只读审计 Web/worker 均运行且为 `sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67cd783c39e64`，成员 AI 环境闸门、账号/额度、配对备份健康通过；Windows EasyTier HTTPS 登录页 200、TLS 验证码 0。**旧导回脚本未在服务器存在，首次尝试在摘要检查前安全停止，随后上传为新文件名并成功；没有因失败挂载 NAS。**本轮无付费请求。发布范围、回退及限制见[发布记录](release-2026-10-29.md)。

**2026-10-29 07:54 教师答案公式热修复（助手直连现场已执行）：**依据用户教师卷截图定位 Word/预览数学标记解析缺口；本机 108 项业务测试通过（4 项条件跳过），虚构 Word 的 OOXML 有分式、下标和根式；本机缺 LibreOffice，未完成自动图像渲染。只含白名单源码的构建包 SHA-256 `af1ed96be46c55e16384e8b14508683bcef29306fa600c0b9bdbf745808d8e5b`，远端断网从旧镜像 `sha256:7f81c32b41368bf26c5f85a9f4fd602ee6393360ba1f4a8f8b0a75d93a675bf5` 构建候选 `sha256:62d562eeeb3f702bf73761ff91ad211c86ca14fc96abe67faed67cd783c39e64`，镜像内 10 项专项测试及 Django 检查通过。切换前强制停写配对备份 `/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-LSlJR5do` 与分离托管 `.../escrow/escrow-LSlJR5do`；NAS service 成功复制并校验十个数据文件，副本 `pilot-scheduled-data-LSlJR5do-4c549aea2551`，不含分离托管。固定[切换脚本](../scripts/apply_ubuntu_pilot_member_ai_math.sh) SHA-256 `e14ec371e12363148474e8415f1254d9f2c15fec7114ec01428fee9d26a80b70` 通过远端摘要与语法检查，以备份和队列空闲为闸门切换 Web/worker；异常时回退旧镜像 pin，数据恢复仍须用配对备份与托管单独处理。成功标记 `PILOT_MEMBER_AI_MATH_DEPLOYED_AND_OLD_STAGING_HTTP_200`，在线只读[草稿审计脚本](../scripts/audit_pilot_teacher_math_export.py)返回 `PILOT_SAVED_DRAFTS_MATH_PREVIEW_AND_WORD_CLEAN`、1 个版本、10 个 Word OMML 分式。切换脚本核对 HTTPS、旧预发布、CSS 与新镜像；Windows EasyTier 登录页再验 200、TLS 验证码 0。**未发起新 AI 调用、未改数据库、未对新 NAS 副本只读导回恢复；旧已下载 Word 不会自动改变，须重新下载。**

**2026-10-29 07:35 成员 Qwen 长度修复二次部署（助手直连现场已执行）：**用户任务页截图证实第 3 次响应达到输出长度上限；只读审计显示额度已用 3、3 条失败任务和未知调用，队列与处理中均为 0。代码要求先生成 3 题、缩短题干及答案并完整闭合 JSON；成员上限由 3000 提至 6000 tokens（夹限 8000），不自动重试。白名单源码包 SHA-256 `fc1395ab65097738a83602ec9f6e4e6efece4bdc73eb49063939d15ea642f414`；首次离线构建脚本误将裸镜像 ID 用于 Dockerfile `FROM`，构建失败但在线未切换；v2 改用已核对的本地标签后断网构建候选 `sha256:7f81c32b41368bf26c5f85a9f4fd602ee6393360ba1f4a8f8b0a75d93a675bf5`，镜像内 14 项及 Django 检查通过。本机专项 16 项、完整回归 107 项通过（4 条件跳过，测试库销毁）。切换前强制停写生成配对备份 `backup-pilot-XgXQqIBU`/`escrow-XgXQqIBU`；已授权 NAS 服务复制十数据文件并核验副本 `pilot-scheduled-data-XgXQqIBU-1c839ac81a6b`，挂载清理。固定[切换脚本](../scripts/apply_ubuntu_pilot_member_ai_compact.sh) SHA-256 `c2d7e1cfd5023b24024f99d330ef04ddb5a9da0ea11cc69aa5d253a74199db5e`，远端摘要和 Bash 语法通过，以该备份为闸门切换 Web/worker，失败可回退旧镜像 `sha256:7d85997d168c880e059069b537d5a3b9029b3b8b20682968d98fb408b8fda34f`。最终标记 `PILOT_MEMBER_AI_COMPACT_DEPLOYED_AND_OLD_STAGING_HTTP_200`；在线 worker 专项审计确认为 6000，双镜像运行、账号记录不变，Windows EasyTier HTTPS 登录页 200/TLS 验证码 0。旧审计脚本仍按最多 4000 断言而失败；新只读审计脚本按 6000 复跑成功。**没有由助手发起付费请求，浏览器端到端仍待新任务验收。**

**2026-10-29 01:50 成员 Qwen 输出长度修复（助手直连现场已执行）：**原在线 worker 只读审计显示每次上限 1500 tokens；结合用户百炼汇总图的两次约 3000 输出 tokens，怀疑达到上限，但尚无单次 `finish_reason` 证据。新增成员专用 `AI_MEMBER_MAX_OUTPUT_TOKENS` 默认 3000、最大 4000，明确处理返回的 `finish_reason=length` 和非正常结束；旧进程级上限保持 1500。包含 `config/settings.py`、`workbench/ai.py` 与测试的源包 SHA-256 `183023e0ac1f86ddadc8d29bdd5b8e46d48efd19410224522d8813adb1911dfc`，离线基于已验热修复镜像构建候选 `sha256:7d85997d168c880e059069b537d5a3b9029b3b8b20682968d98fb408b8fda34f`，镜像内 14 项、本机 16 项测试通过；首次构建会话等待 sudo 超时，未影响在线，随后从已核对源目录继续并成功。切换前运行已安装备份程序 `--force`，生成 `backup-pilot-BQ9zzu8R`/分离托管 `escrow-BQ9zzu8R`；NAS 复制服务成功生成仅含数据的 `pilot-scheduled-data-BQ9zzu8R-0dac6332a847`。固定[切换脚本](../scripts/apply_ubuntu_pilot_member_ai_length.sh)远端 SHA-256 `0761322651237264e9b2358d609bb14b516e231b95f489757aa2a968b26c5d0d`、Bash 语法通过，以该快照为闸门执行，Web/worker 同为新镜像、环境检查通过、HTTPS 与旧预发布登录页 200。错误路径可回退旧镜像 pin `sha256:8e8bda29bac804dd58a0948b49074242153aa783660d8a8cca6d3eb34a89dba6`；数据库另按配对快照恢复。上线后 worker 输出 `PILOT_AI_MEMBER_MAX_OUTPUT_TOKENS=3000`，账号/额度记录未变；未主动发起付费请求。**待用户以虚构资料主动复测后再判定生成是否通过，若仍失败只取安全错误类别排查。**

**2026-10-28 21:09 成员 AI 试点与错误分类热修复（助手直连现场已执行）：**先做初始配对备份、NAS 转存和独立新卷恢复，再启用独立 worker；成员 Key 只经网页由所有者保存，进程级 Key 为空。用户自行触发的前两条任务失败后，离线构建候选 `sha256:8e8bda29bac804dd58a0948b49074242153aa783660d8a8cca6d3eb34a89dba6`，本机 11 项新测试、断网容器 9 项既有测试及 Django 检查通过。切换前再做 `backup-pilot-9opYLVha` 与 NAS 数据副本 `pilot-scheduled-data-9opYLVha-e1ac8e33b880`；上传的 [热修复切换脚本](../scripts/apply_ubuntu_pilot_member_ai_ui.sh)远端 SHA-256 `643e50483a93d8b548a51f450f6c6f8e0e3f5019c5f795e1d9ddbf9cb298dfdb`、Bash 语法通过，以该固定快照为闸门执行，Web/worker 两容器启动并匹配新镜像，HTTPS、旧预发布登录页 200。脚本有错误回滚旧镜像 pin `sha256:181eb56df073e42983d00dffeb38395016d899bbbb5c507dcbf783982ee919a6`；**仅回退代码，不能当作数据库回退**。当前修复只让未来的应用自生成错误类别安全显示，不能重建前两次失败的原始返回；未自动重试、退款或改额度。

**2026-10-28 21:09 热修复后配对备份及 NAS 恢复（助手直连现场已执行）：**`sudo /usr/local/libexec/teacher-workbench-pilot-backup --force` 停止试点写入后生成 `backup-pilot-OVALSQWU` 与分离托管 `escrow-OVALSQWU`，重启后 HTTPS 正常。已授权 NAS 转存服务 `Result=success`、退出 0，数据副本 `pilot-scheduled-data-OVALSQWU-9dd23f3d010b` 的十个文件逐项核验，挂载清理；只读导回十二文件到 `/var/lib/teacher-workbench-pilot-scheduled/nas-import-pilot-scheduled-data-OVALSQWU-9dd23f3d010b`，源清单 SHA-256 为 `90b75b035e388c735002482aa87946e0ede98a0b49cbe80d9bab1e7280b015f1`。固定[独立恢复脚本](../scripts/restore_ubuntu_pilot_member_ai_real_nas.sh)远端 SHA-256 `800d9190cce184bbbb64f7714b296519f0e4977a48603615d64ce25c367b30e5`、语法通过；在 `10.251.38.0/28` 新内部网络及新卷配对先前从 U 盘返还的托管，核对三名账号、原虚构 Word、真实账号加密 Key 可解、额度上限 10/已用 2、两条失败任务/未知调用记录及访问隔离。最终 `PILOT_MEMBER_AI_REAL_NAS_USB_INDEPENDENT_RESTORE_VERIFIED`，目录 `/var/lib/teacher-workbench-pilot-scheduled/nas-restore-9dd23f3d010b`；隔离 DB/Redis 已停，卷保留。后续排错只读核对可运行 [失败分类审计](../scripts/audit_pilot_member_ai_failures.py)，它仅输出固定类别，不输出 Key、资料或厂商原始回复。**当前 AI 生成未通过，不应为排障自动重发请求。**

**2026-10-28 晚动态 NAS 导回工具准备与只读现场核验：**新增 [import_ubuntu_pilot_scheduled_nas.py](../scripts/import_ubuntu_pilot_scheduled_nas.py)，本机 SHA-256 `e624a9e3f711197a8381e4e91cc9212045e68c85a6c075ecc1a31031f98f0e82`，远端用户目录副本 `/home/huahua/import_ubuntu_pilot_scheduled_nas_e624a9e3.py` 已通过远端摘要、语法及旧 NAS 副本 `verify` 只读模式。它从 root 已安装、固定 SHA-256 的转存程序读取共享格式与源校验逻辑，只接受最新本机配对快照对应的 NAS 名称；`verify` 只读挂载并卸载，`import` 会在 root 私有目录新建导回副本。明晨如自动创建新副本，先核对两个 service 成功标记、最新快照名和 NAS 名，再用 `verify`；**新副本的 `import` 与独立恢复尚未执行，不能据旧副本的核验宣布通过。**本轮没有重启或修改在线应用。

**2026-10-28 08:01 健康定时器首次自然运行已通过：**`teacher-workbench-pilot-backup-health.timer` 于 08:01:57 触发，service 08:01:58 success/退出 0，日志 `PILOT_SCHEDULED_BACKUP_FRESH_PAIRED_AND_TIMER_ACTIVE`；下次 2026-10-29 08:03:21。NAS 转存 timer 下次 2026-10-29 04:31:54，仍 enabled/active。明天先查看本机备份 service 是否新建配对快照，再查看 NAS 转存 service 的 `NAS_BACKUP_NAME`、`NAS_MOUNT_CLEANED`、完成标记；若写入新副本，随后只读导回与独立新卷恢复。**这些明日步骤尚未执行，不得记为通过。**

**2026-10-28 每日 NAS 转存已安装，不要重跑一次性安装脚本：**用户明确授权未来每日 04:30（最多随机延迟 10 分钟）把最新完整试点快照的十个数据文件复制到指定 NAS 新目录，不含独立密钥/CA、不自动删除。`install_ubuntu_pilot_nas_replication.sh` 远端 SHA-256 `23ca6ac71e860066f2014c71908a7468f69bb6a5f712a5718828081467901399`，v3 程序 SHA-256 `4360636fb2ec061211be7739966d9ec7d785ad711f8f4b54e89a2b2440d2a442`；两者摘要及 Bash/Python 语法通过。安装脚本依次做本机健康/目标空闲检查、安装 root 专用程序和精确授权策略、`systemd-analyze verify`、受控启动复制 service、确认挂载清理，最后启用 timer。07:54 受控启动核对既有副本 `pilot-scheduled-data-2kgUgmXV-a557dddc7c8e`，service success/状态 0，`PILOT_RECURRING_NAS_ALREADY_VERIFIED`、`NAS_MOUNT_CLEANED`，无新 NAS 数据目录；timer enabled/active，试点 HTTPS 200。后续用 `sudo systemctl status teacher-workbench-pilot-nas-replication.timer` 和 `sudo journalctl -u teacher-workbench-pilot-nas-replication.service -n 80 --no-pager` 查看结果；**第一份后续新快照的自然转存、只读导回和恢复尚未验证。**

**2026-10-28 NAS 定时服务安装前草案（历史状态）：**更新后的动态转存脚本位于项目 [replicate_ubuntu_pilot_scheduled_nas.py](../scripts/replicate_ubuntu_pilot_scheduled_nas.py)，远端用户目录副本为 `/home/huahua/replicate_ubuntu_pilot_scheduled_nas_v2.py`，SHA-256 `dfc04fd0298df6a1a11cb32f083db23dc0a1e2fb6a917df6f7e20e23f269db81`；只读 `verify` 成功。未来每日 04:30 的 [service](../scripts/teacher-workbench-pilot-nas-replication.service)/[timer](../scripts/teacher-workbench-pilot-nas-replication.timer) 仅上传 `/home/huahua/`，SHA-256 分别为 `d0ba150687a8b5305cf2e8e75ab50ac9c800507a4704fc2a89e66c0b1de22218`、`4bbba82b0f67c37919d98a3b04a3daecdd6895c2de0f8974ba575b903823935b`，`systemd-analyze verify` 通过。服务器 `/etc/systemd/system` 下无对应单元，`/etc/teacher-workbench-pilot-nas-replication.policy` 不存在；未安装、未启用、未挂载/写入 NAS。将来若获得覆盖后续快照的明确授权，仍需先对固定新快照验证真实 NAS 写入、只读导回与独立恢复，再考虑定时启用；不能直接把草案当成已验证的每日异地备份。

**2026-10-28 今日定时与应用核对：**备份 timer 首次自然触发后 service success/状态 0，日志为 `PILOT_SCHEDULED_BACKUP_RECENT_SUCCESS_SKIP`，未建立新快照；当前最新仍为 `backup-pilot-2kgUgmXV`。手动只读备份健康与容量审计通过，四容器运行、迁移到 `0008`，Django `check --deploy` 只有已接受的 HSTS 子域/preload 警告，Windows 严格 TLS 登录页 HTTP 200。08:00 健康 timer 当时尚未自然触发，不把手动检查误记为定时验收。

**2026-10-28 动态 NAS 初版只读准备（历史结果）：**初版脚本上传 `/home/huahua/replicate_ubuntu_pilot_scheduled_nas.py`，远端 SHA-256 `b128870e603985111d26c46612f0c41267d5c20bfdf1714641b5e7ce317acd17`，`verify` 只读通过。本机初版 2 项单元测试通过。现用上方 v2 草案；服务器授权策略始终不存在，未运行 `copy`、未挂载/写入 NAS。旧固定快照的一次性授权不扩大到未来每日转存。

**2026-10-27 备份容量只读核查已执行：**[审计脚本](../scripts/audit_ubuntu_pilot_backup_storage.py) 已复制到 Ubuntu 的 `/home/huahua/audit_ubuntu_pilot_backup_storage.py`，远端 SHA-256 为 `5e85dfe7ae742753937855f446a39ff0001b27f9f9efc2043d4cb017a97b650b`；`sudo python3 -B` 运行一次得到 `PILOT_STORAGE_READONLY_AUDIT_OK`。脚本只核对本机快照和分离托管的目录/文件类型与权限、完成标记、尺寸和剩余空间；不重新计算归档哈希，归档完整性由现有备份健康检查负责；未排进定时器。输出 `ESTIMATED_MORE_COPIES=116` 按当前最新快照大小和 12 GiB 备份停止阈值计算，不能预测资料增长。出现 `REVIEW_REQUIRED` 时先核对日志、未完成目录和 NAS 来源恢复证据，不按数量自动删除。当前不执行清理。

**2026-10-27 首份定时快照 NAS 往返与恢复已执行，勿重跑一次性脚本：**用户明确授权固定 `backup-pilot-2kgUgmXV` 十个数据文件转存到 `10.0.30.6:/teacher-workbench-backup` 新目录，并只读导回、配对已返回的 U 盘托管在独立新卷恢复。`transfer_pilot_scheduled_first_nas.py` 远端 SHA-256 `6f3e645c759b85f44e05e2d87143a441a0a6c9d2cf023642fcc2e10f75fe370e`、`restore_ubuntu_pilot_scheduled_first_nas.sh` 远端 SHA-256 `3e7e1f46887410f0234720aef24fbde54d9a6d822302cae16327887e5d500576`，语法及固定源清单均通过。NAS 新目录 `pilot-scheduled-data-2kgUgmXV-a557dddc7c8e` 的十文件逐项校验，写挂载卸载；十二文件只读导回 `/var/lib/teacher-workbench-pilot-scheduled/nas-import-pilot-scheduled-data-2kgUgmXV-a557dddc7c8e` 并完成双清单校验，读挂载卸载。独立 `10.251.34.0/28` 网络、新卷恢复两名虚构账号、一份 Word、下载哈希和跨账号拒绝，`PILOT_SCHEDULED_FIRST_NAS_USB_INDEPENDENT_RESTORE_VERIFIED`、退出码 0；目录 `/var/lib/teacher-workbench-pilot-scheduled/nas-restore-a557dddc7c8e`，恢复 DB/Redis 已停、卷保留。原双站登录页仍 HTTP 200，备份及健康 timer 均 active。分离的主密钥、环境配置和 CA 托管未进入 NAS。首次 `copy` 因旧授权不足被自动审批在 SSH 启动前拒绝；上述操作是在用户补充这份固定快照授权后完成。**未来每日自动 NAS 转存、保留清理、外部失败通知和空白主机重建均未启用或验证。**

**2026-10-27 Ubuntu 257 试点每日本机备份已安装并运行：**`scripts/backup_ubuntu_pilot_scheduled.sh`（SHA-256 `4881ffa187fffebebc2a5a96201745d6284e5bf232e567c38229e0dad352b473`）与 `scripts/check_ubuntu_pilot_scheduled_backup.sh`（`aba9cab77d9173d0ed87aaa18be435544e6a5e4444c53ec90d174a88fd70a0ce`）上传到 `/home/huahua/` 后经远端摘要和 `bash -n` 检查，分别以 root 执行权限安装为 `/usr/local/libexec/teacher-workbench-pilot-backup` 和 `/usr/local/libexec/teacher-workbench-pilot-backup-health`。service/timer 固定文件安装到 `/etc/systemd/system/`，`systemctl daemon-reload` 和 `systemd-analyze verify` 通过（仅出现系统自带 xfs_scrub 旧选项警告）。首次 `systemctl start teacher-workbench-pilot-backup.service` 返回 success，日志完成标记及路径为 `/var/lib/teacher-workbench-pilot-scheduled/backups/backup-pilot-2kgUgmXV`、分离托管 `/var/lib/teacher-workbench-pilot-scheduled/escrow/escrow-2kgUgmXV`；随后 `systemctl enable --now teacher-workbench-pilot-backup.timer`，健康脚本返回 `PILOT_SCHEDULED_BACKUP_FRESH_PAIRED_AND_TIMER_ACTIVE`，再次启动服务安全跳过。日程按服务器 Asia/Shanghai 03:30，随机延迟至多 10 分钟；使用 `sudo systemctl status teacher-workbench-pilot-backup.timer` 看下次时间，`sudo journalctl -u teacher-workbench-pilot-backup.service -n 50 --no-pager` 看结果，`sudo /usr/local/libexec/teacher-workbench-pilot-backup-health` 检查最新副本（不输出密钥）。不要手动删除 root 私有备份或托管；没有自动保留清理。若服务失败，先检查日志、试点 HTTPS、磁盘可用量和未完成目录，修复后再重新启动；**当前没有配置外部失败通知，也没有自动 NAS 复制。**

**2026-10-27 首个定时快照独立恢复已执行，不要重跑一次性脚本：**`restore_ubuntu_pilot_scheduled_first.sh` 远端 SHA-256 `78829355926c40fe154c4c7d2d17dfc906c8a01b093a042b32a14e115ba38bd2`、Bash 语法通过，root 在 `10.251.33.0/28` 新内部网络和新卷读取 `backup-pilot-2kgUgmXV` 与配对 `escrow-2kgUgmXV`。数据库、Redis、私有资料和 CA 恢复，虚构两账号、Word 内容/下载哈希及跨账号拒绝核验成功；最终 `PILOT_SCHEDULED_FIRST_INDEPENDENT_RESTORE_VERIFIED`、退出码 0，恢复目录 `/var/lib/teacher-workbench-pilot-scheduled/restore-2kgUgmXV`。恢复 DB/Redis 已停、卷保留，在线试点和原预发布登录页均 200。后续每日新快照不能直接用这个固定脚本复跑，应另选新隔离资源与固定源校验。

**2026-10-27 本机健康检测已安装并运行：**`teacher-workbench-pilot-backup-health.service` 和 `.timer` 远端摘要分别为 `fab44259cfd6371a1ccb07c77a196ffdc54bf8014e894ebff17ea30f6da36c1b`、`da779747dd75a94c4c6fb6a4e897f4b625aca58c7d82011f0801b4ec3e79ef1f`；安装到 `/etc/systemd/system/`，unit 校验、手动 `systemctl start teacher-workbench-pilot-backup-health.service` 与 `systemctl enable --now teacher-workbench-pilot-backup-health.timer` 成功。每日服务器当地 08:00（最多随机延迟 10 分钟）检查，服务失败时以 `sudo systemctl status teacher-workbench-pilot-backup-health.service` 和 `sudo journalctl -u teacher-workbench-pilot-backup-health.service -n 50 --no-pager` 定位。它只留下本机失败状态和日志，**不会主动通知外部用户。**

**2026-10-27 固定双账号快照 NAS 转存、只读导回和新卷恢复已执行，不要重跑一次性脚本：**用户明确授权 `backup-pilot-YvI69NlE` 的十个数据文件写入 `10.0.30.6:/teacher-workbench-backup` 新目录（不含分离的密钥/CA），并允许只读导回和使用既有 U 盘返回托管恢复。`transfer_pilot_two_users_nas.py` 远端 SHA-256 `30e659983b89431dce834a21a5ed6d2c6db6fc9985a38b3d54caf1ef5e59eaf3`、Python 语法通过；写入 `pilot-two-users-data-YvI69NlE-a9f7376e478c` 时十文件逐项哈希通过，写挂载清理。随后只读导回十二文件到 `/home/huahua/teacher-workbench-nas-import-pilot-two-users-data-YvI69NlE-a9f7376e478c` 并清理读挂载。`restore_ubuntu_pilot_two_users_nas.sh` 远端 SHA-256 `2b43e9d1034e07fab51f2e6f213dd97daf47bf6eaae980a86d83a7850f302da4`、Bash 语法通过；用 U 盘返回托管 `/home/huahua/teacher-workbench-pilot-offline-escrow-restore-b2f424c27b5a` 在 `10.251.32.0/28` 新内部网络和卷恢复，内容及跨账号拒绝通过，最终 `PILOT_TWO_USER_NAS_USB_INDEPENDENT_RESTORE_VERIFIED`、退出码 0。恢复 DB/Redis 停止、卷保留，目录 `/home/huahua/teacher-workbench-pilot-two-users-nas-restore-a9f7376e478c`，在线双站登录页 200。周期备份/失败告警与空白主机重建尚未验证。

**2026-10-27 在线跨账号检查后本机快照及恢复已执行，不要重跑一次性脚本：**助手只读确认在线资料 ID=1、所有者 ID=1、账号数=2，用户普通成员会话看到资料列表不含管理账号 Word、原下载链接显示普通 404。固定 `backup_ubuntu_pilot.sh` 远端摘要 `788b9209ef807f8e0fde371d3fd96f5863af68d688a3e50a0ae0606978a1d951` 与 Bash 语法通过；短暂停止试点 Web/网关后生成 `backup-pilot-YvI69NlE` 和同机分离的 `escrow-YvI69NlE`，四服务恢复、配对文件校验通过。新 `restore_ubuntu_pilot_two_users.sh` 远端 SHA-256 `2b14b640781ac1f0d5a6325e4ed909d20f1ac1851495b2d05186aa31c3764dde`、Bash 语法通过，在 `10.251.31.0/28` 新内部网络和卷独立恢复，核对双账号/资料/权限与下载哈希，最终 `PILOT_TWO_USER_INDEPENDENT_RESTORE_VERIFIED`、退出码 0。恢复测试容器已停、卷保留，目录 `/home/huahua/teacher-workbench-pilot-two-users-restore-YvI69NlE`，在线两站登录页 200。固定范围 NAS 步骤已随后获授权并执行，结果见上方最新记录。

**2026-10-27 恢复副本权限核验已执行，不要重跑一次性脚本：**`verify_ubuntu_pilot_material_nas_access.sh` 仅针对 `teacher-workbench-pilot-material-nas-restore-08582087b8f1` 的已停止 DB/Redis、固定网络和只读资料卷。助手上传后核对远端 SHA-256 `32395d76ade58a86fcfc25bc8cef8647b05a1a1bad2fe9557fbfccb7766cbfd8` 与 Bash 语法；启动隔离容器后用事务性临时账号验证资料列表不可见、直接下载 404、成员页 403，回滚后账号和资料数量未变。退出码 0，`PILOT_MATERIAL_RECOVERED_ACCESS_VERIFIED`；恢复容器已再次停止，在线试点与预发布登录页仍 200。该项只证明恢复副本程序化权限，不等于在线双账号浏览器验收。

**状态：本机开发命令已验证；Ubuntu 257 的隔离预发布与独立 HTTPS 技术试点已启动并分别核验；正式环境未部署。** 2026-10-27 当前 Windows 用户根 CA 信任、试点 HTTPS 虚构管理账号浏览器登录/退出、新配对备份及 NAS 数据往返均通过；固定密钥/CA 托管加密包已完成 U 盘拔插返回、解密和配对 NAS 数据的同机新卷恢复。空白主机灾备和周期备份/告警未验收。本地开发命令适用于项目目录 `D:\Projects\teacher-workbench` 的 Windows PowerShell；Ubuntu 的实际操作在下文单独列明。

**2026-10-27 虚构资料上传后的备份与恢复已执行，不要重跑一次性脚本：**用户在 EasyTier HTTPS 试点浏览器确认虚构 Word 上传、刷新列表、下载打开三项正常。助手执行既有 `/home/huahua/backup_ubuntu_pilot.sh`（远端脚本摘要 `788b9209ef807f8e0fde371d3fd96f5863af68d688a3e50a0ae0606978a1d951`），在试点短暂停写后创建数据快照 `/home/huahua/teacher-workbench-pilot-backups/backup-pilot-6A76GMeO` 与分离托管 `/home/huahua/teacher-workbench-pilot-key-escrow/escrow-6A76GMeO`，恢复服务并核验登录页。新脚本 `restore_ubuntu_pilot_material.sh`（SHA-256 `1e6fb8c73857d456b7e5609634e4c929648346a038ff7e29791a6fb48e8641df`）在独立 `10.251.29.0/28` 网络及新卷恢复资料和下载响应，均与本机虚构样例哈希一致；测试 DB/Redis 停止、卷保留。用户随后单独授权这份固定新数据包的 NAS 转存与只读导回。`transfer_pilot_material_nas.py`（SHA-256 `e01adf4f94a4f471843aea85fdd1aa2af43ac280ae4406b53ecc992ab5d2400a`）只转存十个固定数据文件到 `10.0.30.6:/teacher-workbench-backup/pilot-material-data-6A76GMeO-08582087b8f1`；写挂载已卸载。只读导回到 `/home/huahua/teacher-workbench-nas-import-pilot-material-data-6A76GMeO-08582087b8f1`，12 文件通过双清单验证，读挂载已卸载。`restore_ubuntu_pilot_material_nas.sh`（SHA-256 `ae373916cd76b11272487a5f2b944568aa7c10543ed408f258b835a4b430757d`）将该数据与既有 U 盘返回托管 `teacher-workbench-pilot-offline-escrow-restore-b2f424c27b5a` 配对，在独立 `10.251.30.0/28` 网络、新卷恢复资料及下载响应，最终 `PILOT_MATERIAL_NAS_USB_INDEPENDENT_RESTORE_VERIFIED`、退出码 0。测试 DB/Redis 停止、卷保留，目录 `/home/huahua/teacher-workbench-pilot-material-nas-restore-08582087b8f1`；在线试点和预发布登录页 200。此演练仍在原 Ubuntu，尚无周期备份、告警或空白主机重建。

**2026-10-27 客户端现场更正：**用户说明当前设备已通过 EasyTier 打开试点 HTTPS 地址，且已成功登录、退出。将这台设备的 EasyTier 路径与登录流程记为用户验收通过，不再重复要求检查；其他客户端和物理家外位置未由本轮确认。其后虚构 Word 的上传、刷新和下载已由用户实际验收；真实资料仍不进入技术试点。

## 试点离线托管（固定虚构账号快照已完成）

**2026-10-27 已执行，不要重跑这些一次性命令：**用户在本人终端输入离线口令，从 U 盘返回密文恢复托管，得到 `/home/huahua/teacher-workbench-pilot-offline-escrow-restore-b2f424c27b5a` 和 `PILOT_ESCROW_FROM_RETURNED_PACKAGE_VERIFIED`。助手随后经 SSH 在 Ubuntu 257 核对 `restore_ubuntu_pilot_manager_nas_from_usb.sh` 的 SHA-256 为 `1b44290224ad28e780c6a56b670e6514357f01af75425d094c40f2eebae21076`、Bash 语法通过，再执行一次 `bash restore_ubuntu_pilot_manager_nas_from_usb.sh b2f424c27b5a`。该脚本只读取固定 NAS 导回数据与这份返回托管，在新网络、新卷恢复；账号/迁移/权限、CA、AI 关闭和登录页检查通过，原试点 HTTPS 与预发布 HTTP 登录页均为 200，恢复用 DB/Redis 已停止、卷保留。退出码 0，最终 `PILOT_MANAGER_USB_ESCROW_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-pilot-manager-usb-restore-b2f424c27b5a`。本次不涉及空白主机重建，也没有启用周期备份或付费 AI。

以下为已完成操作的时间顺序记录，包含当时的待办描述；不应按这些一次性步骤重新执行。固定 NAS 数据源是已只读导回的 `pilot-manager-data-Lx7aqLEz-9037d08db8d9`；原分离托管源是 Ubuntu 上的 `escrow-Lx7aqLEz`。托管加密包后来经 USB 离机并返回，成功恢复到上文所列新目录。**离机加密包已验证，同机新卷恢复已通过；异机恢复未验证。**

原执行顺序为：用户在可见 Ubuntu 终端导出加密包；Windows 复制到系统识别的 USB 并核对摘要；安全拔插后从 USB 返回 Ubuntu；用户在终端用修订版恢复脚本输入离线口令；最后配对 NAS 数据新卷恢复。上述顺序已经完成。口令、明文托管及 Caddy CA 私钥未写入聊天、NAS 或 Git；演练仍在原 Ubuntu 上，不能冒充空白主机重建。

首次真实导出输入被 `PASSPHRASE_TOO_SHORT` 拒绝。助手只读核对加密包文件数为 0，在线 HTTPS 登录页仍正常。重试使用原命令，须在输入时确保新口令**至少 20 个字符**，两次输入完全相同；终端不显示输入。示例格式只说明长度：由多段互不相关的词组成，中间可用空格或符号；不要使用文档中的示例字符串作为实际口令。失败时保留空临时目录，不覆盖。

第二次用户终端报告 `PASSPHRASES_DO_NOT_MATCH`；代码在写加密包前停止，仍可用相同命令重新尝试。输入不回显，注意两次的大小写、输入法状态、空格与标点完全一致。不要将口令贴进命令行或聊天。

第三次用户可见终端成功创建固定加密包 `package-KqF0If9u/teacher-workbench-pilot-escrow-Lx7aqLEz.json`，助手只读复核权限 600 与 SHA-256 `ed664283c6b78a2f953524c2ddf88ab9ad983e783289abbc493cbb764242c93a`。加密包仍只在 Ubuntu；USB 盘符待用户确认，未运行复制脚本，后续不得把导出成功误记为离机保存或恢复成功。

Windows 随后识别唯一可移动 `E:`。两份 USB PowerShell 脚本已修成 UTF-8 BOM，Windows PowerShell 5 解析通过。`copy_pilot_escrow_to_usb.ps1` 将仅含密文的 8144 字节包复制到新目录 `E:\teacher-workbench-pilot-escrow-Lx7aqLEz-KqF0If9u\`，本地 SHA-256 核对通过。用户需安全弹出、拔出并重新插入 U 盘，才继续只读复核和导回；未发生明文或解锁口令传输。

用户已重新插入 U 盘，助手再次只读核对 USB 文件 SHA-256 一致，并通过 `return_pilot_escrow_from_usb.ps1` 将**密文**复制回 Ubuntu 新目录 `teacher-workbench-pilot-offline-escrow-return-bb7686675118`，远端复核通过。为避免输错口令后固定空目录阻碍重试，解密脚本改为每次尝试创建新的随机 12 位后缀目录；修订版单独上传为 `/home/huahua/restore_ubuntu_pilot_offline_escrow_v2.sh`，SHA-256 `f96993df9c55c8ae7b4d35218ee2ff00061baccaf7092d28ad0d3e8eb325c765`，远端 Bash 语法通过，旧版保留。用户随后在可见终端解密成功，助手用该新目录完成上文记录的 NAS 数据配对恢复。

## 2026-10-27 试点首次虚构账号（已执行，不要重跑）

助手已将 `create_ubuntu_pilot_manager.sh` 与 `prepare_ubuntu_pilot_manager.py` 上传到 Ubuntu 257 的 `/home/huahua/`；远端 SHA-256、Bash/Python 语法与试点环境字段检查通过。用户已运行下面的一次性命令并在自己的终端设置 `pilot_manager_20261026` 密码；账号为非 staff、非 superuser，仅有成员管理权限。最终 `PILOT_FICTIONAL_MANAGER_READY` 和包装器标记通过，用户浏览器确认登录、成员账号页和退出正常。**下面命令仅保留作历史记录，不要重跑。**

此命令在用户 Windows PowerShell 运行过：包装器先核对本机与服务器上两份脚本的固定 SHA-256，再检查 HTTPS 试点和原预发布登录页、创建账号。账号密码未写入项目或聊天。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_pilot_manager.ps1"
```

用户已在同一台受信任 Windows 浏览器打开 `https://10.0.30.5:18443/login/`，用虚构账号登录、查看成员账号页并退出，报告正常。账号创建后，初始空库备份与 NAS 副本已过时，不能用其恢复新账号。

助手随后运行既有 `backup_ubuntu_pilot.sh`，应用停写后在 `/home/huahua/teacher-workbench-pilot-backups/backup-pilot-Lx7aqLEz` 生成新数据包，在 `/home/huahua/teacher-workbench-pilot-key-escrow/escrow-Lx7aqLEz` 单独保管配置、主密钥和 Caddy CA；校验并恢复原站。上传并运行 `restore_ubuntu_pilot_manager.sh`，在新内部 `10.251.26.0/28` 网络和独立卷恢复 PostgreSQL、Redis、私有文件及 CA；核对仅有虚构管理账号、非 staff 权限、迁移、空业务内容及登录页，测试 DB/Redis 停止且卷保留，恢复目录 `/home/huahua/teacher-workbench-pilot-manager-restore-Lx7aqLEz`。新快照尚未转存 NAS。

用户随后明确授权固定新快照的数据包转存、只读导回和新卷恢复。助手将 `transfer_pilot_manager_nas.py` 与 `restore_ubuntu_pilot_manager_nas.sh` 上传 Ubuntu，远端 SHA-256 和语法通过；源只接受 `backup-pilot-Lx7aqLEz` 的固定清单 SHA-256 `d49273d525f149b62cc1bd0eacf2832b398770e299e659320ec4d9819170e604`，NAS 目的地固定为 `10.0.30.6:/teacher-workbench-backup` 下新目录。仅 10 个白名单数据文件写入 `pilot-manager-data-Lx7aqLEz-9037d08db8d9`；独立主密钥与 CA escrow 未写入 NAS。以只读挂载导回 12 文件至 `/home/huahua/teacher-workbench-nas-import-pilot-manager-data-Lx7aqLEz-9037d08db8d9`，两次 NFS 挂载均清理。导回数据配对 Ubuntu 本机 escrow 在独立 `10.251.27.0/28` 网络与新卷恢复；账号、权限、迁移、CA、登录页通过，测试容器停止、卷保留，目录 `/home/huahua/teacher-workbench-pilot-manager-nas-restore-9037d08db8d9`。这证明当前 Ubuntu 同机 NAS 来源恢复，**不证明 escrow 可在新主机取得**。

## 本机开发环境（2026-10-15 已验证）

- Python 虚拟环境：项目内 `.venv`，不进入 Git。依赖版本见 `requirements.txt`。本机命令行没有 `python` 或 `docker`，创建虚拟环境时使用了 Codex 工作区自带 Python；现可直接用 `.\.venv\Scripts\python.exe`。
- 在 **Windows PowerShell** 进入 `D:\Projects\teacher-workbench` 后执行 `$env:DJANGO_DEBUG='1'`，作用是启用仅供本机测试的 Django 配置。此设置只对当前 PowerShell 窗口有效。
- `& .\.venv\Scripts\python.exe manage.py migrate --noinput`：建立/更新本机测试数据库；已执行成功。数据库在被 Git 忽略的 `data/dev.sqlite3`。
- `& .\.venv\Scripts\python.exe manage.py test workbench`：运行不含真实教学资料的自动测试；2026-10-15 初次执行 21 项通过，2026-10-18 运行 53 项，50 项通过、3 项 PostgreSQL 专用测试按本机条件跳过。运行前仅在本机当前 PowerShell 窗口设置 `DJANGO_DEBUG=1`。
- `& .\.venv\Scripts\python.exe manage.py check`：检查 Django 配置；已执行，未发现问题。
- `& .\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000 --noreload`：只在本机启动开发服务器；已执行。浏览器打开 `http://127.0.0.1:8000/login/`，预期看到“登录工作台”。2026-10-15 已创建仅供本机页面检查的 `preview_teacher_20261015` 账号，口令只在当前对话提供，不写入项目文档。登录页及 CSS、JS 请求均得到 HTTP 200。测试结束按 `Ctrl+C` 停止。
- 2026-10-15 再次启动当前代码的本机服务，仅监听 `127.0.0.1:8000` 且 `AI_ENABLED=0`；登录页、CSS HTTP 200。此为开发服务，终端会话结束后可能停止，不作为正式可用性保证。
- 2026-10-16 发现旧开发服务和新排队模式服务曾同时监听 `127.0.0.1:8000`，浏览器进入旧服务，导致已上传资料的“生成作业”按钮仍禁用。助手仅停止旧服务 PID 8380，保留新服务 PID 12452；随后登录页 HTTP 200，当前模式的首页渲染含可用生成表单。该进程号只用于本次排查，不是以后固定的停止命令；启动新服务前应先检查 8000 端口是否已有旧服务，避免并存。用户需在浏览器按 `Ctrl+F5` 刷新并检查页面“模型状态”是否显示“本机测试排队模式已启用”。
- 本机开发服务器不是正式部署方式；不能通过内网穿透直接公开。
- `& .\.venv\Scripts\python.exe manage.py seed_preview_worksheet preview_teacher_20261015`：在当前本机预览账号下创建一份**虚构离线排版样例**，用于检查预览和两份 Word；已执行成功，重复执行不再创建第二份。此命令仅允许 DEBUG + SQLite 测试环境，既不调用 AI，也不使用教学原始资料。样例位于本机私有数据目录，不进入 Git。
- 2026-10-15 已从虚构样例生成 `data/preview-exports/离线排版样例-学生卷.docx` 和 `data/preview-exports/离线排版样例-教师答案版.docx`，供用户在 WPS 直接检查。该目录被 `.gitignore` 排除；文件是一次性本地测试产物，后续代码调整不会自动更新已有文件。
- 2026-10-15 另建本机隔离检查账号 `preview_other_20261015`，口令仅在当前对话提供。助手以该账号核查：主页没有第一账号的离线样例，直接访问其预览和导出地址均得到 404。此检查仅针对本机测试数据。

## 环境与权限

- 本机开发测试环境：`D:\Projects\teacher-workbench`，SQLite 测试数据在 `data/`，私有文件在 `data/private/`，均不进入 Git。
- Docker 测试环境：`compose.yaml` 固定项目名 `teacher-workbench-test`，Web 仅绑定 Ubuntu 的 `127.0.0.1:18000`，含 Web、worker、PostgreSQL、Redis；2026-10-16 用户现场确认四服务启动与登录页 HTTP 200。服务器 `.env` 使用随机测试密钥，`scripts/check_test_env.py` 离线检查通过；Compose 测试栈强制关闭 AI。虚构业务流程、配对备份、NAS 转存及 NAS 来源独立卷恢复已得到用户现场成功标记；正式环境未部署。详细闸门见 [Docker 隔离测试与回退准备](docker-test-plan.md)。
- 独立正式配置草案：`compose.production.yaml`、`config/nginx-production.conf` 与 `scripts/check_production_env.py` 已在本地编写；仅作为[发布前准备](production-readiness.md)，**没有创建 `.env.production`，也没有在 Ubuntu 解析、启动或迁移**。现有测试栈不受影响。用户不需在此阶段运行草案。
- 登录防护：`workbench/auth_views.py` 与自定义 Django AdminSite 已在本机实现普通/管理员登录共用的 8 次错误、15 分钟窗口限制；本机 43 项测试通过 40、跳过 3。正式配置用 Redis 缓存计数。Ubuntu 一次性 PostgreSQL 回归与两个进程共享虚构 Redis 键已由用户现场验证；**新代码尚未部署到运行中的 Web/worker，真实 HTTP 登录和浏览器行为未验证**；目前不要把测试栈或正式草案接入内网穿透。
- 正式环境：待确定路径、域名/穿透/HTTPS 入口、配置文件、数据目录和负责人。
- 目标 Ubuntu：用户提供的 VM 257，主机名 `teacher-workbench`，SSH 用户 `huahua`。2026-10-16 已把 SSH 握手指纹同用户在 VM 控制台读取的指纹核对一致；用户随后在自己的终端登录并提供只读资源结果，助手没有可复用登录会话。
- SSH 连接如需配置，先向用户说明将连接的主机、使用位置、只读检查或写入范围及成功标准；不扩展到 PVE 宿主机或其他虚拟机。

## Ubuntu 257 只读核查（资源与 sudo Docker 均已反馈）

- **执行位置：**用户电脑的 Windows PowerShell，任意目录均可。用户尝试运行 `scripts/check_ubuntu_readonly.ps1` 时，Windows 执行策略阻止启动，未连接服务器；无需修改执行策略。改为直接粘贴以下一整行命令。它使用本项目已核对指纹的本地公钥文件，仅连接 `huahua@10.0.30.5`；出现密码提示时只在终端输入 Ubuntu 登录密码（输入不显示），不要发到聊天。

```powershell
ssh -T -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=8 huahua@10.0.30.5 "hostname; id -un; free -h; df -h /; df -i /; docker --version; docker compose version; docker info >/dev/null 2>&1 && echo DOCKER_ACCESS=yes || echo DOCKER_ACCESS=no; ss -H -ltn | grep -q :18000 && echo PORT_18000=busy || echo PORT_18000=free"
```

- **预期可见：**`teacher-workbench`、`huahua`、内存与系统盘空间和 inode、Docker/Compose 版本、`DOCKER_ACCESS`、`PORT_18000`。这是只读检查，不上传文件、不创建目录、不启动容器、不运行 `sudo`。若显示主机密钥错误、登录被拒绝或命令缺失，应原样反馈错误，不继续部署。
- **用户现场结果（2026-10-16）：**用户在自己的 PowerShell 输入密码后运行该直接命令，输出 `teacher-workbench`、`huahua`；根分区可用 53G，内存可用 2.8Gi，Docker 29.9.0、Compose v5.6.0，`DOCKER_ACCESS=no`，`PORT_18000=free`。见 [服务器环境](environment.md)。这是一次只读用户反馈；助手没有可复用登录会话，尚未运行 Compose 或容器。
- **组与 socket 检查：用户已执行。**`huahua` 属于 `sudo` 组，不属于 `docker` 组；Docker socket 为 `root:docker`、`srw-rw----`。普通用户无该 socket 权限。先前命令中的 `head -n 12` 只显示 Docker 客户端信息，未包含最终错误。不要为本次测试改用户组或 socket 权限。

```powershell
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "sudo docker info --format '{{.ServerVersion}}'"
```

- **用户现场结果（2026-10-16）：**上条命令输出 Docker 服务端版本 `29.9.0`，`Connection to 10.0.30.5 closed.` 表示 SSH 会话结束。只读检查通过；尚未运行 Compose 或容器。命令没有修改用户组、Docker 配置或容器。
- Windows 已制作本地测试包 `data/deploy/teacher-workbench-test.tar.gz`，50 个白名单源文件，SHA-256 为 `9e29fddfbf6bd33674406aa0e77155574d69cd09557edc0998ce95ea1104bb4c`。包内含 `.dockerignore`，其规则排除后续生成的 `.env` 和 `data/`，避免进入 Docker 构建上下文；包内不含本机教学资料、数据库、密钥或 `.env`。文件清单已核对；尚未上传。以后代码若修改，需重新制作并记录新哈希。

## 隔离测试包传输（用户已完成；仅写 Ubuntu 用户目录）

- **执行位置：**用户电脑的 Windows PowerShell，任意目录。以下一整行先用 SCP 把上述代码包写入 Ubuntu `huahua` 家目录的 `teacher-workbench-test-9e29fddf.tar.gz`，仅在 SCP 成功后再用 SSH 读取其 SHA-256。会出现两次 SSH 密码提示；密码只在终端输入，不发到聊天。不解压、不生成 `.env`、不启动容器，也不写 PVE 或正式环境。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=8 "D:\Projects\teacher-workbench\data\deploy\teacher-workbench-test.tar.gz" "huahua@10.0.30.5:teacher-workbench-test-9e29fddf.tar.gz"; if ($LASTEXITCODE -eq 0) { ssh -T -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "sha256sum teacher-workbench-test-9e29fddf.tar.gz" }
```

- **用户现场结果（2026-10-16）：**服务器端输出的 SHA-256 为 `9e29fddfbf6bd33674406aa0e77155574d69cd09557edc0998ce95ea1104bb4c`，与本地一致。记录为包传输和完整性通过；尚未解压、配置或运行。

## 隔离测试目录解压（用户已完成；未启动容器）

- **执行位置：**用户电脑的 Windows PowerShell。以下 SSH 命令只在 Ubuntu `huahua` 家目录创建一个新的 `teacher-workbench-test-9e29fddf` 目录，并从已核对哈希的包中解压源文件；若该目录已经存在，命令会停止，避免覆盖已有成果。命令不使用 `sudo`，不创建 `.env`，不碰正式环境或 PVE。

```powershell
ssh -T -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "test -f teacher-workbench-test-9e29fddf.tar.gz && test ! -e teacher-workbench-test-9e29fddf && mkdir -m 700 teacher-workbench-test-9e29fddf && tar -xzf teacher-workbench-test-9e29fddf.tar.gz -C teacher-workbench-test-9e29fddf && test -f teacher-workbench-test-9e29fddf/compose.yaml && test -f teacher-workbench-test-9e29fddf/.dockerignore && echo TEST_SOURCE_READY && python3 --version"
```

- **用户现场结果（2026-10-16）：**输出 `TEST_SOURCE_READY` 和 `Python 3.14.4`；记录为独立测试目录及必需文件存在。没有删除或覆盖原目录，尚未生成 `.env`、解析 Compose 或启动容器。

## 生成隔离测试配置并仅解析 Compose（用户已完成）

- **执行位置：**用户电脑的 Windows PowerShell，项目目录 `D:\Projects\teacher-workbench`。以下一整行先上传不含密钥的准备程序到 Ubuntu `huahua` 家目录，然后执行它。程序仅允许在 `teacher-workbench` 主机由 `huahua` 运行，重新核对原包哈希和 50 个已解压文件，拒绝覆盖已有 `.env`，在权限 700 的独立测试目录内生成权限 600 的随机测试密钥与数据库密码。配置强制 `AI_ENABLED=0`、`AI_API_KEY=`；不会回显密钥、调用模型或启动容器。随后运行安全检查器与 `docker compose config --quiet`，不会打印完整 Compose 配置。SSH 可能提示两次密码，均只在终端输入。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\prepare_ubuntu_test_env.py" "huahua@10.0.30.5:prepare_ubuntu_test_env_9e29fddf.py"; if ($LASTEXITCODE -eq 0) { ssh -T -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "python3 prepare_ubuntu_test_env_9e29fddf.py && cd teacher-workbench-test-9e29fddf && python3 scripts/check_test_env.py --env-file .env && docker compose config --quiet && echo TEST_CONFIG_READY" }
```

- **用户现场结果（2026-10-16）：**反馈 `TEST_ENV_CREATED`、安全检查器通过和 `TEST_CONFIG_READY`。只记录测试配置与 Compose 解析成功；未查看或保存 `.env` 内容，尚未启动容器。

## 隔离测试栈首次启动（2026-10-16 已尝试；构建失败）

- **范围：**仅 Ubuntu 257 的 `~/teacher-workbench-test-9e29fddf`；Compose 项目固定 `teacher-workbench-test`，Web 仅绑定服务器 `127.0.0.1:18000`，AI 强制关闭。首次启动会拉取/构建镜像、创建 PostgreSQL/Redis/私有文件三个**新**命名卷并执行数据库迁移。这是测试环境写操作，不连接内网穿透、不开放公网、不触碰 PVE、NAS 或正式环境。脚本先核对 `.env` 权限和安全配置，若 18000 端口、同名容器或三个同名卷已存在则停止，避免覆盖旧数据；失败后**不自动删除卷**。
- **执行位置：**用户电脑的 Windows PowerShell。以下一整行先上传不含密钥的启动脚本到 Ubuntu `huahua` 家目录，再做 `bash -n` 语法检查并运行。SCP、SSH 和首次 `sudo` 可能分别要求密码，只在终端输入，不发到聊天。下载和构建可能持续数分钟，期间不要关闭 PowerShell。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\start_ubuntu_test_stack.sh" "huahua@10.0.30.5:start_ubuntu_test_stack_9e29fddf.sh"; if ($LASTEXITCODE -eq 0) { ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "bash -n start_ubuntu_test_stack_9e29fddf.sh && bash start_ubuntu_test_stack_9e29fddf.sh" }
```

- **成功标准：**先出现 `TEST_FIRST_START_PREFLIGHT_OK`，随后 `sudo docker compose ps` 列出服务，最终出现 `TEST_LOGIN_HTTP_200`。这仅说明本机回环登录页可响应；账号、上传、Word、隔离和备份恢复仍须另行验收。若中途报错，保留现有测试卷和输出，不执行 `docker compose down -v`；反馈最后的错误与服务状态，排查后再决定处理方式。
- **用户现场结果（2026-10-16）：**前置检查输出 `TEST_FIRST_START_PREFLIGHT_OK`，Redis 镜像拉取成功；Docker 构建 Python 镜像时，`pip` 从 `files.pythonhosted.org` 下载 Django wheel 出现 `ReadTimeoutError`，构建退出码 2。没有输出 `TEST_LOGIN_HTTP_200`，也没有 `docker compose ps` 结果。是否已留下同名容器或命名卷尚未知；不要直接重跑本节命令或删除卷。按下一节的离线重试步骤处理。

## 构建超时后的离线重试（2026-10-16 用户现场通过）

- **原因与范围：**本轮只针对 Python 依赖下载超时。离线重试包存于被 Git 忽略的 `data/deploy/teacher-workbench-test-offline-retry.tar.gz`，20 个文件，SHA-256 为 `f0b5572a2ae64b1dd94e20995e8bb169e939df0a58fb3b1199a1524a3726c880`。其中 18 个是适用于 Python 3.12/Linux x86_64 的 wheel，另含测试专用 Dockerfile 和重试脚本。包不含 `.env`、Key、教学资料、数据库或用户聊天。离线依赖在 Windows 用目标平台和 `--no-index` 完成解析；Ubuntu 构建尚待验证。
- **操作位置：**用户电脑的 Windows PowerShell，任意目录。以下两行依次执行；第一行仅将包复制到已核对 SSH 指纹的 Ubuntu 257 用户家目录。第二行先校验 SHA-256，再创建新的私有解包目录、解包并执行 `bash -n`；脚本在改动测试 Dockerfile 前会核对主机/用户、目录与 `.env` 权限、原 Dockerfile 哈希、端口、同名容器和三个命名卷。若有既存容器或卷，打印错误并停止，**不删除、不覆盖数据卷**。通过后只在 `~/teacher-workbench-test-9e29fddf` 内加入离线依赖并重试原启动脚本。SCP、SSH、`sudo` 可能要求密码；只在自己终端输入，不发到聊天。预计需要几分钟。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\data\deploy\teacher-workbench-test-offline-retry.tar.gz" "huahua@10.0.30.5:teacher-workbench-test-offline-retry.tar.gz"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "set -e; echo 'f0b5572a2ae64b1dd94e20995e8bb169e939df0a58fb3b1199a1524a3726c880  teacher-workbench-test-offline-retry.tar.gz' | sha256sum -c -; test ! -e teacher-workbench-test-offline-retry; mkdir -m 700 teacher-workbench-test-offline-retry; tar -xzf teacher-workbench-test-offline-retry.tar.gz -C teacher-workbench-test-offline-retry; bash -n teacher-workbench-test-offline-retry/retry_ubuntu_test_stack_offline.sh; bash teacher-workbench-test-offline-retry/retry_ubuntu_test_stack_offline.sh"
```

- **成功标准：**依次看到 SHA 校验 `OK`、`TEST_OFFLINE_DEPENDENCIES_READY`、`TEST_FIRST_START_PREFLIGHT_OK`、四项 Compose 服务状态以及最终 `TEST_LOGIN_HTTP_200`。若出现 `TEST_CONTAINERS_ALREADY_EXIST`、`TEST_VOLUME_ALREADY_EXISTS` 或其他错误，保留当前现场并反馈错误结尾；不要执行清理命令。登录页成功后，还要另行验收测试账号、上传、下载、Word 和跨账号隔离。此步骤不会触发付费 AI，也不对外开放端口。
- **用户现场结果（2026-10-16）：**四服务均显示 Up，db/redis healthy，Web 仅 `127.0.0.1:18000->8000/tcp`，最终输出 `TEST_LOGIN_HTTP_200`。表示该次测试栈启动成功；这是刚启动时的状态，不能据此宣称长期稳定或完成业务验收。

## 隔离测试栈持续状态与原自动测试（2026-10-16 已执行，测试未通过）

- **范围：**仅检查 Ubuntu 257 上既有的 `~/teacher-workbench-test-9e29fddf` Compose 项目。先核对四项服务仍运行、Web 只绑定 `127.0.0.1:18000`；再在 Web 容器中运行 Django 配置及迁移检查、35 项自动测试；最后从 Ubuntu 主机访问登录页及 CSS/JS。自动测试会在 PostgreSQL 中创建并自动删除**单独的虚构测试数据库**，不把真实资料或 Key 送入模型，不改正式环境，不清理主业务卷。失败即停止并保留现场。此脚本尚未在 Ubuntu 执行。
- **操作位置：**用户电脑 Windows PowerShell，依次执行下面两行。第一行只上传脚本到 Ubuntu 用户家目录；第二行先检查 Bash 语法，再执行。出现 SSH 或 `sudo` 密码提示时，仅在终端输入，勿发送给助手。整个测试约需一分钟。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\verify_ubuntu_test_stack.sh" "huahua@10.0.30.5:verify_ubuntu_test_stack_9e29fddf.sh"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "bash -n verify_ubuntu_test_stack_9e29fddf.sh && bash verify_ubuntu_test_stack_9e29fddf.sh"
```

- **成功标准：**末尾依次看到 `TEST_FOUR_SERVICES_RUNNING_LOOPBACK_ONLY`、`TEST_DJANGO_CHECK_AND_MIGRATIONS_OK`、Django `Ran 35 tests ... OK`、`TEST_POSTGRES_SUITE_OK`、`TEST_LOGIN_AND_STATIC_HTTP_200`、`TEST_STACK_SMOKE_OK`。如出现错误，反馈末尾输出；不要清空卷或重复创建测试栈。通过后仍须用虚构资料检查实际登录、上传、下载、双 Word 及两个账号的隔离。
- **用户现场结果（2026-10-16）：**前两项通过；原 35 项测试在 PostgreSQL 得到 `FAILED (failures=5, errors=16)`，测试数据库输出已删除。脚本在此停止，所以没有静态资源检查或 `TEST_STACK_SMOKE_OK`。原因至少包含本机 DEBUG+SQLite 专用命令的安全闸门与 Ubuntu PostgreSQL 环境冲突、测试中期连接关闭；不能据此宣称业务功能失败或通过。**不要重跑这一整套 SQLite 专用测试。**下一节改用独立的虚构 PostgreSQL 流程检查，不改业务代码或数据卷。

## PostgreSQL 虚构业务流程与静态资源复核（2026-10-16 用户现场通过）

- **范围：**仅针对既有 Ubuntu 257 测试栈。两个新脚本不进入容器镜像；Shell 脚本核对四服务仍运行、Web 仅绑定回环，然后把 Python 检查通过标准输入交给 Web 容器。它用 Django **单独创建并删除的测试数据库**和虚构 Word 内容检查上传、本人下载、预览、学生/教师双 Word、跨账号拒绝及 AI 关闭；`TransactionTestCase` 允许文件响应结束后数据库连接重新打开。上传文件放在临时目录，不会加入持久私有资料卷。最后检查 Ubuntu 回环登录页与 CSS/JS。无需 API Key，也不会调用模型或改动正式环境。原运行中的四服务和三个持久卷保持不变。
- **本机验证：**`scripts/postgres_smoke.py` 语法通过；在本机 SQLite 上以专用测试开关执行这一项虚构流程通过，默认运行会拒绝 SQLite。**PostgreSQL 上尚未执行**，不宣称通过。
- **操作位置：**用户电脑 Windows PowerShell，依次执行两行。第一行只把两份脚本复制到已核对 SSH 指纹的 Ubuntu 257 用户家目录；第二行先做 Bash 语法检查再运行。密码仅在自己终端输入，不发到聊天。若第一行上传失败，不执行第二行。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\postgres_smoke.py" "D:\Projects\teacher-workbench\scripts\verify_ubuntu_postgres_smoke.sh" "huahua@10.0.30.5:"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "bash -n verify_ubuntu_postgres_smoke.sh && bash verify_ubuntu_postgres_smoke.sh"
```

- **成功标准：**看到 `TEST_STACK_STILL_RUNNING`、Django `Ran 1 test ... OK`、`POSTGRES_SMOKE_WORKFLOW_OK`、`TEST_LOGIN_AND_STATIC_HTTP_200`、`TEST_POSTGRES_SMOKE_OK`。如失败，保留状态并反馈末尾输出，不运行清理卷命令。通过仍不等于真实教学资料、WPS、费用或备份恢复已验收。
- **用户现场结果（2026-10-16）：**以上五项成功标记与单项测试 `OK` 均出现；Django 测试数据库按输出已删除。这验证 Ubuntu 测试栈内的虚构资料流程，仍未触碰持久卷备份或 NAS。

## PostgreSQL 完整回归重试（2026-10-16 用户现场技术测试通过）

旧版 35 项在 PostgreSQL 的失败日志已逐项核对。新版只修改测试适用范围和模拟环境，不改业务代码或真实命令的安全闸门；11 项本机 SQLite 专用测试在 PostgreSQL 跳过，3 项 PostgreSQL 专用测试反向确认本机命令拒绝运行。工作流测试改为逐项清理数据库，避免流式 Word 响应关闭后沿用长事务连接。详见 [阶段 1 核对](stage1-readiness.md)。本机以千问厂商环境、AI 关闭运行 38 项测试：35 项通过、3 项跳过；在模拟 PostgreSQL 设置且不连接数据库时，3 项命令防护测试通过。**Ubuntu 现场结果见本节末尾。**

**操作位置：用户电脑 Windows PowerShell。**下面只把新版测试文件与验证脚本复制到 Ubuntu `huahua` 家目录；不会修改运行中的应用文件或容器。已核对的 SSH 主机指纹文件沿用先前路径；如果出现主机指纹变化，停止。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\workbench\tests.py" "huahua@10.0.30.5:/home/huahua/teacher-workbench-postgres-tests.py"
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\verify_ubuntu_postgres_regression.sh" "huahua@10.0.30.5:/home/huahua/verify_ubuntu_postgres_regression.sh"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "sha256sum /home/huahua/teacher-workbench-postgres-tests.py /home/huahua/verify_ubuntu_postgres_regression.sh && bash -n /home/huahua/verify_ubuntu_postgres_regression.sh && bash /home/huahua/verify_ubuntu_postgres_regression.sh"
```

**核对与影响：**上传后的测试文件 SHA-256 应为 `BFB996D948CC239BD267D6308DBB52832FD9F773996C4813F200A9586D16BD66`，脚本应为 `D10E4DCB5C68DCB685C69B74D44141AD0765287EBDF5FCB0D59B7ED6CA6E6BE9`，终端会显示供事后核对；脚本在任何测试写入前自动拒绝测试文件哈希不符。脚本还核对 Ubuntu 主机/用户、四服务、回环端口、AI 禁用配置及预期的临时测试数据库不存在。随后用一次性 Web 容器只读挂载新版 `tests.py`，在临时 PostgreSQL 测试数据库运行，结束自动移除该一次性容器；既有 Web/worker 与业务卷不替换。预计输出 `Ran 38 tests`、`OK (skipped=11)`、`POSTGRES_REGRESSION_SUITE_OK`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_REGRESSION`。若报错，保留输出，不清理或重建现有卷；成功仍仅表示虚构测试回归通过，不代表正式服务或真实资料验收。

**用户现场结果（2026-10-16）：**提供输出末尾 `OK (skipped=11)`、`Destroying test database for alias 'default'...`、`POSTGRES_REGRESSION_SUITE_OK`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_REGRESSION`。按脚本顺序，整套测试成功、测试数据库已销毁，既有测试站登录页仍 HTTP 200。用户未贴出 `Ran ... tests` 行，因此具体现场测试总数仍以本机发现数为参考，不写成直接见到。助手没有 SSH 登录服务器；该技术结果不代表真实教学资料或正式发布验收。

## 登录限速的 Ubuntu 一次性回归（2026-10-16 用户现场通过）

本机新增的普通/管理员登录限速已在 SQLite 完整回归中通过；现有 Ubuntu 运行中的 Web/worker **仍是旧代码**。下面的脚本只在一次性 Web 容器内只读挂载 7 份新版代码与模板，运行临时 PostgreSQL 测试数据库；然后用两个独立一次性 Python 进程读写一个 60 秒虚构 Redis 键，验证正式配置的共享缓存。不会替换现有应用容器、修改已有资料、删除卷或调用 AI。若成功，源码包解压到 `huahua` 家目录新建的私有临时目录，供事后核对。

**操作位置：用户电脑 Windows PowerShell。**依次执行三行；SSH 和 `sudo` 密码只在本机终端输入，不发送给助手。第一、二行上传白名单代码包与脚本到 Ubuntu 257 的 `huahua` 家目录；第三行先显示哈希并检查 Bash 语法，再执行。若 SSH 主机指纹变化，立即停止。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\data\test-bundles\teacher-workbench-login-throttle-bundle.tar.gz" "huahua@10.0.30.5:/home/huahua/teacher-workbench-login-throttle-bundle.tar.gz"
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\verify_ubuntu_login_throttle.sh" "huahua@10.0.30.5:/home/huahua/verify_ubuntu_login_throttle.sh"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "sha256sum /home/huahua/teacher-workbench-login-throttle-bundle.tar.gz /home/huahua/verify_ubuntu_login_throttle.sh && bash -n /home/huahua/verify_ubuntu_login_throttle.sh && bash /home/huahua/verify_ubuntu_login_throttle.sh"
```

**本机核对：**代码包只含 `config/settings.py`、`config/urls.py`、`config/admin_app.py`、`config/admin_site.py`、`workbench/auth_views.py`、`workbench/tests.py` 和登录模板，无 `.env`、数据库、用户文件或教学样本；包哈希 `dae312864834705a2dddd6698a1b539ba893f6c820375f080173709c95161d91`，脚本哈希 `63ac66c905b771cc16aa59a9c72e20a1672f8bfdb1ceef5a5996b6fc0a69243f`。本机 Bash 语法、LF 换行、错误主机拒绝以及包内容逐文件校验通过。

**成功标准：**看到 `Ran 43 tests`、`OK (skipped=11)`、`LOGIN_THROTTLE_POSTGRES_REGRESSION_OK`、`REDIS_SHARED_COUNTER_OK` 和 `SOURCE_TEST_LOGIN_HTTP_200_AFTER_LOGIN_THROTTLE`。若失败，保留输出末尾，不清理或重建现有卷；尤其不要把测试站接入公网。成功仍只表示隔离测试技术回归通过，现有 Web/worker 仍运行旧代码，正式配置与浏览器实际登录另行验收。

**用户现场结果（2026-10-16）：**提供末尾 `OK (skipped=11)`、`Destroying test database for alias 'default'...`、`LOGIN_THROTTLE_POSTGRES_REGRESSION_OK`、`REDIS_SHARED_COUNTER_OK`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_LOGIN_THROTTLE`。`Container ... Creating/Created` 是两个一次性容器的正常创建信息。未贴 `Ran 43 tests`，具体现场总数不单独宣称。Redis 检查只验证两个进程共享虚构键；运行中的 Web/worker 没有被替换，真实 HTTP 登录限速尚未在服务器实测。助手没有 SSH 登录服务器。

## EasyTier 当前路径核对（后续 HTTPS 暂缓）

**已知信息（2026-10-17）：**用户给出 EasyTier Compose 配置，说明它运行在 PVE LXC 140，通过子网代理让已加入的外部设备访问包含 Ubuntu `10.0.30.5` 的家庭网段。配置中没有工作台 HTTPS 入口；不再要求用户寻找“内网穿透工具名称”。该配置含入网密钥，**不要再次发送原文或把它存入仓库**。项目只记录不含凭据的[网络访问计划](network-access-plan.md)，不管理 LXC 140。

**当前决定（2026-10-17）：**用户暂不使用工作台域名或 Cloudflare 代理，也未新增 `workbench` 记录；只用 EasyTier 做异地组网。本机先前对 Cloudflare NS 和候选域名的查询仅留作历史线索，当前不要求任何 DNS 操作。下一步先验证家外设备到 Ubuntu 的 EasyTier 私网路径。

**Ubuntu 监听只读核对（2026-10-17 用户现场通过）：**用户在 Windows PowerShell 执行下面一行；它在 Ubuntu 257 显示主机名和当前 TCP 监听地址/端口，不修改任何配置。现场输出为 `teacher-workbench`，测试站在 `127.0.0.1:18000`，无 80、443、18080 监听。无对应行仅表示该时刻没有 TCP 监听，不代表防火墙已放行或 EasyTier 远程可达。

```powershell
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "hostname; ss -H -ltn"
```

若以后复查时 SSH 提示主机指纹变化，立即停止；不要跳过主机密钥检查。此步骤没有访问或管理 PVE LXC 140。入口软件、防火墙以及外部 EasyTier 客户端到 Ubuntu 的连通性仍须在后续分别核对。

**家外 EasyTier 路径只读测试（2026-10-17 用户现场返回成功）：**在**不连接家庭 Wi-Fi**、已连接 EasyTier 的 Windows 电脑上打开 PowerShell，运行下面一行。可用手机热点让电脑处于家外网络；确认 EasyTier 客户端显示已连接。命令只尝试连到 Ubuntu 257 现有的 SSH 22 端口，不登录、不读文件、不修改 PVE、LXC 或 Ubuntu。

```powershell
Test-NetConnection -ComputerName 10.0.30.5 -Port 22 | Select-Object ComputerName,RemotePort,TcpTestSucceeded
```

**成功标准：**输出的 `ComputerName` 为 `10.0.30.5`、`RemotePort` 为 `22`、`TcpTestSucceeded` 为 `True`。若为 `False`，保留结果即可；它可能涉及 EasyTier 路由、学校网络或防火墙，不要自行改 PVE 网络配置。家庭局域网内运行即使为 `True`，也不能记为 EasyTier 异地路径通过。工作台网页仍只绑定 Ubuntu 回环 18000，因此这个测试成功也不代表远程网页已可访问。

**用户现场结果：**返回 `10.0.30.5  22  True`。按用户遵循上述家外网络/EasyTier 步骤的上下文，记为该 Windows 设备到 Ubuntu SSH 端口的 TCP 技术测试通过；输出本身不显示网络类型或 EasyTier 状态。网页访问、手机及学校网络未测试。

### 临时查看既有测试站登录页（2026-10-17 用户反馈通过）

**操作位置：**同一台已连接 EasyTier、位于家外网络的 Windows 电脑，打开项目目录 `D:\Projects\teacher-workbench` 的 PowerShell。下面命令使用先前由 Ubuntu 控制台核对过的 SSH 主机公钥，通过加密隧道把服务器本机回环 `18000` 映射到**这台电脑**的回环 `18001`。它不运行远端命令、不修改服务器、不让其他 EasyTier 成员直接访问测试站；本机的 `data/ssh-known-hosts-review` 文件须存在。只用于查看旧版虚构测试站，不输入真实教学资料、真实成员密码或 API Key。

```powershell
ssh -N -L 127.0.0.1:18001:127.0.0.1:18000 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5
```

**预期：**如提示输入 `huahua@10.0.30.5` 的 SSH 密码，只在自己的终端输入，输入时不显示字符；连接成功后 PowerShell 光标会一直停在这里，这是隧道保持运行的正常现象。不要把密码或完整终端截图发给助手。另开本机浏览器访问 `http://127.0.0.1:18001/login/`；预期看到“教师工作台”登录页及正常样式。若出现主机密钥变化、端口占用、`Permission denied` 或无法访问页面，停止并只反馈不含密码的错误文字，不自行改防火墙或 SSH 配置。检查结束回到原 PowerShell 按 `Ctrl+C` 关闭隧道；刷新浏览器应无法再访问。此法不验证新版登录限速、账号登录、手机直接访问、HTTPS 或 PWA。

**用户现场结果：**反馈“正常访问教师工作台登录页”。只记页面可见，尚未登录账号或验证新版代码。

### 为浏览器验收建立一个虚构普通账号（2026-10-17 用户现场通过）

**范围与影响：**只在 Ubuntu 257 现有 `teacher-workbench-test` 隔离测试数据库新增用户名 `browser_preview_20261017` 的普通账号；不改现有两名备份探针账号、不改运行中的 Web/worker 镜像、不更改端口、不调用 AI，也不修改 PVE、LXC、NAS 或正式环境。新密码由用户在终端无回显输入两次，脚本只保存 Django 密码哈希，不输出明文。请使用**全新的测试专用密码**，不要使用真实账号、NAS、SSH 或厂商密码。已有同名账号时脚本会拒绝覆盖；不自动重置密码。

**执行前核对（历史）：**Python 语法编译通过；在本机 SQLite 配置中安全闸门拒绝建号；Git Bash `bash -n` 通过，脚本为 UTF-8、LF 换行。`scripts/prepare_ubuntu_browser_preview_user.py` 与 `.sh` 的 SHA-256 分别为 `29fa3c0ee20fd6bd109168f327859d15e93ddec7996c66a3cd17c94761917ef5`、`8e3f9b31ebf922a84fe41f4652928b0c8d345f3b3de335be7569db81311a7d80`；Ubuntu 建号结果见下段。若修改脚本须重新计算，不沿用这两个值。

**操作位置：**用户的 Windows PowerShell，项目文件仍在 `D:\Projects\teacher-workbench`。按顺序执行三行；第一行只检查 Ubuntu 家目录不存在同名脚本，看到 `PREVIEW_UPLOAD_PATH_FREE` 才执行第二行。第二行只传两份无凭据的脚本；第三行先核对哈希和 Bash 语法，随后只在测试数据库创建账号。SSH、`sudo` 和新测试密码仅在用户自己的终端输入，不要把密码发给助手。若此前的 SSH 隧道窗口仍开着，可另开 PowerShell 执行；若已关闭，建号后按上节重新打开隧道。

```powershell
ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "test ! -e ~/prepare_ubuntu_browser_preview_user.py && test ! -L ~/prepare_ubuntu_browser_preview_user.py && test ! -e ~/prepare_ubuntu_browser_preview_user.sh && test ! -L ~/prepare_ubuntu_browser_preview_user.sh && echo PREVIEW_UPLOAD_PATH_FREE"
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\prepare_ubuntu_browser_preview_user.py" "D:\Projects\teacher-workbench\scripts\prepare_ubuntu_browser_preview_user.sh" "huahua@10.0.30.5:"
ssh -tt -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "cd ~ && printf '29fa3c0ee20fd6bd109168f327859d15e93ddec7996c66a3cd17c94761917ef5  prepare_ubuntu_browser_preview_user.py\n8e3f9b31ebf922a84fe41f4652928b0c8d345f3b3de335be7569db81311a7d80  prepare_ubuntu_browser_preview_user.sh\n' | sha256sum -c - && bash -n prepare_ubuntu_browser_preview_user.sh && bash prepare_ubuntu_browser_preview_user.sh"
```

**成功标准与浏览器检查：**终端出现两个 `OK`、`PREVIEW_TEST_ACCOUNT_READY username=browser_preview_20261017 staff=False; password hidden`、`PREVIEW_LOGIN_HTTP_200`。在隧道保持打开的浏览器 `http://127.0.0.1:18001/login/` 使用该用户名和刚才自己输入的测试密码登录；预期进入“首页看板”，可见普通导航，不能访问管理后台。只反馈成功标记和页面表现，**不要发送密码**。此操作不能验收新版登录限速、自动备份、手机、HTTPS 或 PWA；测试结束后按 `Ctrl+C` 关闭隧道。

**用户现场结果（2026-10-17）：**用户提供 `PREVIEW_TEST_ACCOUNT_READY username=browser_preview_20261017 staff=False; password hidden`、`PREVIEW_LOGIN_HTTP_200` 和 SSH 会话关闭。账号已建成；**不要重跑建号脚本**，同名账号安全闸门会拒绝覆盖。用户接着看到浏览器“`127.0.0.1` 拒绝连接”；助手在当前 Windows 电脑只读检查本地 `18001` 没有监听。原因与上节的临时 SSH 隧道已关闭相符，不能据此判断服务器登录页故障。

**恢复浏览器测试（2026-10-17 已执行；再次访问时可沿用）：**在需要测试的 Windows 电脑上，保持 EasyTier 连接，重新打开上节的 `ssh -N -L 127.0.0.1:18001:127.0.0.1:18000 ...` 命令。输入的是 Ubuntu `huahua` 的 SSH 密码；看到光标停住后**保持该 PowerShell 窗口打开**，另开浏览器访问 `http://127.0.0.1:18001/login/`，使用已经建立的 `browser_preview_20261017` 和刚才自定的测试账号密码登录。浏览器中的 `127.0.0.1` 指当前 Windows 电脑；只有 SSH 隧道运行时才有服务。如果仍拒绝连接，先只读检查本地 `18001` 是否监听，并反馈不含密码的 SSH 错误。不要重新建号、修改防火墙或把测试站改为全网卡监听。

**用户现场结果（2026-10-17）：**用户反馈已能进入首页。该恢复步骤已通过；无需再次建号。若关闭隧道，下次查看时仍需按上节重新打开。

### 用虚构 Word 验收资料上传与下载（2026-10-17 用户现场通过）

**操作位置：**在 Windows 电脑保持 SSH 隧道开启，用已建虚构账号进入 `http://127.0.0.1:18001/`。点左侧“课件与资料”，在“上传资料”中选择本项目已有的 `D:\Projects\teacher-workbench\data\preview-exports\离线排版样例-学生卷.docx`，再点“上传并提取文字”。文件约 37 KB，为以前生成的虚构排版样例；本机已验证可抽取 153 字、含虚构标记；不用真实教学资料。测试 Compose 强制 `AI_ENABLED=0` 且空 Key，这一步只上传和抽取，不触发模型。

**预期与记录：**页面提示“资料已保存，文字已提取”，在“我的资料”中出现该文件名。点同一行“下载原文件”，浏览器应下载 DOCX，WPS 可打开并显示两道虚构题。只反馈上传提示、资料是否出现、下载能否打开，不发送文件或密码。若浏览器再次显示 `127.0.0.1` 拒绝连接，先确认运行 `ssh -N` 的 PowerShell 窗口仍开着；不要重传或重建账号。执行前服务器上传/下载、原文件内容与跨账号拒绝尚未由本轮现场验证；执行结果见下条。

**用户现场结果（2026-10-17）：**反馈“资料出现在‘我的资料’列表，下载的 Word 能打开”。因此上述虚构文件的浏览器上传列表和原文件下载/打开已通过；成功提示文字、服务器抽取字段、下载哈希、跨账号拒绝未由用户单独核对。文件已经在测试库中，**不要为了重复验收再次上传**。已有 PostgreSQL 虚构流程与 NAS 独立恢复脚本曾验证跨账号 404，详见[验收记录](acceptance.md)；它们不等于当前浏览器的第二账号实际验收。

**原候选域名调查（当前不执行）：**助手先前查询发现 `workbench.huahuaya.top` 和随机子域名返回同一公网 IPv6，提示可能存在通配 AAAA。用户已明确当前不使用域名；不再要求打开 Cloudflare 或核对这些记录。将来重启 HTTPS/PWA 工作时再处理。

## 隔离测试卷一致性备份（修订版于 2026-10-16 用户现场通过）

- **范围：**仅 Ubuntu 257 的 `teacher-workbench-test` 测试栈。先在其数据库和私有文件卷中建立一份明确标注的虚构资料、两个不可用密码的测试账号及两版草稿；若同名记录已存在，脚本只核对、不覆盖。随后临时停止 Web/worker 写入，导出 PostgreSQL 自洽备份与私有文件卷压缩包并校验可读取性、SHA-256，最后重新启动 Web/worker 并核对回环登录页。备份只保存在 `huahua` 家目录下权限 700 的新测试备份目录，**不上传 NAS、不含实际教学资料、不删除卷**。测试站会短暂停止响应；失败时脚本会尝试重新启动 Web/worker，并留下标为 `INCOMPLETE` 的目录供排查。Redis 队列卷不在这次数据库/原件配对备份中；AI 已强制关闭。
- **本机检查：**虚构种子程序语法编译通过，在 Django 自动创建并删除的本机测试数据库中完成首次建立与再次运行不覆盖的检查；Shell 脚本为 LF 换行，静态核对没有清除 Docker 卷或 NAS 写入命令，且有失败时重启 Web/worker 的清理钩子。Bash 语法由 Ubuntu 执行前 `bash -n` 核对；Ubuntu 的 `pg_dump`、私有卷归档、重启和恢复尚未执行。**创建备份不等于恢复成功。**下一步须用另一套独立卷演练还原，不覆盖原测试栈。
- **操作位置：**用户电脑 Windows PowerShell，依次执行下面两行。第一行只把两份脚本上传到 Ubuntu `huahua` 家目录；第二行先核对 Bash 语法，再运行。SSH 和 `sudo` 密码只在终端输入，不发给助手。预计测试网页暂停约几十秒；失败时保留输出，不执行清卷命令。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\seed_test_backup_probe.py" "D:\Projects\teacher-workbench\scripts\backup_ubuntu_test_stack.sh" "huahua@10.0.30.5:"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "bash -n backup_ubuntu_test_stack.sh && bash backup_ubuntu_test_stack.sh"
```

- **成功标准：**依次看到 `TEST_BACKUP_PROBE_READY`、`TEST_APPLICATION_WRITES_STOPPED`、`TEST_WEB_RESTARTED_HTTP_200`、`TEST_BACKUP_FILES_VERIFIED` 和 `TEST_BACKUP_DIR=...`。只需反馈这些标记及最后目录路径，不要发送备份内容或 `.env`。若缺少最后的成功标记，不能记为备份完成；保留现场，等待排查。
- **用户现场进度（2026-10-16）：**已收到前两项标记：虚构记录建立，Web/worker 已停止。其后的 `pg_dump` 和私有卷 `tar` 均重定向到备份文件，完成前没有进度输出。用户报告光标持续闪动；备份文件、完整性校验和 Web 重启尚未得到证据。原 SSH 窗口保持打开；若超过两分钟无新输出，在 Windows 第二个 PowerShell 窗口执行下面的只读诊断。密码只在自己的终端输入，勿复制备份内容或配置。

```powershell
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "cd teacher-workbench-test-9e29fddf && sudo docker compose ps; ps -C pg_dump,tar,docker -o pid,etime,stat,comm; find ~/teacher-workbench-test-backups -mindepth 2 -maxdepth 2 -type f -printf '%f %s bytes\n'"
```

  预期输出为四服务状态、正在运行的导出/归档进程以及 `db.dump`、`private.tar.gz` 等文件大小。此命令不打开或改变备份内容。**不要因为终端暂时无输出就重复启动备份脚本或删除卷。**

- **首次现场诊断结果（2026-10-16）：**db/redis healthy，Web/worker 未运行，`db.dump` 为 0 字节、`STATE` 为 11 字节，未列出导出或归档进程。本次备份未完成。先在原窗口按一次 `Ctrl+C` 并等待退出；若 30 秒仍未退出，停下并反馈。退出后，在 Windows 第二个 PowerShell 窗口执行下面的测试服务恢复命令。它只启动既有 Web/worker 容器，不重建或清理卷。成功标准是两项服务 `Up` 和 `TEST_LOGIN_HTTP_200`；此命令和恢复结果目前**待现场执行/核实**。

```powershell
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "cd teacher-workbench-test-9e29fddf && sudo docker compose start web worker && sleep 5 && sudo docker compose ps && curl --noproxy '*' -s -o /dev/null -w 'TEST_LOGIN_HTTP_%{http_code}\n' http://127.0.0.1:18000/login/"
```

  保留 `INCOMPLETE` 目录用于排查，不使用该目录做恢复，也不删除数据库或私有卷。

- **本地脚本修订（尚未上传/运行）：**新增导出与归档阶段标记、超时、停止前的 `sudo` 授权刷新及停止后的非交互 `sudo`；失败时显示自动重启是否成功。旧的服务器脚本不受本地修改影响。恢复测试服务并定位本次故障后，才考虑传输修订版重试；不得把 `db.dump` 的 0 字节文件当备份使用。
- **服务恢复的用户现场结果（2026-10-16）：**`docker compose start web worker` 成功，db/redis healthy，Web/worker 均 Up，Web 仍只绑定回环地址，登录页 `TEST_LOGIN_HTTP_200`。旧备份仍无效；此前卡在何处尚未由原终端输出定位。

### 修订版备份重试（本机语法通过，Ubuntu 待执行）

本机脚本现在会在停止 Web/worker **之前**用非交互 `sudo` 完成 PostgreSQL 结构导出和私有文件卷只读归档预检；预检失败不会停服务。停机后数据库导出、私有文件归档、停止/启动均有阶段提示与时限，错误会尝试重启服务并保留新的 `INCOMPLETE` 目录。脚本拒绝与旧备份进程或另一份修订版备份并行。修订版在 Windows Git Bash 执行 `bash -n` 通过，文件为 LF，静态检查无删卷命令；**Ubuntu 运行和自动恢复路径均未验证**。旧的 0 字节 `db.dump` 保留供故障排查，不参与此次新备份。

**操作位置：**用户电脑 Windows PowerShell，原备份窗口已经结束后依次执行两行。第一行只上传本地修订版到 Ubuntu 用户家目录的**新文件名**；第二行先核对 SHA-256 与 Bash 语法，再运行。SSH/`sudo` 密码只在自己的终端输入，不发给助手。

**旧窗口关闭后的核对（部分结果）：**用户只确认已关闭原 PowerShell 窗口；随后贴出四服务 Up、db/redis healthy、`TEST_LOGIN_HTTP_200`，但未包含进程检查标记，旧脚本是否退出尚未由该输出证明。下面是此前提供的只读核对命令，保留供排查；修订版脚本在任何停服务动作前也会独立检查旧脚本，发现旧进程则输出 `OLDER_BACKUP_ATTEMPT_STILL_RUNNING` 并退出。命令不会读取备份内容或修改服务。

```powershell
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "if ps -eo args= | grep -E '^bash (\./)?backup_ubuntu_test_stack\.sh$' >/dev/null; then echo OLD_BACKUP_STILL_RUNNING; else echo OLD_BACKUP_NOT_RUNNING; fi; cd teacher-workbench-test-9e29fddf && sudo docker compose ps && curl --noproxy '*' -s -o /dev/null -w 'TEST_LOGIN_HTTP_%{http_code}\n' http://127.0.0.1:18000/login/"
```

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\backup_ubuntu_test_stack.sh" "huahua@10.0.30.5:backup_ubuntu_test_stack_4441766e.sh"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "printf '4441766e81c4a4927bdf95d775518bea09980082116c3bd63896f956de7b89a4  backup_ubuntu_test_stack_4441766e.sh\n' | sha256sum -c - && bash -n backup_ubuntu_test_stack_4441766e.sh && bash backup_ubuntu_test_stack_4441766e.sh"
```

**成功标准：**先看到文件校验 `OK`、`OLD_BACKUP_NOT_RUNNING`、`TEST_BACKUP_PROBE_READY (existing fictional records)`、`TEST_POSTGRES_PREFLIGHT_OK`、`TEST_PRIVATE_PREFLIGHT_OK`；后续依次出现 `TEST_APPLICATION_WRITES_STOPPED`、`TEST_POSTGRES_DUMP_READY`、`TEST_PRIVATE_ARCHIVE_READY`、`TEST_WEB_RESTARTED_HTTP_200`、`TEST_BACKUP_FILES_VERIFIED` 与新的 `TEST_BACKUP_DIR=...`。若出现 `OLDER_BACKUP_ATTEMPT_STILL_RUNNING`，脚本会在停服务前退出。若缺少任一末尾成功标记，视为未完成；不要再次运行或使用 `INCOMPLETE` 目录，先反馈最后输出并检查 Web 状态。即使备份成功，恢复到独立卷仍待演练。

**用户现场结果（2026-10-16）：**修订版备份脚本末尾输出 `TEST_WEB_RESTARTED_HTTP_200`、`TEST_BACKUP_FILES_VERIFIED`、`TEST_BACKUP_DIR=/home/huahua/teacher-workbench-test-backups/backup-NX5wqA1m`。按脚本流程，它在写入 `TEST_BACKUP_COMPLETE` 状态前检查 PostgreSQL 导出可列出内容、私有文件归档含 `materials/`、两文件非空且 SHA-256 一致；Web 重启并回环登录 HTTP 200。用户只提供末尾输出，助手没有读取服务器备份内容。旧 `INCOMPLETE` 目录仍应保留作故障记录，**不可当有效备份**。独立恢复的后续结果见下节；NAS 仍未验证。

### 将该备份恢复到独立测试卷（2026-10-16 用户现场通过）

`scripts/restore_ubuntu_test_backup.sh` 只接受上面已记录的 `backup-NX5wqA1m`：先核对完成状态、数据库/文件和源码校验值、归档路径安全、源测试栈与镜像；再建立 `teacher-workbench-restore-nx5wqa1m` 专用网络、PostgreSQL 卷和私有文件卷。它生成新的随机测试密钥且不显示，AI 保持关闭；恢复数据库和文件后用 `scripts/verify_restored_test_probe.py` 核对虚构资料、两版草稿、预览、学生/教师双 Word 与跨账号拒绝，并在 `127.0.0.1:18001` 短暂检查登录页。成功后停止新增的 Web/DB 容器，**保留新增卷、备份及原测试栈**。失败时也保留状态供排查，不自动重跑或清卷。此项不连接 NAS、不发布服务。

虚构账号设置为不可用密码，新测试环境使用新 Django 密钥，因此本演练不验证旧会话延续、真实账号密码登录或原密钥恢复；未来正式恢复方案必须单独处理密钥并由用户实际登录验收。

本机已用临时 SQLite 测试数据库和临时私有文件目录对核对程序运行 1 项虚构流程，输出 `RESTORE_FIXTURE_AND_ACCESS_OK`，随后测试数据库删除；恢复脚本 Git Bash 语法、LF 换行和无删卷命令检查通过。**这些不等于 Ubuntu PostgreSQL 上的恢复通过。**

**操作位置：**用户电脑 Windows PowerShell，依次执行下面两行。第一行只上传两个脚本到 Ubuntu `huahua` 家目录；第二行先核对两文件 SHA-256 和 Bash 语法，再恢复到全新测试卷。SSH/`sudo` 密码仅在用户终端输入，勿发送 `.env`、备份文件或原始资料。脚本会临时占用约 18001 端口，只绑定 Ubuntu 本机回环；原测试网页 18000 不停止。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\restore_ubuntu_test_backup.sh" "D:\Projects\teacher-workbench\scripts\verify_restored_test_probe.py" "huahua@10.0.30.5:"
ssh -t -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "printf 'f78747b75dec9f542f6574ec6235f32be8df26af4c543d18156080ad4fb6fb1a  restore_ubuntu_test_backup.sh\n534071c1b38cc7f0f45efa4f3a0703f5e302b1690f01366d42753ff851d33060  verify_restored_test_probe.py\n' | sha256sum -c - && bash -n restore_ubuntu_test_backup.sh && bash restore_ubuntu_test_backup.sh"
```

**成功标准：**先看到两个文件的校验 `OK`、`RESTORE_BACKUP_VERIFIED`、`RESTORE_ISOLATION_PREFLIGHT_OK`；之后依次出现 `RESTORE_POSTGRES_READY`、`RESTORE_PRIVATE_READY`、`RESTORE_FIXTURE_AND_ACCESS_OK`、`RESTORE_LOGIN_HTTP_200`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`INDEPENDENT_RESTORE_VERIFIED`。只需反馈这些标记和最后 `RESTORE_TEST_DIR=...`。缺少最终标记就不能记为恢复成功；不要重新运行脚本、删除卷或把 18001 接入内网穿透，先反馈末尾错误。即使通过，也只证明这份虚构测试备份可恢复，不等于 NAS/正式环境的备份方案已落实。

**用户现场结果（2026-10-16）：**提供了 `RESTORE_ISOLATION_PREFLIGHT_OK`、`RESTORE_TEST_ENV_READY`、`RESTORE_EMPTY_DATABASE_READY`、`RESTORE_POSTGRES_READY`、`RESTORE_PRIVATE_READY`、`RESTORE_FIXTURE_AND_ACCESS_OK`、`RESTORE_LOGIN_HTTP_200`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`INDEPENDENT_RESTORE_VERIFIED`，独立目录为 `/home/huahua/teacher-workbench-restore-nx5wqa1m`。中间三条 `Not Found` 对应第二账号访问第一账号资料下载、作业详情和教师版 Word，正是预期 404。按脚本流程，新恢复容器已停止、恢复卷保留，源测试站回环登录页仍为 HTTP 200；助手未直接连接服务器复核。虚构账号使用不可用密码及新 Django 密钥，真实密码登录、原会话及密钥恢复仍待单独验收；NAS 未涉及。

### Ubuntu 到 OMV 的只读摸底（2026-10-16 用户现场通过）

`scripts/check_ubuntu_nas_readonly.py` 只对已记录的 OMV 地址 `10.0.30.6` 检查 NFS TCP 2049 和 SMB TCP 445 是否可连接，并统计 Ubuntu 当前的 NFS/CIFS 挂载数量及来源直接写为该 IP 的数量。它不使用 `sudo`，不装载共享、不输入凭据、不读写 NAS 文件；只输出布尔结果和数量。端口不可连接不一定表示 NAS 停机，来源用主机名时 `NAS_IP_MOUNT_COUNT=0` 也不能排除已有挂载。即使端口可连接，也不代表有目录写权限或已建立业务备份。

**操作位置：**用户电脑 Windows PowerShell，运行下面两行。第一行把只读脚本复制到 Ubuntu 用户家目录；第二行校验脚本 SHA-256 后在 Ubuntu 运行。仅需提供从 `NAS_TARGET=` 到 `NAS_READONLY_SURVEY_DONE` 的输出，不发送密钥或 NAS 路径。此检查不触碰 PVE 宿主机。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\check_ubuntu_nas_readonly.py" "huahua@10.0.30.5:check_ubuntu_nas_readonly.py"
ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "printf 'da8e3fedd42255f9cfd42c3e3cdc5b2188beec62f7ce13c814e00a86e1c782df  check_ubuntu_nas_readonly.py\n' | sha256sum -c - && python3 -B check_ubuntu_nas_readonly.py"
```

**预期可见结果：**先看到 `check_ubuntu_nas_readonly.py: OK`，最后看到 `NAS_READONLY_SURVEY_DONE`，中间列出两个端口的 `reachable`/`not_reachable` 和挂载数量。结果只决定后续 NAS 方案需要哪种接入方式，不能记为 NAS 备份通过。

**用户现场结果（2026-10-16）：**脚本上传与 SHA-256 校验成功，输出 `NAS_TARGET=10.0.30.6`、`NAS_NFS_TCP_2049=reachable`、`NAS_SMB_TCP_445=reachable`、`NETWORK_MOUNT_COUNT=0`、`NAS_IP_MOUNT_COUNT=0`、`NAS_READONLY_SURVEY_DONE`。据此确认 Ubuntu 可到达两个服务端口，且检查时没有 NFS/CIFS 挂载。未尝试挂载、认证、列目录或写备份；PVE 现有挂载不会自动出现在 Ubuntu。

**后续备份方案待配置：**第一版扩展时先在 OMV 确定工作台专用共享或目录及 Ubuntu 的最小访问权限，不直接占用 PVE 备份根目录。选定 NFS 或 SMB、挂载方式、保留版本数和密钥恢复方式后，先把一份虚构测试数据的配对备份转存到该专用位置，再从 NAS 副本恢复到另一套隔离卷，最后核对资料、历史版本、双 Word 与账号隔离。端口可达不能代替共享授权与读写/恢复测试。上述目录、权限、命令和自动周期目前均**待验证**，尚未在 Ubuntu 或 OMV 执行。

### OMV NFS 导出可见性只读检查（用户已执行，工具缺失）

这是 [NAS 接入方案](nas-backup-plan.md) 的下一道信息闸门。`scripts/check_ubuntu_nfs_exports_readonly.py` 只在 Ubuntu 257 以 `huahua` 身份查看是否有 `mount.nfs`、`showmount` 工具，并在工具存在时查询 OMV 的 NFS 导出列表。它只显示交接记录中的 `/export/backup` 是否列出及该行客户端说明，不显示其他共享；不使用 `sudo`、不挂载、不认证、不读取或写入 NAS 文件。`showmount` 无法查询时不能推断 NFSv4 共享不可用。

**操作位置：**用户电脑 Windows PowerShell，依次运行以下两行；密码只在自己终端输入。第一行上传脚本到 Ubuntu 用户家目录；第二行核对 SHA-256，再执行只读查询。不要把 OMV 密码或其他共享目录贴到聊天。

```powershell
scp -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 "D:\Projects\teacher-workbench\scripts\check_ubuntu_nfs_exports_readonly.py" "huahua@10.0.30.5:check_ubuntu_nfs_exports_readonly.py"
ssh -o StrictHostKeyChecking=yes -o UserKnownHostsFile=D:/Projects/teacher-workbench/data/ssh-known-hosts-review -o HostKeyAlgorithms=ssh-ed25519 huahua@10.0.30.5 "printf 'd9e6544465cdbcebbcfd0eaa671fcb57eb15ee3b2b7b14ccb43be871634d8d52  check_ubuntu_nfs_exports_readonly.py\n' | sha256sum -c - && python3 -B check_ubuntu_nfs_exports_readonly.py"
```

**预期可见结果：**先看到 `check_ubuntu_nfs_exports_readonly.py: OK`，最后看到 `NFS_EXPORT_SURVEY_DONE`。中间可能是 `NFS_EXPORT_LIST=returned`、`tool_absent` 或 `unavailable`，都属于只读检查结果，不能记为共享授权通过。只需反馈从 `NAS_TARGET=` 到末尾标记的输出。

**用户现场结果（2026-10-16）：**`check_ubuntu_nfs_exports_readonly.py: OK`，随后 `NFS_MOUNT_HELPER=absent`、`NFS_EXPORT_LIST=tool_absent`、`NFS_EXPORT_SURVEY_DONE`。此脚本没有列出任何共享，因为 Ubuntu 缺少工具；**不能把 `tool_absent` 理解为 OMV 没有 NFS 导出**。当前不为此安装软件，不尝试挂载，也不修改现有 PVE 备份共享。

### 在 OMV 管理页面核对备份共享（只查看，NFS 列表已核对）

**操作位置：**用户自己的 Windows 浏览器，打开平时登录的 OMV 管理页面；登录凭据只输入在 OMV，不发给助手。官方文档把共享文件夹放在“存储 → 共享文件夹”，NFS 服务共享放在“服务 → NFS → 共享”。不同版本的界面名称可能略有差异：[OMV 共享文件夹说明](https://docs.openmediavault.org/en/stable/administration/storage/sharedfolders.html)、[OMV NFS 说明](https://docs.openmediavault.org/en/8.x/administration/services/nfs.html)。

1. 在共享文件夹列表只查看：是否已有**专门给教师工作台**的文件夹；若有，记名称和所在存储设备。不要新建、编辑或删除。
2. 在 NFS 共享列表只查看：上述专用文件夹是否有对应导出；另找交接记录中的 PVE `backup` 共享，记其“客户端”和“权限（只读/读写）”两列。不要改动 PVE 的条目，也不要点击保存/应用。
3. 只反馈工作台专用共享是否存在，以及相关条目的名称、客户端和权限；可截取相关行，遮住无关共享。**预期结果**是能区分“已有工作台专用共享”“只有 PVE 备份共享”“没有可见 NFS 共享”三种情况之一。若菜单或登录方式不同，只反馈当前可见菜单，不提供密码。

这是只读核对，不能证明 Ubuntu 具有 NFS 文件权限。官方文档说明 NFS 导出还涉及客户端范围与 UID/GID 文件权限；具体新建、授权、Ubuntu 安装客户端与挂载步骤都要基于现场结果另行制定。

**用户现场结果（2026-10-16）：**用户截图显示 NFS 列表只有 `backup`、`share` 两项，客户端均为 `10.0.30.0/24`，选项含 `rw` 与 `no_root_squash`；未见教师工作台专用 NFS 条目。共享文件夹的底层设备和权限仍未知。现有两个条目不改动；截图不代表 Ubuntu 已可读取或写入。

**原定只读操作（已执行，结果见下条）：**在 Windows 浏览器的 OMV 管理页面打开「存储 → 共享文件夹」，查看 `backup`、`share` 两行的「设备」「相对路径」「权限」等可见列，并留意是否存在名称明确的教师工作台专用文件夹。只截取相关行并遮住无关共享；若某列未显示，反馈实际可见列即可。预期是辨认这两个现有文件夹放在哪个存储设备，以及是否已有可单独配置的工作台文件夹。不要点击新增、编辑、删除或应用更改；这一步不涉及 Ubuntu、PVE 或 NAS 写入。

**用户现场结果（2026-10-16）：**共享文件夹列表显示 `backup`、`share` 均在 `/dev/sda`，相对路径分别为 `backup/`、`share/`，状态 Available；`Photos`、`family` 在 `/dev/sdb1`。没有名称明确的教师工作台专用文件夹。该列表没有显示文件权限；用户只读查看，没有提供新建或修改结果。

**授权记录（2026-10-16）：**用户同意在 OMV `/dev/sda` 新建工作台专用文件夹及单独受限访问入口，仅用虚构数据验证备份与独立恢复；没有授权修改现有 `backup`、`share`、PVE 或正式服务。

### 第一步：创建空的专用共享文件夹（用户现场截图已确认）

**操作位置：**用户电脑的 Windows 浏览器，登录原有 OMV 管理页面，打开「存储器 → 共享文件夹」。这是 OMV 写操作；助手没有可复用的 OMV 登录会话。登录密码只输入 OMV 页面，不发到聊天。

1. 点击列表左上角的蓝色加号。**名称**填 `teacher-workbench-backup`；**设备**选与现有 `backup`、`share` 相同的 `/dev/sda`；**相对路径**填 `teacher-workbench-backup/`。若页面自动带出同名路径，只核对即可。
2. **权限**选“管理员：读写；用户：无访问；其他人：无访问”（`700`）。OMV 官方文档提示新建默认是 `775`，因此必须主动核对这一项。这里的“管理员”是 OMV 文件夹权限选项，不是教师工作台账号。
3. 保存新文件夹；如果页面提示有待应用更改，仅应用这次新建。完成后列表应出现 `teacher-workbench-backup`，设备 `/dev/sda`、相对路径 `teacher-workbench-backup/`、状态 Available。请只反馈这四项和权限选择结果；若设备或权限选项与上述不同，停在表单，不猜测也不保存。

此时**不要创建 NFS 或 SMB 共享，不要复制备份、改动 `backup`/`share`，也不要把密码发到聊天**。空目录的创建成功只验收文件夹本身；后续专用身份、SMB 私有共享、Ubuntu 挂载与 NAS 来源恢复分别核对。

**用户现场结果（2026-10-16）：**新增行显示名称 `teacher-workbench-backup`、设备 `/dev/sda`、相对路径 `teacher-workbench-backup/`、状态 Available。截图未显示新建时选择的权限、实际文件所有者或 POSIX 模式；这些仍需核对，不能把 Available 当作 `700` 的证明。

### 第二步：只读查看专用文件夹权限（用户现场截图已确认顶层 POSIX 模式）

**操作位置：**仍在 OMV 的「存储器 → 共享文件夹」。选中**仅** `teacher-workbench-backup` 这一行，点击工具栏的“访问控制列表 / ACL”入口。若图标没有文字，先将鼠标悬停看提示，不要误点删除或更改权限。打开后只查看面板底部的文件所有者、所属组以及“所有者 / 组 / 其他人”读写执行权限；预期为所有者 `root`、组 `users`、只有所有者有读写执行权限（`700`）。截图只需包含这些字段，遮住无关用户；**不要勾选递归、保存或应用**。如果界面没有 ACL 入口或看到的模式不是 `700`，原样反馈，不打开网络共享。

此处只核对文件系统权限。OMV 的“权限”按钮设置的是 SMB/FTP 服务访问权限，不能代替 ACL 面板中的 POSIX 权限；二者后续都要核对。

**用户现场结果（2026-10-16）：**ACL 页面显示新文件夹顶层所有者 `root [0]`、所属组 `users [100]`、所有者“读/写/执行”、组“无”、其他人“无”，对应 `700`；“递归”未勾选。第二张截图只展示 ACL 用户/组列表的开头，不能据此断言所有命名 ACL 项的状态。用户未报告在该页保存或应用更改。

### 第三步：核对现有 SMB 共享入口（只查看，待用户现场执行）

**操作位置：**在 Windows 浏览器的 OMV 管理页面打开「服务 → SMB/CIFS → 共享」（部分版本显示“SMB”或“Samba”）。只截取共享名称、关联文件夹和公开/访客访问方式等可见列，遮住无关信息；若页面为空，也反馈“列表为空”。**不要新建、编辑、删除或保存。**预期是知道 NAS 是否已有其他 SMB 共享，避免随后创建的备份专用账号因默认加入 `users` 组而意外获得其他共享入口。用户创建账号的步骤将在核对现有共享后执行；密码只在 OMV 页面输入，不发送聊天。

**用户现场结果（2026-10-16）：**四个已启用的 SMB 共享为 `Photos`、`backup`、`family`、`share`，均显示“公开 No”“可浏览”勾选；新文件夹没有 SMB 共享。该列表不显示 `users` 组或账号权限。助手尝试使用 Computer Use 做只读浏览器检查，但其 `@oai/sky` 模块在当前运行环境未提供，因此没有直接访问 OMV 页面；下述检查仍由用户在 OMV 管理界面完成。

### 第四步：查看四个现有共享的服务级权限（用户截图已提供）

**操作位置：**在 OMV「存储器 → 共享文件夹」依次选中 `Photos`、`backup`、`family`、`share`，每次点击工具栏中名为“权限”的入口（不是 ACL，也不是编辑/删除）。只查看该共享的用户/组权限表，特别是 `users` 组的“读写 / 只读 / 无访问”选择；可用表格搜索框查找 `users`。分别截取四个页面的相关行，或直接回复四个共享里 `users` 组各自的状态。**不要改动选项、保存或应用。**若界面不显示 `users` 组或权限含义不清，直接反馈画面；不要创建备份账号。

这一步只核对未来账号可能继承的服务级权限，不检查现有共享的内容。即使四项都显示“无访问”，还需在创建专用账号后核对该账号自己的权限，再开放新的备份共享。

**用户现场结果（2026-10-16）：**四张权限页只出现 `huahua` 用户行，没有 `users` 组行；两张 `huahua` 为 Read/Write，两张权限均未选中。截图不含共享名称，无法逐一对应。OMV 官方 Samba 文档提示空白选择不能可靠证明新账号无法进入非公开共享。故暂停新增 SMB 账号与 SMB 共享，不更改四个现有共享。

### 第五步：专用 NFS 测试入口（表单已核对，创建待用户现场执行）

为避免新 SMB 账号可能获得旧共享的访问，虚构数据的 NAS 备份演练改用**单独的 NFS 导出**。它只允许 Ubuntu 257 的 `10.0.30.5` 作为客户端；NFS 不验证用户身份，正式数据使用前还须重新审查权限。先只看表单，不保存：在 Windows 浏览器的 OMV 页面打开「服务 → NFS → 共享」，点击蓝色加号，查看能否选择共享文件夹 `teacher-workbench-backup`，以及客户端、权限和额外选项字段。截图包含整个表单即可；不要修改已有 `backup`/`share` 条目，也不要输入网段 `10.0.30.0/24` 或点击保存。表单确认后，再给出准确值并做虚构数据挂载/恢复验证。

**用户现场结果（2026-10-16）：**新增表单可见“共享文件夹”“客户端”“权限”“扩展选项”；初始权限为“只读”，初始扩展选项为 `subtree_check,insecure`。尚无保存或导出已生效的证据。

**下一次操作位置：**仍在 OMV 的此新增表单，仅为工作台新建一项 NFS 导出，按下列值填写并保存；如果没有 `teacher-workbench-backup` 可选、表单拒绝某个选项，或保存前发现客户端不是单个 IP，则停下并反馈，不猜测替换值。

1. 共享文件夹：`teacher-workbench-backup`（核对是 `/dev/sda` 上已创建的同名文件夹，不选择旧的 `backup` 或 `share`）。
2. 客户端：`10.0.30.5`（Ubuntu 257 的单个 IPv4 地址，不填 `/24` 网段）。
3. 权限：`读/写`。目录目前仍是 `root:users`、POSIX `700`，此设置本身不会让被映射为匿名身份的 NFS 请求获得文件系统写权限；随后单独配置并验证仅这个目录的权限。
4. 扩展选项：完整替换初始内容为 `sync,no_subtree_check,secure,root_squash,all_squash,anonuid=65534,anongid=65534`。不保留默认的 `insecure`，也不使用 `no_root_squash`。全部远端 UID/GID 会映射到匿名身份；`secure` 要求保留端口。这里的 `65534` 是 Linux NFS 匿名 UID/GID，实际写入前还须核对 NAS 文件夹对该身份的 ACL。
5. 标签可留空。保存后如 OMV 提示“应用待处理更改”，仅应用本次新增 NFS 导出。返回共享列表，预期在原 `backup`、`share` 之外新增一行，文件夹为 `teacher-workbench-backup`、客户端正好 `10.0.30.5`，权限 `rw`，选项中有 `all_squash` 且无 `no_root_squash`/`insecure`。请反馈该行截图；不要向新目录复制资料，暂不在 Ubuntu 挂载。

**未验证边界：**OMV 是否已应用导出配置、Ubuntu 的保留端口挂载以及匿名身份的目录权限均待现场确认。正式资料不能因为导出列表出现就视为已有安全备份。NFS 缺少用户认证，来源 IP 限制与匿名映射只用于当前虚构测试数据演练。

**用户现场结果（2026-10-16）：**NFS 列表第三行已出现 `teacher-workbench-backup`，客户端恰为 `10.0.30.5`，扩展选项含 `rw,secure,sync,root_squash,all_squash,anonuid=65534,anongid=65534,no_subtree_check`；原两行仍在。截图没有展示 OMV 顶部是否存在待应用提示，也不能证明导出实际可挂载。列表核对完成；匿名身份的文件夹权限尚未配置。

### 第六步：仅调整专用文件夹的所有者（待用户现场执行）

为使 NFS 匿名映射 `65534` 能在保持 POSIX `700` 的同时使用专用目录，拟将**仅** `teacher-workbench-backup/` 顶层的所有者从 `root [0]` 改为 `nobody [65534]`。这是虚构数据测试方案；不更改现有 `backup/`、`share/` 或其他共享，也不勾选递归。

**操作位置：**Windows 浏览器中的 OMV「存储器 → 共享文件夹」。如页面仍有本次 NFS 新增的待应用提示，先仅应用这次更改；然后选中 `teacher-workbench-backup`，打开“ACL/访问控制列表”（不是“权限”）。在顶层路径 `/` 的“文件的所有者和组”区域，展开“所有者”。**只有选项明确显示 `nobody [65534]` 时**才选择它；组保留 `users [100]`，所有者权限保持读/写/执行，组与其他人保持“无”，递归保持未勾选。核对所选文件夹名称和这五项后保存；若 OMV 提示待应用更改，只应用此次修改。成功标准是重新打开同一 ACL 页面时看到顶层所有者 `nobody [65534]`、组 `users [100]`、仅所有者读/写/执行。请反馈这部分截图。若下拉中没有准确的 `nobody [65534]`、权限/递归状态变化或路径不是顶层 `/`，取消并反馈，不选择其他账号。

**未验证：**此操作还没有在 OMV 执行；即使页面显示预期，也要在 Ubuntu 挂载后用虚构文件实际验证读写、归属和 NAS 来源恢复，不能仅凭 ACL 页面宣称备份通过。

**用户现场结果（2026-10-16）：**两张 ACL 页面截图显示顶层 `/` 所有者 `nobody [65534]`、组 `users [100]`，仅所有者读/写/执行，组与其他人无权限，递归未勾选；命名 ACL 列表只显示前几行。页面没有保存/应用状态，不能据此认定 Ubuntu 已可挂载或写入。

### 第七步：Ubuntu 对专用 NFS 做只读挂载检查（用户已运行初版）

此检查仅访问 Ubuntu 257 和 OMV 的 `teacher-workbench-backup` 导出，不挂载旧 `backup`/`share`，不读取文件内容或打印文件名。脚本在 Ubuntu `/mnt` 下创建临时挂载点，以 `ro,resvport,nosuid,nodev,noexec` 挂载，核对来源、文件系统类型、只读状态与顶层目录可列出，随后卸载并删除**该临时空挂载点**。它不会向 NAS 写文件，不会运行 Docker，也不会修改 PVE。首次需在 Ubuntu 安装 `nfs-common`；安装软件与临时挂载是 Ubuntu 侧的变更，不等于正式部署。

**本机准备与修订（2026-10-16）：**初版 SHA-256 为 `E4D728BFDE03E7BACA435CDF11D2D1AC3888649FFDFC011C9CC37433085327FA`。初版精确要求模式 `700`，现场实际 `2700`，故修订为接受 `700` 或 `2700`，同时单独报告 setgid；修订版 SHA-256 为 `BCF7F073500C4E87C7F6E5B4DDA5C887E78B7AEC163CC5B530E48EE68A5D811D`，本机 AST 通过。修订版尚未在 Ubuntu 运行，当前无需仅为末尾标记重跑。

**用户操作位置 1：Windows PowerShell。**在自己的电脑执行以下命令；`scp` 与 `ssh` 只连接已知 Ubuntu `10.0.30.5`，密码只输入终端，不发聊天。若指纹与已记录主机不一致，停止。

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\scripts\probe_ubuntu_nfs_readonly.py huahua@10.0.30.5:/home/huahua/
ssh huahua@10.0.30.5
```

**用户操作位置 2：SSH 登录后的 Ubuntu 终端。**先校验文件哈希，预期为上方值；再安装 NFS 客户端并运行。Ubuntu `sudo` 若提示密码，只在该终端输入。任何一步报错就停下并反馈输出，不继续后续命令。

```bash
sha256sum /home/huahua/probe_ubuntu_nfs_readonly.py
sudo apt-get update
sudo apt-get install -y nfs-common
sudo python3 /home/huahua/probe_ubuntu_nfs_readonly.py
```

**原定成功标准：**输出 `DEDICATED_NFS_READONLY_MOUNT_OK`、`DEDICATED_NFS_DIRECTORY_READ_OK`、`PROBE_MOUNT_CLEANED`、`NFS_READONLY_PROBE_DONE`，退出码为 0。脚本不显示目录里的文件名。若输出 `PROBE_MOUNT_LEFT_ACTIVE` 或卸载失败标记，先不要重跑或复制备份，保留终端输出以便定位。

**用户现场结果（2026-10-16，初版）：**`DEDICATED_NFS_READONLY_MOUNT_OK`、`NFS_ROOT_UID=65534`、`NFS_ROOT_MODE=2700`、`DEDICATED_NFS_METADATA_UNEXPECTED`、`PROBE_MOUNT_CLEANED`。按脚本顺序，固定来源和只读状态检查通过，目录枚举成功，挂载已清理。末尾成功标记因过严的精确模式判断没有出现，不能记脚本整体通过。`2700` 的额外 setgid 位使新建子项继承组，不给当前组/其他人增加访问位；后续写入脚本用 `umask 077` 并检查新文件为 `600`。无 NAS 写入。

### 第八步：专用 NFS 虚构单文件写入探测（本机已准备，Ubuntu 待执行）

此步只连接 Ubuntu 257 的已知 OMV 专用导出。脚本先临时读写挂载并核对来源、NFS 类型、读写选项、顶层 UID `65534` 以及模式 `700`/`2700`；只有全部匹配才创建一个随机命名的**虚构探测文件**。以 `umask 077` 和文件模式 `600` 写入固定测试字串，读回并核对匿名 UID 与模式，然后仅删除自己创建且内容匹配的文件，最后卸载临时挂载。它不读取教学资料或备份，不接触原有 `backup`/`share`，不运行 Docker，也不修改 PVE。任何清理失败标记都应保留现场供检查，不能继续复制备份。

**本机检查（2026-10-16）：**`scripts/probe_ubuntu_nfs_write.py` Python AST 语法通过；固定导出、写入前来源核对、独占新建、权限核对、读回与单文件清理路径已静态检查。SHA-256：`A18DBC9CF0A6680224AE3C13657D77E682569EA1ACA43E55218FB44955056758`。Ubuntu 尚未运行，不能宣称 NAS 可写。

**操作位置 1：用户电脑的 Windows PowerShell。**在项目目录执行下面两行，第一行只把脚本传到 Ubuntu 用户家目录；第二行打开 SSH。密码仅在终端输入。若 SSH 主机指纹与已记录的不同，停止。

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\scripts\probe_ubuntu_nfs_write.py huahua@10.0.30.5:/home/huahua/
ssh huahua@10.0.30.5
```

**操作位置 2：SSH 登录后的 Ubuntu 终端。**核对第一行完整哈希与上方一致，再运行脚本。`sudo` 密码只在终端输入。若哈希不同，不运行第二行。

```bash
sha256sum /home/huahua/probe_ubuntu_nfs_write.py
sudo python3 /home/huahua/probe_ubuntu_nfs_write.py
```

**成功标准：**依次出现 `DEDICATED_NFS_WRITE_MOUNT_OK`、`NFS_PROBE_FILE_UID=65534`、`NFS_PROBE_FILE_MODE=600`、`NFS_FICTIONAL_WRITE_READBACK_OK`、`NFS_PROBE_FILE_REMOVED`、`PROBE_MOUNT_CLEANED`、`NFS_WRITE_PROBE_DONE`。只反馈这些标记和模式数字，不发 NAS 文件名或教学内容。若缺少后两个清理标记、出现 `LEFT_FOR_REVIEW` 或 `CLEANUP_FAILED`，不要重跑或复制备份，反馈完整探测输出。此步成功仍不等于配对备份已上传或从 NAS 恢复。

**用户现场结果（2026-10-16）：**上述成功标记全部出现，顶层 UID `65534`/模式 `2700`，新文件 UID `65534`/模式 `600`，文件已删除、临时挂载已清理。此项记为**专用 NFS 虚构单文件读写技术测试通过**；配对备份上传、NAS 来源独立恢复及正式资料安全仍待验证。

### 第九步：转存已经验证的虚构配对备份（脚本本机已检查，Ubuntu 待执行）

`scripts/copy_fictional_backup_to_nas.py` 只读取 Ubuntu 本机已验证的 `backup-NX5wqA1m`，先核对完成标记、数据库/私有文件校验和与匹配的测试代码包；**不重新导出数据库、不停现有服务、不读取 `.env`、不触碰真实教学资料**。临时挂载前述专用 NFS 导出并核对来源与权限，建立随机命名的受限暂存目录，复制数据库导出、私有文件归档、两个校验清单、状态文件及对应的虚构测试代码包。每个 NAS 文件须为匿名 UID `65534`、模式 `600`，复制后再校验源与目标哈希；完成状态写入后才改为最终目录名，最后卸载。若中途失败，暂存目录可能留在 NAS 上用于排查，不自动删除或覆盖；**没有 `NAS_FICTIONAL_COPY_DONE` 就不能当有效备份**。

**本机准备（2026-10-16）：**Python AST 语法、错误 NFS 来源拒绝及非目标主机拒绝路径通过；静态检查固定为 `10.0.30.6:/teacher-workbench-backup`，不含 Docker 操作、删除备份目录或读取 `.env`。SHA-256 为 `665122A804713C208DA123F9E1572F18DCB158488EA094842388A642C10474FE`。此脚本尚未在 Ubuntu 运行，NAS 整组备份未验证。

**操作位置 1：用户电脑 Windows PowerShell。**在项目目录执行以下三行。第一行定位项目，第二行只上传脚本到 Ubuntu `huahua` 家目录，第三行 SSH 登录。密码只在本机终端输入；若 SSH 主机指纹与之前已核对结果不同，停止。

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\scripts\copy_fictional_backup_to_nas.py huahua@10.0.30.5:/home/huahua/
ssh huahua@10.0.30.5
```

**操作位置 2：SSH 登录后的 Ubuntu 终端。**先核对第一行完整哈希与上方一致，再执行第二行。第二行会将一份**虚构测试数据**写入专用 NAS 文件夹；`sudo` 密码只在终端输入。哈希不一致就不要执行。

```bash
sha256sum /home/huahua/copy_fictional_backup_to_nas.py
sudo python3 /home/huahua/copy_fictional_backup_to_nas.py
```

**成功标准：**依次看到 `FICTIONAL_SOURCE_BACKUP_VERIFIED`、`DEDICATED_NAS_MOUNT_VERIFIED`、六个 `NAS_COPY_FILE_VERIFIED=...`、`NAS_FICTIONAL_BACKUP_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_BACKUP_NAME=...`、`NAS_FICTIONAL_COPY_DONE`。只反馈这些标记及最后备份名称，不发送文件内容或 `.env`。若输出停在某个文件且终端仍在运行，不关闭窗口，先保留现场并反馈最后几行；若出现 `NAS_UNMOUNT_FAILED`、`NAS_MOUNT_LEFT_ACTIVE` 或缺少末尾完成标记，不要重跑、删除暂存目录或启动恢复。转存成功后仍须从 NAS 副本恢复到另一套新卷，才能验收 NAS 来源恢复。

**用户现场结果（2026-10-16）：**上述源校验、固定 NAS 挂载、六个文件复制校验、完成状态、临时挂载清理与最终成功标记全部出现；NAS 副本目录为 `fictional-backup-NX5wqA1m-dab1c5b855e1`。记录为**用户现场的虚构配对备份整组 NAS 转存技术测试通过**。尚未验证从这份 NAS 副本恢复、自动备份、版本保留或正式资料安全。

### 第十步：从 NAS 副本只读导入到 Ubuntu 新私有目录（用户现场技术测试通过）

`scripts/import_fictional_nas_backup.py` 只挂载 `10.0.30.6:/teacher-workbench-backup`，选项含 `ro,resvport,nosuid,nodev,noexec`。它只寻找第九步输出的 `fictional-backup-NX5wqA1m-dab1c5b855e1`，检查完成状态、文件所有者和权限、NAS 清单和原数据库/私有文件校验清单，随后复制到 Ubuntu **新建**的 `/home/huahua/teacher-workbench-nas-import-dab1c5b855e1`。本机目录与文件分别限制为 `700`/`600`；NAS 源只读，不覆盖既有本机备份或测试卷。导入后卸载临时挂载。失败时新建的隐藏暂存目录可能保留用于排查，不自动删除。完整导入前不能执行下一步恢复。

**本机检查（2026-10-16）：**Python AST、非目标主机拒绝、错误 NFS 来源拒绝、危险校验清单条目拒绝通过；SHA-256 为 `3FC20D5CCBDBC24A5B20EDA6D3803E720C7352A001E33CDC565C546B0B8886FA`。Ubuntu 尚未运行，导入与恢复都未验证。

**操作位置 1：用户电脑 Windows PowerShell。**执行以下三行，将导入和恢复脚本一并上传到已知 Ubuntu 257，随后 SSH 登录。只连接 `huahua@10.0.30.5`；密码仅在自己的终端输入。若 SSH 主机指纹变化，停止。

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\scripts\import_fictional_nas_backup.py .\scripts\restore_ubuntu_nas_test_backup.sh huahua@10.0.30.5:/home/huahua/
ssh huahua@10.0.30.5
```

**操作位置 2：SSH 登录后的 Ubuntu 终端。**核对两个文件的完整 SHA-256；第二个预期哈希见第十一步。**仅当两个哈希均一致时**执行导入。`sudo` 密码只在该终端输入，不发送备份文件、校验清单或 `.env` 到聊天。

```bash
sha256sum /home/huahua/import_fictional_nas_backup.py /home/huahua/restore_ubuntu_nas_test_backup.sh
sudo python3 /home/huahua/import_fictional_nas_backup.py
```

**导入成功标准：**`NAS_SOURCE_BACKUP_VERIFIED`、八个 `NAS_IMPORT_FILE_VERIFIED=...`、`NAS_LOCAL_IMPORT_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_LOCAL_IMPORT_DIR=/home/huahua/teacher-workbench-nas-import-dab1c5b855e1`、`NAS_IMPORT_DONE`。若少了末尾两项、出现卸载失败，**不要运行恢复脚本**；保留终端并反馈末尾输出。成功后可以按下一步在新卷演练恢复；导入本身尚不证明应用可恢复。

**用户现场结果（2026-10-16）：**用户提供上述源校验、八个导入文件校验、本机导入完成与 `NAS_MOUNT_CLEANED`；实际导入目录与预定路径一致。记为指定虚构 NAS 副本只读导入技术测试通过；助手未直接访问服务器。

### 第十一步：从 NAS 导入副本恢复到新 Docker 卷（用户现场技术测试通过）

`scripts/restore_ubuntu_nas_test_backup.sh` 仅使用第十步的新私有目录作为数据库和私有文件来源；先复核两个完成状态、NAS 与原备份校验清单、匹配的测试代码包以及归档路径安全。它沿用已通过的本机独立恢复验证逻辑，但使用另一组**全新**网络、数据库卷和私有文件卷，临时网页仅绑定 `127.0.0.1:18002`。核对虚构资料、两版草稿、双 Word 和跨账号拒绝，最后停止新容器、保留新卷并复核源测试页仍可用。它不删除旧卷、不覆盖先前的 `18001` 恢复环境，不接入内网穿透或正式环境。虚构测试账号密码不可用，真实密码/密钥恢复仍待单独验收。

**本机检查（2026-10-16）：**Git Bash `bash -n` 通过；文件为 LF 换行；静态核对固定读取 NAS 导入目录、使用独立前缀与 `18002`，没有 `docker compose down -v`、删卷或删源备份。SHA-256 为 `91648ED60446E135647B9F7DF29BDBED6EACAF4F5F2362E52C128AD705EB8B63`。Ubuntu 尚未执行。

**操作位置：**仅在第十步出现 `NAS_IMPORT_DONE` 后，在同一个 Ubuntu SSH 终端运行以下一行；命令会创建新的 Docker 测试卷和临时回环网页，成功后停止新 Web/DB 容器并保留卷。若第十步失败或哈希不符，不运行。

```bash
bash /home/huahua/restore_ubuntu_nas_test_backup.sh
```

**恢复成功标准：**出现 `NAS_IMPORTED_BACKUP_VERIFIED`、`RESTORE_ISOLATION_PREFLIGHT_OK`、`RESTORE_POSTGRES_READY`、`RESTORE_PRIVATE_READY`、`RESTORE_FIXTURE_AND_ACCESS_OK`、`RESTORE_LOGIN_HTTP_200`、`SOURCE_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 与最终的 `NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。只反馈这些标记和 `RESTORE_TEST_DIR=...`，不发送任何密码或备份内容。若缺少最终标记、容器未停止或原测试页不可用，不要重跑或删除卷；反馈最后输出以便定位。即使通过，这仍是虚构资料在测试栈的技术恢复，不等于正式环境、NAS 自动周期或真实账号验收通过。

**用户现场结果（2026-10-16）：**用户提供上述恢复成功标记，且有 `RESTORE_EMPTY_DATABASE_READY`、`RESTORE_TEST_ENV_READY`；新目录 `/home/huahua/teacher-workbench-nas-restore-dab1c5b855e1`。三条 `Not Found` 是隔离校验时预期的跨账号 404；原测试页 HTTP 200，新增容器已停、卷保留。记为虚构 NAS 副本来源独立恢复技术测试通过；未核对真实账号、密钥、自动备份或正式环境。

## 真实 AI 本机试用与故障排查（单次接口探测已成功）

**当前顺序：** ChatGPT 会员接入需等待私有应用资格，[核对记录](chatgpt-plan-assessment.md)详述。2026-10-16 用户在本机运行千问单次虚构资料测试，得到“接口返回结构有效：4 道题”；证明该 Key、北京地域 OpenAI 兼容地址与 `qwen-flash` 的一次请求已经连通。数学正确性、实际账单、页面全流程和其他资料尚未验证。

**用户现场结果：** 千问免费额度已用完，用户同意改用充值后的 API。2026-10-16 用户截图显示：华北 2（北京）、2026.10、某个 API Key 的月度预算 ¥30.00、达预算后停止“是”、告警阈值 80%；截图未显示完整 Key，不能确认余额、模型权限、真实接口连接或调用账单。未在文档记录 Key 名称或任何片段。先选千问 `qwen-flash`，不自动换 DeepSeek。

1. **用户在自己的电脑浏览器中操作阿里云百炼控制台**：截图已显示一把北京地域 Key 的 ¥30 月度预算与达额停用；后续须使用**同一把 Key**。预算截图不证明 Key 已充值或可以调用。若需要变更，在[密钥管理](https://help.aliyun.com/zh/model-studio/get-api-key/)核对 Key，在“费用用量 → 预算管理”核对该 Key 的预算；独立 Key 并非必需。[预算管理说明](https://help.aliyun.com/zh/model-studio/budget-management)指出停用可能延迟，因此预算不是绝对的实时费用上限。充值金额由用户决定；助手不代购、充值或输入支付信息。不要在聊天里发送 API Key、控制台完整截图中的账号信息或支付信息。
   - “独立 Key”指在现有阿里云账号里**新建一把专供本项目使用的 Key**；本阶段不需要新注册阿里云账号。若创建弹窗提供“自定义权限 → 访问模型范围”，可只选 `qwen-flash`。创建后可在列表中识别这把 Key，并在预算管理中选它作为预算对象。该权限和预算是否已生效，必须以用户控制台实际显示为准。
2. **用户在自己的 Windows PowerShell 中操作，单次接口探测已成功**：进入 `D:\Projects\teacher-workbench`，运行 `$env:DJANGO_DEBUG='1'`，然后运行 `& .\.venv\Scripts\python.exe manage.py test_ai_provider --prompt-qwen-key --confirm-paid-call`。命令先以**可见输入**接收该 Key 对应的 OpenAI 兼容 Base URL，再以**隐藏输入**接收同一把 Key；两者均不写入文件或 PowerShell 命令历史。2026-10-16 用户截图中的正确位置是“按量付费 Base URL”下**左侧 OpenAI 图标旁的地址**，点击该地址最右侧复制按钮，粘贴完整 URL；**右侧 A 图标旁是 Anthropic 地址，不适用此命令**。用户随后提供的左侧地址已在本机离线校验通过。用户接着反馈 Key 隐藏输入收到空白／控制字符错误，命令在发请求前退出；旧版 Windows `getpass` 逐键读取可能无法正确处理 `Ctrl+V`。现已改用 Windows 控制台整行读取并关闭回显，虚构字符串的交互测试显示内容完整且终端不回显；**用户已验证一次真实接口请求返回 4 道结构有效的题目**。项目文档不记录具体业务空间 ID、Key 片段或账号。Base URL 如不填写则使用北京通用地址 `https://dashscope.aliyuncs.com/compatible-mode/v1`；新建 Key 应优先使用百炼创建时显示的地址，官方[Key 文档](https://help.aliyun.com/zh/model-studio/get-api-key/)说明它与 Key 一起提供，业务空间专属地址形如 `https://实际业务空间ID.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`。非法地址会在读取 Key 前被拒绝。输入后才对 `qwen-flash` 发送一次固定虚构数学资料请求，可能产生费用。Key 仅在该 Python 进程内使用，命令退出即不再保存在该进程中。不带 `--confirm-paid-call` 时输入模式会在读取 URL 或 Key 前退出。成功输出“接口返回结构有效：N 道题”；失败仅输出 HTTP 状态及固定类别，或网络／JSON 类别，不打印 Key、供应商正文或资料全文。若 Key 输入包含粘贴控制字符，命令会在发请求前拒绝。请勿把 Key 粘贴进聊天或 PowerShell 命令文本。
3. **本机逐任务路径（用户已完成两次虚构资料任务）**：在项目目录的 Windows PowerShell 设置 `$env:DJANGO_DEBUG='1'` 和 `$env:AI_LOCAL_QUEUE='1'`，运行 `& .\.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000 --noreload`。本机页面可在**不保存 Key** 的情况下上传和排队；点击“生成作业”只创建任务，不调用模型。用户已对虚构资料执行生成任务 1 和修改任务 2，保存两版 Word，并在 WPS 检查第 2 版三题、根式及打印预览。以后如需处理新任务，先运行 `& .\.venv\Scripts\python.exe manage.py run_local_task 任务编号 --prompt-qwen-key` 做不发请求的资料编号预检；核对无误后，用户才可显式运行 `& .\.venv\Scripts\python.exe manage.py run_local_task 任务编号 --prompt-qwen-key --confirm-paid-call --confirm-material-id 资料编号`，按提示临时输入 Base URL 和隐藏 Key。每次可能产生费用，不自动重试或切换厂商。Docker/Ubuntu 测试栈强制关闭 AI，不使用此本机选项；厂商账单按用户要求暂缓核对。
4. **教师验收**：在浏览器查看生成和修改后的题目、答案、来源及版本；下载学生卷和教师版，在 WPS 检查公式可编辑、答案对应和打印预览。真实输出需人工审核。步骤与结果补记 [acceptance.md](acceptance.md)。

当前适配器期待 Chat Completions 的纯文本 JSON；用户单次虚构资料请求返回了 4 道结构有效的题目，但 `qwen-flash` 对实际数学作业的正确性与实际账单仍待验证。ChatGPT Plus 的官方计划接入与当前 API Key 适配器不同，不能把订阅直接填入 `.env`。

**2026-10-16 故障记录：** 用户按原命令实际输入 Key 并触发一次请求，得到“模型调用或结果解析失败”；旧代码隐藏了 HTTP 状态、网络错误与结果格式差异，故不能判定是 Key、地址、余额还是返回格式造成。没有成功生成题目，也没有核对实际账单。已改为只显示安全错误类别，并允许安全输入 Key 对应的 API Host；修改后 29 项自动测试通过。下一次请求必须由用户在预算范围内主动运行，助手不能从旧报错推断已解决。

**2026-10-16 成功记录：** 用户在控制台整行隐藏输入 Key 后，单次虚构资料请求返回结构有效的 4 道题。先前地址与隐藏粘贴问题已绕过；本轮没有由助手追加真实请求。真实输出未展示给助手，未核对数学答案或费用。随后代码增加不落盘 Key 的逐任务执行路径，并在不配置 Key 的本机排队模式下通过自动测试。

**2026-10-16 逐任务预检记录：** 用户已在页面排队任务 1。助手执行无 `--confirm-paid-call` 的只读预检：资料编号 2，提取文字 153 字；数据库检查为 queued，任务及资料所有者一致，上传文件哈希与现有虚构学生卷一致。没有读取 Key 或发送模型请求。此编号仅适用于本次本机测试数据库；下一步由用户在项目目录 Windows PowerShell 设置 `$env:DJANGO_DEBUG='1'`、`$env:AI_LOCAL_QUEUE='1'`，再运行 `& .\.venv\Scripts\python.exe manage.py run_local_task 1 --prompt-qwen-key --confirm-paid-call --confirm-material-id 2`，按提示输入 Base URL 和 Key。该操作会把虚构资料文字发送到千问并可能产生费用；用户须在自己的终端主动执行。不要把 Key 发到聊天中。

**2026-10-16 逐任务执行结果：** 用户已按上条命令执行任务 1，反馈“该任务已完成”。本地状态 done、第 1 版草稿含 2 道 AI 题；费用未核对。实际输出含 `$...$` 数学写法，修复预览/Word 导出后，助手重新启动本机服务（只监听 `127.0.0.1:8000`，当时单一监听进程）；登录页 HTTP 200。用户需在 [作业 2 页面](http://127.0.0.1:8000/worksheets/2/)刷新并重新下载两份 Word，旧下载文件不会自动变更。只有用户在 WPS 实际检查编辑、答案及打印预览后才能记为教师验收通过。此操作没有再次调用模型。

**2026-10-16 导航改造后的本机服务：** 检查确认旧本机服务仍运行旧路由，`/create/` 返回 404；通过原有终端会话停止该服务，再以 `DJANGO_DEBUG=1`、`AI_LOCAL_QUEUE=1` 启动当前代码，仍仅监听 `127.0.0.1:8000`。新 `/create/`、`/worksheets/`、`/materials/` 对未登录请求返回登录跳转，34 项自动测试通过；用户浏览器的实际点击效果待复核。未连接 Ubuntu、未改正式环境。

**2026-10-16 修改草稿页面更新后的本机服务：** 已停止上一轮的本机开发会话，并用相同的 `DJANGO_DEBUG=1`、`AI_LOCAL_QUEUE=1` 参数重新启动；`127.0.0.1:8000/login/` 返回 HTTP 200，端口只有一个监听进程。只读检查实际作业 2 有第 1 版、创建任务为 done，没有修改任务；本轮没有输入 Key 或调用模型。页面上的“提交修改要求”在本机排队模式只建任务；实际发往千问仍须按照上文的逐任务编号预检与显式付费命令操作。

**2026-10-16 任务 2 预检记录：** 用户已通过页面排队一项修改任务。助手运行 `run_local_task 2 --prompt-qwen-key`，未提供 `--confirm-paid-call`；命令显示资料编号 2、提取文字 153 字并明确未发送模型请求。只读查询确认任务 2 状态 queued、类型 revise、作业和资料均为编号 2，与任务 1 同源且归属一致，作业仍只有第 1 版。预检后由用户在 Windows PowerShell 进入 `D:\Projects\teacher-workbench`，设置 `$env:DJANGO_DEBUG='1'`、`$env:AI_LOCAL_QUEUE='1'`，再执行 `& .\.venv\Scripts\python.exe manage.py run_local_task 2 --prompt-qwen-key --confirm-paid-call --confirm-material-id 2`；命令临时提示输入百炼 OpenAI 兼容 Base URL 和隐藏 Key，**发送资料与现有草稿到千问，可能产生费用**。预检时尚未付费执行；用户不得把 Key 发到聊天。

**2026-10-16 任务 2 执行与本机服务记录：** 用户已执行上条显式命令并反馈完成；本机数据库状态 done、第 2 版三题已保存。助手发现根式字面命令后修复预览与 Word 导出，没有再次调用模型。35 项自动测试通过；停止旧本机开发会话，以 `DJANGO_DEBUG=1`、`AI_LOCAL_QUEUE=1` 重新启动 `127.0.0.1:8000`，仅一个监听进程，登录页与 CSS 均 HTTP 200。先前下载的第 2 版 Word 是旧导出，应刷新 [作业 2 页面](http://127.0.0.1:8000/worksheets/2/)并重新下载。教师在 WPS 中检查根式、答案和版式，厂商控制台核对账单；两项均未收到验收结果。

## 启动（Docker/Ubuntu）

- **隔离测试栈：用户现场技术测试通过。**用户已在 Ubuntu 独立测试目录完成配置离线检查、Compose 预检和四服务启动；Web 仅绑定 `127.0.0.1:18000`，登录页与静态资源返回 HTTP 200，详细证据见前文及 [隔离测试计划](docker-test-plan.md)。正式环境的启动流程尚未建立。

## 停止

- **待验证，尚无命令。** 明确停止的是测试还是真实服务、对使用者的影响及成功标准。

## 查看日志

- **待验证，尚无命令。** 记录查看位置、如何筛除 Key、个人信息和教学资料，再给出错误判定方法。

## 备份

- **隔离测试卷：用户现场技术测试通过。**已执行的脚本、标记与目录见上文“测试卷配对备份”及 NAS 第九至十一步。覆盖 PostgreSQL 一致性导出和同一时点的私有文件卷，并有一份虚构数据专用 NAS 副本；每日自动备份、多版本保留与正式环境密钥恢复途径仍未核实。业务数据与 Git 代码版本是不同记录。

## 恢复

- **隔离测试卷：用户现场技术测试通过。**本机备份及 NAS 副本来源的独立新卷恢复、虚构资料/两版历史/双 Word/跨账号拒绝与回环登录页响应见上文；原测试卷未覆盖。虚构账号不可登录，因此真实账号密码、旧会话和原密钥恢复尚未验证；正式环境未部署。

## 升级与回退

- **待验证，尚无已执行命令。** 新版先通过测试并由用户确认，再停写、同时备份数据库与私有文件、恢复演练、升级和检查。涉及数据库迁移时使用匹配的代码与数据库备份回退；代码回退不等于数据回退。不得用 `docker compose down -v` 作为普通停止或回退手段。

## 操作记录格式

每次实际操作补记：日期、环境、操作者、命令或界面动作、执行结果、成功证据、失败处理。用户新提供的服务器结果同步写入 [environment.md](environment.md)。

## 独立预发布测试栈（2026-10-17 用户已完成启动与技术探针）

**用途与隔离：**只用虚构数据，在 Ubuntu 257 的新目录与独立 PostgreSQL、Redis、私有文件及静态文件卷中核对新版登录限速。新栈只绑定服务器 `127.0.0.1:18002`，AI 强制关闭；现有 `teacher-workbench-test` 的 `127.0.0.1:18000` 和卷不作更改。这里是回环 HTTP 测试环境，不能作为正式站、PWA 或面向 EasyTier 全网卡开放。正式配置仍见 [production-readiness.md](production-readiness.md)。

**本地准备已通过：**离线包 `data/deploy/teacher-workbench-staging.tar.gz` 含 77 个允许的代码、示例配置和 Linux wheel 文件，SHA-256 `74586f82a15b88ad55d8466d66351beb335c8d147b35cc2cb139dad74fe9492e`。包不含 `.env`、教学资料、数据库或 Git；脚本源文件哈希随代码改动需重新核对。下列第 1～3 步已由用户执行，现场结果见本节末尾；保留命令供后续排查，**不要重复创建同名目录**。

**第 1 步，Windows PowerShell，复制两个文件：**先保持 EasyTier 可连接 Ubuntu；在 `D:\Projects\teacher-workbench` 打开 PowerShell，运行：

```powershell
scp .\data\deploy\teacher-workbench-staging.tar.gz huahua@10.0.30.5:teacher-workbench-staging-74586f82.tar.gz
scp .\scripts\prepare_ubuntu_staging.sh huahua@10.0.30.5:prepare_ubuntu_staging_74586f82.sh
```

预期两次复制完成，不要求打开压缩包或发送密码。使用此前已核对的 Ubuntu SSH 主机密钥；若主机指纹变化，先停止操作。

**第 2 步，仍在 Windows PowerShell，Ubuntu 只准备目录与随机配置：**

```powershell
ssh -t huahua@10.0.30.5 'bash ~/prepare_ubuntu_staging_74586f82.sh ~/teacher-workbench-staging-74586f82.tar.gz 74586f82a15b88ad55d8466d66351beb335c8d147b35cc2cb139dad74fe9492e'
```

脚本会检查主机/用户、压缩包哈希、原测试页、端口、同名 Docker 项目、内存和磁盘，再新建权限为 `700` 的独立目录和权限为 `600` 的随机 `.env.staging`，运行 Compose 离线解析。预期显示 `STAGING_PREFLIGHT_OK`、`STAGING_DIR=/home/huahua/teacher-workbench-staging-74586f82`、`NO_CONTAINERS_STARTED`。若报错，**不要重跑或手动删除目录**，只反馈错误标记；原测试站应保持可用。此步需要用户在本机输入 SSH、必要时 sudo 密码；不要把密码或 `.env.staging` 内容发给助手。

**第 3 步，仅第 2 步通过后，在 Windows PowerShell 启动并核对：**

```powershell
ssh -t huahua@10.0.30.5 'cd ~/teacher-workbench-staging-74586f82 && bash scripts/start_ubuntu_staging.sh'
```

脚本只对 `teacher-workbench-staging` 项目执行 `up -d --build`，等待新登录页，再以随机不存在的虚构用户名交替向普通和管理登录入口提交 8 次错误密码；第 9 次预期 HTTP 429，以此核对两个入口共享 Redis 计数。它还核对 Nginx 提供 CSS/JS 和旧测试站登录页仍 HTTP 200。成功标记为 `STAGING_STATIC_CSS_JS_HTTP_200`、`STAGING_SHARED_LOGIN_THROTTLE_HTTP_429`、`STAGING_HTTP_TECHNICAL_VERIFICATION_OK`。失败时脚本停止新栈容器、**保留新卷供排查**，不删除或更改旧测试栈。若镜像下载或构建失败，不要自行改网络/Compose；反馈错误标记和非敏感末尾日志。此步不创建真实账号、不给模型发请求，也不打开正式服务。

**后续浏览器验收（第 3 步成功后）：**保持 SSH 隧道 `ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5` 打开，在同一 Windows 电脑浏览器访问 `http://127.0.0.1:18002/login/`。这是新栈的空数据库，旧测试账号不会自动复制过来；先不要用真实账号。账号准备和用户页面验收需另行记录；命令成功本身不能代替用户验收。

**用户现场结果（2026-10-17）：**终端返回 `STAGING_HTTP_TECHNICAL_VERIFICATION_OK` 与 `SOURCE_TEST_LOGIN_STILL_HTTP_200`；用户开启上述 SSH 隧道后反馈网页端正常显示。按脚本条件，新栈 HTTP 登录限速与静态资源技术探针通过，旧站登录页仍可用；浏览器验收仅覆盖新登录页。新栈账号登录及上传下载还未检查。`Connection to 10.0.30.5 closed.` 表示本次 SSH 命令结束，不是应用故障。

**助手本机补充核对：**通过用户保持的 `18002` 隧道，助手以只读 GET 核对登录页、CSS、JS 均 HTTP 200 且文件类型符合预期。没有登录账号，也没有取得服务器可复用 SSH 会话。

### 新栈虚构普通账号与浏览器验收（2026-10-17 账号已建立，浏览器待验）

**目标：**只在新的预发布数据库创建一个非管理员测试账号，验证成功登录与虚构资料上传下载。旧测试账号位于另一数据库，不需要迁移或重建旧站。账号密码只在用户的 Ubuntu 终端无回显输入，不传给助手，不与 SSH/NAS/厂商密码复用。已有同名账号时脚本拒绝覆盖。

**执行位置：**保持当前 `ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 ...` 的 PowerShell 窗口开着；另开一个 Windows PowerShell，在项目目录运行以下三条命令：

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\scripts\prepare_ubuntu_staging_browser_user.py .\scripts\prepare_ubuntu_staging_browser_user.sh huahua@10.0.30.5:
ssh -t huahua@10.0.30.5 'bash ~/prepare_ubuntu_staging_browser_user.sh'
```

脚本先核对 Ubuntu 主机/用户、预发布目录和 helper 哈希、Compose 项目与回环端口、四项运行服务，再在独立数据库中创建 `staging_preview_20261017`。预期先看到两次测试密码输入提示（输入不显示），然后看到 `STAGING_BROWSER_ACCOUNT_READY username=staging_preview_20261017 staff=False; password hidden` 和 `STAGING_AND_SOURCE_LOGIN_HTTP_200`。若出现错误标记，请停下并只反馈标记，勿重跑、勿发送密码；原测试站不受此脚本修改。

**浏览器验收：**保持隧道窗口运行，访问 `http://127.0.0.1:18002/login/`，用新账号和刚才设定的测试密码登录。预期进入首页；在“课件与资料”上传项目内虚构文件 `D:\Projects\teacher-workbench\data\preview-exports\离线排版样例-学生卷.docx`，预期出现在“我的资料”，下载后 Word 能打开。只反馈首页是否进入、资料是否出现、下载能否打开；不发送密码或文件。此过程不触发模型（新栈 `AI_ENABLED=0`），也不替代真实资料、HTTPS/PWA 或正式发布验收。

**用户现场结果（2026-10-17）：**账号创建命令返回 `STAGING_BROWSER_ACCOUNT_READY username=staging_preview_20261017 staff=False; password hidden` 和 `STAGING_AND_SOURCE_LOGIN_HTTP_200`；**不要重跑建号脚本**。随后浏览器显示 `127.0.0.1:18002` 的 `ERR_CONNECTION_REFUSED`。助手在同一 Windows 电脑只读检查该端口无监听、HTTP GET 不可达，说明当前没有可用本地转发；此前在隧道开启时，新站登录页/CSS/JS 均返回过 HTTP 200。账号登录仍待验。

**恢复浏览器连接（已执行；今后再次访问可沿用）：**在 Windows **另开一个 PowerShell 窗口**运行下方命令，输入 Ubuntu `huahua` 的 SSH 密码；命令成功后窗口会停在光标处，**保持这个窗口打开**。然后在浏览器重新访问 `http://127.0.0.1:18002/login/`，使用已创建的新测试账号登录。这里的 `127.0.0.1` 指 Windows 电脑，关闭隧道窗口后浏览器会再次拒绝连接。若 SSH 命令直接返回错误，仅反馈不含密码的错误信息；不要修改服务端监听、重建账号或重复上传资料。

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5
```

### 预发布登录 CSRF 403 修复（2026-10-17；现有浏览器链路已复核）

**现场问题与证据：**隧道恢复后，用户在 `http://127.0.0.1:18002/login/` 登录得到 403，页面明确写着 Origin 带 `:18002` 不匹配。助手用虚构用户名和有效 CSRF 令牌重复一次 POST，也得到 Origin mismatch 403；GET 页面仍 200。预发布 Nginx 原来以 `$host` 向 Django 传 Host，导致浏览器端口丢失。已在本地把[预发布网关配置](../config/nginx-staging.conf)改为 `$http_host`，保留浏览器 Host 与端口。**此改动尚未进入 Ubuntu，当前账号登录不能算通过。**

**范围：**只修改 `/home/huahua/teacher-workbench-staging-74586f82/config/nginx-staging.conf` 的 Host 转发并热重载 `teacher-workbench-staging` 网关；脚本先核对原配置和新配置哈希、四服务及 `127.0.0.1:18002` 绑定，保存原配置副本。然后在服务器回环用随机不存在的虚构账号发一次带 Origin 的错误登录 POST，预期到达登录表单并返回 HTTP 200，旧 `18000` 和新 `18002` 登录页仍 200。若配置或探针失败，脚本尝试恢复旧配置并重载；**不重新构建镜像、不迁移数据库、不删除卷、不重建账号**。旧离线压缩包仍含原配置，不要重新解压覆盖运行目录。

**操作位置：**保持原 SSH 隧道可用；另开 Windows PowerShell，在项目目录执行：

```powershell
Set-Location D:\Projects\teacher-workbench
scp .\config\nginx-staging.conf huahua@10.0.30.5:nginx-staging-csrf-569890e8.conf
scp .\scripts\apply_ubuntu_staging_csrf_fix.sh huahua@10.0.30.5:apply_ubuntu_staging_csrf_fix.sh
ssh -t huahua@10.0.30.5 'bash ~/apply_ubuntu_staging_csrf_fix.sh'
```

预期看到 `nginx -t` 成功、`STAGING_CSRF_ORIGIN_POST_REACHED_LOGIN_HTTP_200`、`STAGING_AND_SOURCE_LOGIN_HTTP_200_AFTER_CSRF_FIX`、`STAGING_CSRF_GATEWAY_RELOAD_VERIFIED`。若看到 `STAGING_CSRF_FIX_FAILED_OLD_GATEWAY_RESTORED`、`STAGING_CSRF_FIX_ROLLBACK_FAILED_REVIEW_REQUIRED` 或其他错误标记，请先停止，只反馈不含密码的标记。成功后回到浏览器，刷新登录页，再用已创建的测试账号登录；**不要重新建号**。帐号登录、资料上传及下载仍需用户实际核对。

**后续结果（2026-10-17）：**上段是故障当时的操作说明。用户随后提供新站成功登录首页及资料上传入列的截图，并明确确认虚构 DOCX 上传下载正常。助手经现有 Windows SSH 隧道发起一次全新虚构错误登录，带有效 CSRF 令牌及浏览器 Origin/Referer；GET 与 POST 均 HTTP 200，POST 显示错误密码提示，因此此前的 CSRF 403 已消除。用户没有提供 `STAGING_CSRF_GATEWAY_RELOAD_VERIFIED` 等脚本终端输出，**不能据此追认 `nginx -t`、回滚准备和旧站探针的本次执行结果**；旧站可用性仍以此前现场标记为证。今后继续访问新站需保持 `18002` SSH 隧道打开，关闭后 `127.0.0.1:18002` 拒绝连接是预期现象。不要重跑建号或热重载脚本来补收标记。

### 预发布虚构资料的配对备份与独立恢复（2026-10-17 两步现场通过）

**范围：**仅针对 `teacher-workbench-staging-74586f82` 的虚构普通账号与 `离线排版样例-学生卷.docx`。备份脚本先核对库中恰好只有该普通账号和这份文件，文件 SHA-256 匹配本项目虚构样例，没有作业或模型任务；不符即停止，避免把后来加入的真实资料误作虚构数据处理。源站备份时会短暂停止新栈 Web 和网关，把 PostgreSQL 导出与私有文件归档为一组，随后启动并检查新站登录页。旧 `18000` 不改动。备份只放 Ubuntu 私有目录，**暂不转存 NAS**，不含 `.env.staging` 或明文测试密码；数据库导出包含测试账号的密码哈希，备份仍须作为私有数据保护。恢复脚本使用全新的数据库、私有文件卷和随机测试配置，不覆盖源站；恢复验证仅使用虚构数据、所有者下载和其他账号 404，之后停止恢复容器并保留新卷。没有正式数据或付费 AI 调用。

**本机检查已通过：**两个 Bash 脚本 `bash -n`、Python 语法、虚构样例 SHA-256 匹配、LF 行尾与不含删卷命令检查通过；在 Windows 错误主机运行备份脚本按预期输出 `WRONG_HOST_OR_USER`，没有进入服务器操作。独立恢复的 Docker 运行仍未执行。

**第一步，用户在 Windows PowerShell 的项目目录 `D:\Projects\teacher-workbench` 执行：**

```powershell
scp .\scripts\verify_staging_fictional_snapshot.py .\scripts\backup_ubuntu_staging_fictional.sh huahua@10.0.30.5:
ssh -t huahua@10.0.30.5 'bash ~/backup_ubuntu_staging_fictional.sh'
```

输入 SSH 和必要时 sudo 密码即可，**不要将密码发给助手**。终端预期依次出现 `STAGING_FICTIONAL_SOURCE_VERIFIED`、`STAGING_POSTGRES_PREFLIGHT_OK`、`STAGING_PRIVATE_PREFLIGHT_OK`、`STAGING_APPLICATION_WRITES_STOPPED`、`STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`、`STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_BACKUP_FILES_VERIFIED` 和 `STAGING_BACKUP_DIR=...`。停 Web/网关时预发布页面可能短暂不可用；脚本失败会尝试重启，不删除卷。若停在 `STAGING_POSTGRES_DUMP_START` 数分钟或报错，**不要关窗口、不要重跑**，先反馈最后的非敏感标记和新站是否仍能打开；不要发送备份文件、账号密码或资料。

**第一步现场结果（用户提供的 2026-10-17 终端输出）：**依次返回 `STAGING_FICTIONAL_SOURCE_VERIFIED`、PostgreSQL 与私有文件预检成功、Web/网关停止、数据库与文件归档就绪、四服务重新启动、新站登录页 HTTP 200、`STAGING_BACKUP_FILES_VERIFIED`。备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-cxi7XtWw`。这些标记表示**用户现场技术测试通过**；助手没有直接读取服务器备份文件，也未验证恢复。不要重跑这份备份以补输出。

**第二步，已于 2026-10-17 现场执行；以下命令只留作操作记录，不要重跑：**已将第一步返回的实际备份目录写入下方命令。执行位置为 Windows PowerShell 的项目目录：

```powershell
scp .\scripts\restore_ubuntu_staging_fictional.sh huahua@10.0.30.5:
ssh -t huahua@10.0.30.5 'bash ~/restore_ubuntu_staging_fictional.sh /home/huahua/teacher-workbench-staging-backups/backup-cxi7XtWw'
```

预期出现 `STAGING_RESTORE_ISOLATION_PREFLIGHT_OK`、`STAGING_RESTORE_POSTGRES_READY`、`STAGING_RESTORE_PRIVATE_READY`、`STAGING_RESTORE_FIXTURE_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_INDEPENDENT_RESTORE_VERIFIED`。若任何标记缺失，只反馈最后错误标记；**不要重跑或清理新卷**。这一恢复演练仍不证明 NAS 来源恢复、每日自动备份、真实账号密码/密钥恢复或正式发布可用。

**第二步现场结果（用户提供的 2026-10-17 终端输出）：**依次返回隔离预检、随机恢复配置、空数据库、PostgreSQL 与私有文件恢复成功标记，以及 `STAGING_RESTORE_FIXTURE_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_INDEPENDENT_RESTORE_VERIFIED`。恢复目录为 `/home/huahua/teacher-workbench-staging-restore-20261017`。输出中的 `Not Found: /materials/1/download/` 是独立恢复副本中另一个账号访问原所有者资料时预期的 404；后续完整成功标记说明该拒绝被脚本判定正确。恢复容器已停止、新卷保留；预发布和旧测试站登录页均在结束时返回 HTTP 200。此结果来自用户终端输出，助手没有取得服务器会话或下载备份。

### 预发布手动排队更新（2026-10-17 用户现场已部署）

**目的：**新站可从虚构资料页面点击“生成作业”，但点击只在独立 PostgreSQL 保存任务；模型和 Key 仍关闭。随后单独核对任务与资料，只有用户再次明确运行单任务命令才可能发送付费请求。本轮先更新预发布代码并验收“只排队、不调用”；**不运行付费命令**。旧 `18000` 测试站和正式环境不变。

**本机已验证：**新增手动排队设置、仅限虚构样例的逐任务命令；Django 45 项测试通过、3 项 PostgreSQL 专用跳过；配置闸门 4 项通过、迁移无变更、Django 检查通过。新离线包 78 个文件，SHA-256 `1d3ed18b66e8bd0f48db0f5115cd0da659e799929715d30dec865f97d4b028bb`，仅含代码、模板、配置示例和 18 个 Linux wheel，不含 `.env`、资料或数据库。本机 Bash 语法、错误主机拒绝和包清单检查通过。Ubuntu 技术结果见下；**浏览器实际排队尚未验证**。

**更新范围与回退：**脚本核对上一节已成功恢复的配对备份、旧站/预发布站回环登录页、四服务及虚构资料；在 `/home/huahua/teacher-workbench-staging-1d3ed18b` 解包新代码并复制服务器现有私有测试配置，不回显密钥。新镜像使用独立标签，旧镜像保留。只重建 `teacher-workbench-staging` 的 Web 和网关，沿用原独立数据库/文件卷；失败时尝试用原目录和旧镜像重建这两个容器。脚本不执行 `down -v`、删卷或修改旧测试栈。重建期间预发布网页会短暂不可用；用户已创建的虚构账号与资料应保留。脚本不生成任务、不调用模型。

**用户已在 Windows PowerShell 的项目目录执行（历史命令；无需重复）：**

```powershell
cd D:\Projects\teacher-workbench
scp .\data\deploy\teacher-workbench-staging.tar.gz huahua@10.0.30.5:teacher-workbench-staging-manual-queue-1d3ed18b.tar.gz
scp .\scripts\apply_ubuntu_staging_manual_queue.sh huahua@10.0.30.5:
ssh -t huahua@10.0.30.5 'bash ~/apply_ubuntu_staging_manual_queue.sh'
```

成功标记应包含 `STAGING_UPDATE_BACKUP_VERIFIED`、`STAGING_FICTIONAL_SOURCE_VERIFIED`、`STAGING_UPDATE_ISOLATION_PREFLIGHT_OK`、`STAGING_UPDATE_NEW_CONFIG_READY`、`STAGING_UPDATE_NEW_IMAGE_READY`、`STAGING_MANUAL_QUEUE_AI_OFF_VERIFIED`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_UPDATE`、最终 `STAGING_MANUAL_QUEUE_DEPLOYED_AI_OFF`。若失败，记录最后的非敏感错误标记及是否出现 `STAGING_UPDATE_FAILED_OLD_WEB_GATEWAY_RESTORED` 或 `STAGING_UPDATE_ROLLBACK_FAILED_REVIEW_REQUIRED`，不要重跑、删目录或卷。命令不会要求 API Key；**不要在这一步输入 Key 或点击生成**，待技术标记通过后再核对页面。

**用户现场结果（2026-10-17）：**返回 `STAGING_MANUAL_QUEUE_AI_OFF_VERIFIED`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_UPDATE`、`STAGING_MANUAL_QUEUE_DEPLOYED_AI_OFF`，新目录 `/home/huahua/teacher-workbench-staging-1d3ed18b`。按脚本顺序，AI 关闭、预发布数据库名、Django 检查和新旧站回环登录页已通过；助手未直连服务器。尚无浏览器点击排队或模型运行结果。

**下一步浏览器验收（待用户执行；只保存任务）：**在自己的 Windows PowerShell 开一个窗口运行下面命令，并保持窗口打开。若已经有同一端口的 SSH 隧道，可继续使用原窗口，不要再开第二条。

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5
```

在同一台电脑的浏览器打开 `http://127.0.0.1:18002/`，用已有虚构普通账号 `staging_preview_20261017` 登录。进入“出试卷”，选择已上传的虚构 `离线排版样例-学生卷.docx`，只点击一次“生成作业”。预期出现新任务及“排队中”状态；等约半分钟刷新后仍应是排队中，因为没有后台生成 worker。记录页面显示的任务编号与状态即可，**不要输入 API Key、不要重复点击或运行单任务命令**。若页面报错或任务自行完成，记录文字或截图，停止本项操作。此步骤只验收页面排队，不涉及真实教学资料或付费请求。

**用户页面结果（2026-10-17）：**截图可见“生成：排队中”与“任务 1 · 2026-10-17 11:32”，创建排队任务的页面步骤通过；未提供刷新后的画面。不要再次点击生成，否则会产生另一条测试任务。

**下一步只读任务预检（待用户执行；不会读取 Key 或发送模型请求）：**在自己的 Windows PowerShell 运行下列单条 SSH 命令。它在 Ubuntu 257 的独立预发布 Web 容器中检查任务 1 是否仍排队、账号及资料文件是否与虚构样例匹配，并只显示资料编号、文件名和提取字数。若命令要求 SSH 或 sudo 密码，只在自己的终端输入，不发给助手。

```powershell
ssh -t huahua@10.0.30.5 'cd ~/teacher-workbench-staging-1d3ed18b && sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T web python manage.py run_staging_task 1'
```

成功时应看到“待发送资料 <编号>：离线排版样例-学生卷.docx”和“任务仍在排队。未提供 --confirm-paid-call，没有读取 Key 或发送模型请求。”，请只反馈这两行或非敏感错误末尾。此命令没有付费确认参数，**不输入 API Key**；若显示任务不是待处理、账号或文件不匹配，则停止并反馈，不尝试换任务编号或修改数据。

**用户现场结果（2026-10-17）：**只读命令返回“待发送资料 1：离线排版样例-学生卷.docx（提取文字 153 字）”及“任务仍在排队。未提供 --confirm-paid-call，没有读取 Key 或发送模型请求。”资料编号已确认是预发布库的 `1`，不要与此前本机测试库的资料编号混用。命令守卫还核对虚构账号、任务归属与样例文件 SHA-256；没有新草稿或模型调用。

**一次性千问生成（2026-10-17 用户已执行；历史命令勿重跑）：**该命令仅处理上述任务 1 与资料 1，明确含 `--confirm-paid-call`。执行时 Key 只在交互终端临时输入，不放进命令、聊天、文件或 Git；`ssh -tt` 与不带 `-T` 的 Compose `exec` 保持容器内交互终端。

```powershell
ssh -tt huahua@10.0.30.5 'cd ~/teacher-workbench-staging-1d3ed18b && sudo docker compose --env-file .env.staging -f compose.staging.yaml exec web python manage.py run_staging_task 1 --confirm-paid-call --confirm-material-id 1 --prompt-qwen-key'
```

输入位置与预期：SSH/sudo 密码只在本机终端输入；出现“按量付费 Base URL”提示时粘贴此前测试通过的百炼北京地域左侧 OpenAI 兼容地址（这一行会显示）；出现“请输入百炼 API Key（输入不显示）”时才粘贴 Key，屏幕不应显示 Key。若 Key 出现在屏幕上，立即停止，不发送截图。命令会把**这份虚构资料的提取文字**发给千问 `qwen-flash`，可能产生费用；不会自动购买、充值或重试。成功标记为“该预发布任务已完成；请在页面核对内容及厂商账单。”若返回错误或停在处理中，只反馈不含 Key 的错误末尾，并先检查页面任务状态，**不要直接重跑**，以免重复付费。完成后在预发布浏览器刷新任务 1 页面，核对草稿、学生卷与教师答案版 Word；内容、公式、答案和 WPS 排版须另行验收。

**用户现场结果（2026-10-17）：**用户反馈“该预发布任务已完成”。按命令条件，任务状态已为 `done`，草稿版本已保存；没有得到页面内容、下载文件或账单核对结果。**不要再次运行上面的付费命令。**

**下一步页面与 WPS 验收（待用户执行）：**沿用已打开的 `18002` SSH 隧道；若已关闭，在 Windows PowerShell 重新执行本节前面的 `ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5` 并保持窗口打开。在浏览器进入 `http://127.0.0.1:18002/worksheets/`，用此前虚构普通账号登录，打开刚完成的作业并刷新。预期任务显示“生成：已完成”，下方有“草稿预览 · 第 1 版”；逐题展开参考答案。下载“学生卷 Word”和“教师答案版 Word”，分别用 Windows 的 WPS 打开。核对学生卷没有答案、教师版有对应答案、网页预览与两份 Word 的题目一致，检查公式能编辑、排版和打印预览。若有题目或答案错误，记下题号与问题；不要直接生成第二份或提交修改任务。此步只需反馈实际看到的结果，不要发送真实资料、Key 或密码。

**用户现场验收结果（2026-10-17）：**用户按上述步骤反馈“均正常”。记录为虚构任务 1 的页面、双 Word、WPS 公式编辑与打印预览通过；没有纸张实际打印、复杂题或账单核对结果。不要再次执行付费命令。

### 已生成草稿的预发布备份与独立恢复（2026-10-17 两步均现场通过）

旧 `backup_ubuntu_staging_fictional.sh` 和 `restore_ubuntu_staging_fictional.sh` 检查的是生成前“无作业”状态，**不能用于现在的任务 1**。本项目保留旧备份及旧脚本，另建立 `verify_staging_generated_snapshot.py`、`backup_ubuntu_staging_generated.sh` 和 `restore_ubuntu_staging_generated.sh`。新检查器只接受虚构普通账号、固定 DOCX 哈希、任务 1 为已完成且只有一版草稿；不打印题目正文。备份短暂停止预发布 Web/网关，成对保存 PostgreSQL 转储、私有文件和匹配代码包；失败时尝试重启网页并保留未完成目录。独立恢复只用全新卷和网络，不覆盖源数据库/文件卷；恢复副本核对本人下载、预览、双 Word 和跨账号 404。**本机已通过 Python 编译、默认环境拒绝、Bash 语法、错误主机拒绝和 LF/无清卷命令检查；Ubuntu 备份由用户现场输出验证，独立恢复待执行。**本机 WPS 另存的下载文件不在服务器快照内。

**第一步：仅制作新备份，用户已于 2026-10-17 执行；以下命令仅保留为历史记录，勿重跑。**先运行只读目标检查；预期输出 `GENERATED_HELPER_TARGETS_FREE`。若没有该标记或报目标已存在，停止并反馈，不覆盖服务器现有文件。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'for p in ~/verify_staging_generated_snapshot.py ~/backup_ubuntu_staging_generated.sh ~/restore_ubuntu_staging_generated.sh; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo GENERATED_HELPER_TARGETS_FREE'
```

目标空闲后上传三个新脚本并只运行备份。SSH/sudo 密码只在自己的终端输入；不发送密码、备份文件或 API Key。备份脚本会先核对当前预发布代码、唯一虚构草稿、文件哈希及四服务，再短暂停止预发布 Web/网关；旧 `18000` 测试站和正式环境不变。

```powershell
scp .\scripts\verify_staging_generated_snapshot.py .\scripts\backup_ubuntu_staging_generated.sh .\scripts\restore_ubuntu_staging_generated.sh huahua@10.0.30.5:
ssh -t huahua@10.0.30.5 'bash ~/backup_ubuntu_staging_generated.sh'
```

**第一步现场结果（用户提供的 2026-10-17 Ubuntu 终端输出）：**已出现 `STAGING_GENERATED_SOURCE_VERIFIED`、PostgreSQL/私有文件预检、停止 Web/网关、`STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`、四服务启动、`STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_GENERATED_BACKUP_FILES_VERIFIED`。备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-generated-wmPvKqmx`。这些标记按备份脚本表示配对备份及文件校验成功、预发布网页恢复；助手未直接连接 Ubuntu，也未从该新备份恢复。备份目录包含测试账号密码哈希和草稿内容，必须保持私有；不要重跑第一步。

**第二步：独立恢复演练，待用户在 Windows PowerShell 执行。**确认本地有 `restore_ubuntu_staging_generated.sh`，并使用已经上传到 Ubuntu 家目录的同名脚本。只传入上述真实备份目录；脚本先核对备份状态、各文件权限与哈希、当前源站镜像和隔离目标是否空闲，任何不符即停止。随后创建全新 Docker 网络、数据库卷和私有文件卷，使用随机测试配置且关闭 AI，恢复后核对虚构资料、任务 1 草稿预览、学生/教师双 Word、跨账号 404，并检查原预发布站及旧测试站登录页 HTTP 200。新恢复容器最终停止，**新卷保留，不覆盖源卷，不调用模型，也不写 NAS**。

```powershell
ssh -t huahua@10.0.30.5 'bash ~/restore_ubuntu_staging_generated.sh /home/huahua/teacher-workbench-staging-backups/backup-generated-wmPvKqmx'
```

SSH/sudo 密码只在用户自己的 Windows PowerShell 输入，不发给助手。预期最终看到 `STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_GENERATED_INDEPENDENT_RESTORE_VERIFIED` 与 `STAGING_GENERATED_RESTORE_DIR=...`。跨账号检查可能输出 `Not Found`，后续完整成功标记出现时才视为预期拒绝。若任何末尾标记缺失或报目标已存在，停止并反馈最后的非敏感输出，**不要重跑、删目录或清卷**。本步尚未现场执行；完成前不能宣称生成后的草稿可恢复。

**第二步现场结果（用户提供的 2026-10-17 Ubuntu 终端输出；上方命令勿重跑）：**返回隔离目标预检、随机测试配置、空库与私有文件恢复成功、`STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_GENERATED_INDEPENDENT_RESTORE_VERIFIED`。恢复目录为 `/home/huahua/teacher-workbench-staging-generated-restore-20261017`。三条 `Not Found` 是恢复副本中另一个账号访问原件、作业和教师卷时预期的 404。新增容器已停、新卷保留，源预发布和旧测试站登录页仍返回 HTTP 200。结果来自用户现场输出，助手未直接登录；当前新备份仍只在 Ubuntu 本机，尚未转存 NAS。

### 生成后虚构备份转存专用 NAS（2026-10-17 本地准备；现场待验）

已单独写好 `copy_staging_generated_backup_to_nas.py`、`import_staging_generated_nas_backup.py` 和 `restore_ubuntu_staging_generated_from_nas.sh`，均绑定本次 `backup-generated-wmPvKqmx` 虚构备份。它们不改旧测试栈脚本。转存仅从**已完成的本机备份**读取数据库、私有文件、哈希清单、匹配代码包和镜像标识，不读取运行中的 Docker 卷，不触发 AI；只向 `10.0.30.6:/teacher-workbench-backup` 建立一个新私有目录，逐文件校验后标记完成并卸载。源预发布站保持运行，NAS 上此前的备份保持原样。当前本机 Python 语法、错误主机拒绝、Bash 语法、LF 行尾及无清卷操作静态检查通过；**Ubuntu/NAS 转存、导入和来源恢复均未执行**。此恢复演练仍依赖 Ubuntu 现有的应用镜像和辅助检查器，不能证明整机灾难恢复。

**第一步（2026-10-17 用户已执行；以下命令仅留作历史记录，勿重跑）：**在 Windows PowerShell 中进入项目目录，先确认 Ubuntu 家目录没有这三个同名目标；成功应看到 `GENERATED_NAS_HELPER_TARGETS_FREE`。随后上传三个新脚本，并只运行转存脚本。SSH/sudo 密码只在自己的终端输入，不发送到聊天。

```powershell
cd D:\Projects\teacher-workbench
$preflight = ssh huahua@10.0.30.5 'for p in ~/copy_staging_generated_backup_to_nas.py ~/import_staging_generated_nas_backup.py ~/restore_ubuntu_staging_generated_from_nas.sh; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo GENERATED_NAS_HELPER_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $preflight -ne 'GENERATED_NAS_HELPER_TARGETS_FREE') { throw '服务器脚本目标已占用或预检失败，请停止并反馈' }
Write-Output $preflight
scp .\scripts\copy_staging_generated_backup_to_nas.py .\scripts\import_staging_generated_nas_backup.py .\scripts\restore_ubuntu_staging_generated_from_nas.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '脚本上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'sudo python3 ~/copy_staging_generated_backup_to_nas.py'
```

转存开始前应出现 `GENERATED_STAGING_SOURCE_BACKUP_VERIFIED`。完成时应看到 `NAS_GENERATED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_BACKUP_NAME=staging-generated-wmPvKqmx-<12 位小写十六进制>`、`NAS_GENERATED_STAGING_COPY_DONE`。只反馈非敏感标记和 NAS 目录名，不发送备份文件、题目或密码。若挂载、权限、校验或卸载失败，**不要重跑、不要删除暂存目录或已有备份**；保留最后的错误标记以便检查。取得实际 NAS 目录名后，再用只读导入及全新卷恢复核对，不提前宣称 NAS 来源可恢复。

**第一步现场结果（用户提供的 2026-10-17 Ubuntu 终端输出；上方转存命令勿重跑）：**出现 `GENERATED_STAGING_SOURCE_BACKUP_VERIFIED`、`DEDICATED_NAS_MOUNT_VERIFIED`、`NAS_STAGING_DIRECTORY_READY`、七个 `NAS_COPY_FILE_VERIFIED=...`、`NAS_GENERATED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_GENERATED_STAGING_COPY_DONE`。实际副本名为 `staging-generated-wmPvKqmx-0d63b4ce3f0e`。这表明转存、逐文件校验和临时挂载清理均由脚本完成；来源恢复尚未执行。助手没有直接登录 Ubuntu 或 NAS。

**第二步（待用户执行）：**在 Windows PowerShell 运行下列一条 SSH 命令。它先把上述**实际 NAS 副本**通过只读 NFS 挂载导入 Ubuntu 新的私有目录，并校验文件与状态；只有导入脚本成功退出时，`&&` 才会运行独立恢复。恢复使用新网络、数据库卷和私有文件卷，关闭 AI，不修改源预发布卷或 NAS 副本。SSH/sudo 密码只在自己的终端输入；**不发送备份文件、密码或题目内容**。

```powershell
ssh -t huahua@10.0.30.5 'sudo python3 ~/import_staging_generated_nas_backup.py staging-generated-wmPvKqmx-0d63b4ce3f0e && bash ~/restore_ubuntu_staging_generated_from_nas.sh /home/huahua/teacher-workbench-nas-import-staging-generated-wmPvKqmx-0d63b4ce3f0e'
```

成功应先出现 `NAS_GENERATED_STAGING_SOURCE_VERIFIED`、`NAS_LOCAL_IMPORT_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_GENERATED_STAGING_IMPORT_DONE`；然后出现 `STAGING_NAS_RESTORE_ISOLATION_PREFLIGHT_OK`、`STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_GENERATED_NAS_SOURCE_RESTORE_VERIFIED` 与新恢复目录。恢复检查中的三条 `Not Found` 是另一账号预期的 404，必须以最终成功标记为准。任何失败时保留末尾非敏感输出，**不要重跑、删除新目录或清卷**。这一步仍依赖 Ubuntu 上保留的应用镜像及检查器，不能代替整机灾难恢复或正式环境验收。

**第二步现场结果（用户提供的 2026-10-17 Ubuntu 输出；上方导入/恢复命令勿重跑）：**九个 `NAS_IMPORT_FILE_VERIFIED=...` 均出现，随后为 `NAS_LOCAL_IMPORT_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_GENERATED_STAGING_IMPORT_DONE`。只读导入目录为 `/home/huahua/teacher-workbench-nas-import-staging-generated-wmPvKqmx-0d63b4ce3f0e`。全新卷恢复接着返回隔离预检、数据库及私有文件就绪、`STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_GENERATED_NAS_SOURCE_RESTORE_VERIFIED`；恢复目录为 `/home/huahua/teacher-workbench-staging-generated-nas-restore-20261017`。三条 `Not Found` 是跨账号拒绝的预期 404。新容器已停、卷保留，源两站登录页仍 HTTP 200。助手未直接连接服务器；此演练仍使用 Ubuntu 现有应用镜像与检查器。

**下一项无付费页面验收（待用户执行）：**在 Windows PowerShell 保持或重新打开 `18002` 的 SSH 本地转发（命令见本节前文），在浏览器登录 `http://127.0.0.1:18002/worksheets/1/` 的虚构账号 `staging_preview_20261017`。确认第 1 版草稿仍可预览，向下找到“修改草稿”，在“希望怎样修改”输入一条不含真实教学资料的要求，例如“请把第 1 题的讲解改为两步，保留原题”，仅点击一次“提交修改要求”。预期页面提示“修改任务已排队”，任务进度显示“修改：排队中”，旧第 1 版仍可查看和下载。当前预发布手动队列只有管理员显式启动才会调用模型；本步骤不输入 Key、不会自动调用模型。请只反馈页面看到的任务编号与状态，不发送密码或题目内容。若页面没有修改表单或显示错误，保留原页状态并反馈，不重复点击。

**页面现场结果（用户 2026-10-17 截图；上段点击步骤勿重做）：**已显示“修改任务已排队。”和“修改：排队中”，任务编号 2，时间 22:37。第 1 版持续可见及排队状态刷新后的持久性未由截图单独覆盖。下一步只读核对任务 2，暂不输入 Key 或处理付费调用。

**任务 2 无付费只读预检（待用户执行）：**在 Windows PowerShell 运行下列命令。它通过 SSH 在 Ubuntu 257 的独立预发布 Web 容器中读取任务 2 的所属虚构资料和文件哈希；没有 `--confirm-paid-call`，命令会在核对后退出，不读取 Key、不调用模型。无需再次点击网页上的提交按钮，也不要重新运行任务 1。

```powershell
ssh -t huahua@10.0.30.5 'cd ~/teacher-workbench-staging-1d3ed18b && sudo docker compose --env-file .env.staging -f compose.staging.yaml exec -T web python manage.py run_staging_task 2'
```

成功标准是显示“待发送资料 1：离线排版样例-学生卷.docx（提取文字 153 字）”和“任务仍在排队。未提供 --confirm-paid-call，没有读取 Key 或发送模型请求。”。若任务不存在、资料不符或状态改变，命令会拒绝；请反馈非敏感错误文字，不要重试、输入 Key 或发送资料内容。此处没有授权处理任务 2 的付费调用；后续若要运行，须单独按命令的显式付费闸门处理。

**任务 2 只读预检现场结果（用户 2026-10-17 输出；上段命令勿重跑）：**资料编号 1、虚构 DOCX 名称、153 字及“任务仍在排队。未提供 --confirm-paid-call，没有读取 Key 或发送模型请求。”均出现。按命令守卫，归属和文件 SHA-256 已核对，尚无第 2 版或新模型调用。现有 NAS 副本是任务 2 排队前的恢复点。

**任务 2 一次性千问修改（待用户主动执行，可能产生费用）：**仅在 Windows PowerShell 中运行下面这条命令。它与已成功的任务 1 流程相同，但只针对已预检的**修改任务 2、资料 1**；包含显式付费确认参数，容器内会临时询问百炼 OpenAI 兼容 Base URL 和隐藏的 API Key。将虚构资料的提取文字、已有第 1 版草稿及用户填写的修改要求发送给千问 `qwen-flash`；不会读取其他教学文件或自动购买、充值。既有第 1 版不覆盖，新结果成功时保存为第 2 版。仅有排队前的旧 NAS 恢复点；新结果生成后需另备份。

```powershell
ssh -tt huahua@10.0.30.5 'cd ~/teacher-workbench-staging-1d3ed18b && sudo docker compose --env-file .env.staging -f compose.staging.yaml exec web python manage.py run_staging_task 2 --confirm-paid-call --confirm-material-id 1 --prompt-qwen-key'
```

SSH/sudo 密码只在用户自己的终端输入。出现“按量付费 Base URL”提示时粘贴此前测试通过的百炼页面**左侧 OpenAI 图标下的北京地域完整地址**；这一行会显示。出现“请输入百炼 API Key（输入不显示）”时才粘贴 Key，屏幕不应显示 Key；不要把 Key 发到聊天、文件或 Git。成功标记为“该预发布任务已完成；请在页面核对内容及厂商账单。”。如果命令失败或停在处理中，先保留非敏感错误末尾和页面状态，**不要直接重跑**，因为请求可能已发送并产生费用。成功后也不要再次运行任务 2；下一步在预发布浏览器核对第 1/2 版、题目答案与双 Word，再由用户在 WPS 验证公式、排版和打印预览。实际纸张打印与账单仍需分别核对。

**任务 2 现场结果（用户 2026-10-17 输出与截图；上方付费命令勿重跑）：**终端返回“该预发布任务已完成”，网页显示“修改：已完成”和“草稿预览 · 第 2 版”，学生卷与教师答案版下载入口可见。第 1 题答案把 `\n` 显示成文字；这是已发现的显示问题，不记为教师完成 WPS 验收。旧 NAS 备份只含第 1 版。

### 第 2 版数据保护与换行修复（备份、独立恢复及预发布技术部署已完成；页面待验）

**本机已完成：**两处渲染代码已改，虚构分步答案的网页换行、教师 Word 换行与数学公式检查通过，相关工作流 19 项回归通过；数据库草稿不改写、不再调用 AI。准备了只接受虚构资料、完成的任务 1/2 和第 1/2 版的只读检查器 `verify_staging_revised_snapshot.py`，配对备份 `backup_ubuntu_staging_revised.sh`、全新卷恢复 `restore_ubuntu_staging_revised.sh`，以及仅替换预发布 Web/网关的 `apply_ubuntu_staging_linebreak_fix.sh`。补丁包 `data/deploy/teacher-workbench-staging-linebreak-fix.tar.gz` 只含 `workbench/export.py` 与 `workbench/templatetags/worksheet_display.py`，SHA-256 为 `7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d`；不含教学资料、Key、数据库或 `.env`。本机 Python 编译、Bash 语法、错误主机拒绝、LF 换行、Django 迁移无变更及补丁成员核对通过；Ubuntu 的备份、恢复、容器构建和真实页面效果**尚未执行**。

**顺序：**先备份当前第 2 版，取得实际备份目录；再用该目录恢复到全新隔离卷并检查两版与账号隔离；最后才用同一备份作为闸门，把补丁包应用到独立预发布 Web。旧源目录、镜像、数据库和私有文件卷保留；更新失败会尝试重建旧 Web/网关。正式环境和旧测试站不更新。任何一步失败时保留现场，不删除目录或卷，不跳过恢复直接更新。

**第一步：上传检查器并备份第 2 版（待用户执行）。**在用户电脑的 **Windows PowerShell**，进入 `D:\Projects\teacher-workbench`。先核对 Ubuntu 家目录没有同名目标，再上传两个脚本，校验 SHA-256、检查 Bash 语法，最后在 Ubuntu 257 运行配对备份。运行时预发布 Web/网关会短暂停止并自动重启；旧测试站不受此脚本操作。SSH/sudo 密码仅在本机终端输入，不发到聊天。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'for p in ~/verify_staging_revised_snapshot.py ~/backup_ubuntu_staging_revised.sh; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo STAGING_REVISED_HELPER_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'STAGING_REVISED_HELPER_TARGETS_FREE') { throw '服务器目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\verify_staging_revised_snapshot.py .\scripts\backup_ubuntu_staging_revised.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "694036a7e5964915ba143450d03d5dc6ca26320ceebe548626310739a4c06dd1  verify_staging_revised_snapshot.py" | sha256sum -c - && echo "ed2e1c8313c999ff0b0ea4d4432f031c46250df788a6ce41efcdff1f7d191bfb  backup_ubuntu_staging_revised.sh" | sha256sum -c - && bash -n backup_ubuntu_staging_revised.sh && bash backup_ubuntu_staging_revised.sh'
```

成功应依次见 `STAGING_REVISED_SOURCE_VERIFIED`、`STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`、`STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_REVISED_BACKUP_FILES_VERIFIED` 和 `STAGING_REVISED_BACKUP_DIR=...`。只需反馈末尾非敏感标记和备份目录名；不要发送备份文件、教学内容或密码。若输出停在应用停止后、缺少末尾成功标记或出现重启失败，**不要重跑备份脚本或启动补丁**，先反馈最后的非敏感输出。

**第一步现场结果（用户提供的 2026-10-17 Ubuntu 输出；上方备份命令勿重跑）：**源草稿检查与 PostgreSQL/私有文件预检通过；预发布 Web/网关暂停后得到 `STAGING_POSTGRES_DUMP_READY`、`STAGING_PRIVATE_ARCHIVE_READY`，四服务启动并有 `STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_REVISED_BACKUP_FILES_VERIFIED`。实际目录为 `/home/huahua/teacher-workbench-staging-backups/backup-revised-X7Bv9cfE`。按脚本内容，该本机备份覆盖完成的任务 1/2、草稿两版、数据库和私有文件，文件校验完成。助手未直接访问服务器；独立恢复和 NAS 转存均未执行。

**第二步：全新隔离卷恢复（待用户执行）。**在用户电脑的 **Windows PowerShell** 进入项目目录，先确认 Ubuntu 家目录没有同名恢复脚本，再上传并核对哈希，最后把上方**实际备份目录**交给脚本。它只读取源预发布备份，在 Ubuntu 257 创建新的 Docker 网络、数据库卷和私有文件卷；恢复副本中验证虚构原件下载哈希、两版预览、两版各两份可解析且不同的 Word，以及另一账号的 404。恢复容器最终停止，新卷保留；不会清理源卷、写 NAS、调用 AI 或更新正式环境。SSH/sudo 密码只在自己的终端输入。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/restore_ubuntu_staging_revised.sh && test ! -L ~/restore_ubuntu_staging_revised.sh && echo STAGING_REVISED_RESTORE_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'STAGING_REVISED_RESTORE_TARGET_FREE') { throw '服务器恢复脚本目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\restore_ubuntu_staging_revised.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '恢复脚本上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "4e99532774ace77c1cac0c6a9f6d09a1ea35b019dac78ae7d9d0ec681f85dde6  restore_ubuntu_staging_revised.sh" | sha256sum -c - && bash -n restore_ubuntu_staging_revised.sh && bash restore_ubuntu_staging_revised.sh /home/huahua/teacher-workbench-staging-backups/backup-revised-X7Bv9cfE'
```

成功应看到 `STAGING_REVISED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_REVISED_INDEPENDENT_RESTORE_VERIFIED` 和 `STAGING_REVISED_RESTORE_DIR=...`。检查另一账号时可能出现 `Not Found`，须以最终成功标记为准。请只反馈末尾非敏感标记和恢复目录名，不发送备份文件、密码或题目。若出现权限、镜像、目标已存在或恢复错误，**不要重跑或删除任何目录、卷**；保留末尾输出供检查。

**第二步现场结果（用户提供的 2026-10-17 Ubuntu 输出；上方恢复命令勿重跑）：**返回隔离目标预检、随机测试配置、空数据库、PostgreSQL 和私有文件恢复成功；随后有 `STAGING_REVISED_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_REVISED_INDEPENDENT_RESTORE_VERIFIED`。新目录 `/home/huahua/teacher-workbench-staging-revised-restore-20261017`；四条 `Not Found` 是恢复副本另一账号访问原件、作业及两版教师卷时预期的 404。新容器已停、新卷保留，源预发布和旧测试站登录页均 HTTP 200。助手未直接登录 Ubuntu；第 2 版 NAS 副本尚未转存。

**第三步：只更新独立预发布网页的换行渲染（待用户执行）。**本机重新制作两文件补丁包，哈希保持 `7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d`；对应更新脚本哈希为 `11c86b65650f29b4edd21f27c44f766e62cb1e269d6a7f68e9b0b1398fb0019c`。Bash 语法、LF 行尾、无清卷/付费调用命令及本机虚构换行单测再次通过。**这些是本机检查，Ubuntu 构建和页面效果尚未验证。**下面脚本要求第 2 版备份完整、源代码和镜像与备份匹配、四服务运行及新目录/镜像标签空闲，然后从已核对的旧代码包创建新私有目录，只覆盖两处渲染代码，离线构建新 Web 镜像并重建预发布 Web/网关。原数据库、私有卷、旧代码和镜像保留；若切换后验证失败，脚本尝试恢复旧 Web/网关。旧测试站、NAS、正式环境均不改；AI 继续关闭。**部署过程可能短暂中断预发布网页。**

在用户电脑的 **Windows PowerShell** 输入下列整段命令。先检查 Ubuntu 家目录没有同名脚本或补丁包，避免覆盖；上传后再次核对 SHA-256 再执行。SSH/sudo 密码只在本机终端输入，不发送到聊天。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'for p in ~/apply_ubuntu_staging_linebreak_fix.sh ~/teacher-workbench-staging-linebreak-fix-7198283e.tar.gz; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo STAGING_LINEBREAK_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'STAGING_LINEBREAK_TARGETS_FREE') { throw '服务器补丁目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\apply_ubuntu_staging_linebreak_fix.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '更新脚本上传失败，请停止并反馈' }
scp .\data\deploy\teacher-workbench-staging-linebreak-fix.tar.gz huahua@10.0.30.5:teacher-workbench-staging-linebreak-fix-7198283e.tar.gz
if ($LASTEXITCODE -ne 0) { throw '补丁包上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "11c86b65650f29b4edd21f27c44f766e62cb1e269d6a7f68e9b0b1398fb0019c  apply_ubuntu_staging_linebreak_fix.sh" | sha256sum -c - && echo "7198283ea40ed0368dad0107e8050076dfcf8faadb928229bfd83d0b202ca94d  teacher-workbench-staging-linebreak-fix-7198283e.tar.gz" | sha256sum -c - && bash -n apply_ubuntu_staging_linebreak_fix.sh && bash apply_ubuntu_staging_linebreak_fix.sh /home/huahua/teacher-workbench-staging-backups/backup-revised-X7Bv9cfE'
```

成功应看到 `STAGING_LINEBREAK_NEW_CONFIG_READY`、`STAGING_LINEBREAK_NEW_IMAGE_READY`、`STAGING_LINEBREAK_RENDER_AND_AI_OFF_VERIFIED`、`STAGING_LINEBREAK_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_LINEBREAK_FIX_DEPLOYED_AI_OFF` 和新目录标记。只反馈末尾非敏感输出和新目录，不发送密码、备份或题目内容。若缺少最终成功标记、构建失败或出现 `STAGING_LINEBREAK_ROLLBACK_FAILED_REVIEW_REQUIRED`，保留现场并反馈，**不要重跑、删目录或清卷**。本步骤尚未由用户在 Ubuntu 运行；成功后还需在真实预发布页面与 WPS 检查第 1/2 版和双 Word，才能记为用户验收通过。

**第三步现场结果（用户提供的 2026-10-17 Ubuntu 构建/切换日志；上方部署命令勿重跑）：**源站 HTTP 200、隔离预检、Compose 配置通过；新镜像 `teacher-workbench-staging-web:linebreak-20261017` 构建完成，预发布 Web/网关启动。随后出现 `STAGING_LINEBREAK_RENDER_AND_AI_OFF_VERIFIED`、`STAGING_LINEBREAK_AND_OLD_TEST_LOGIN_HTTP_200`、最终 `STAGING_LINEBREAK_FIX_DEPLOYED_AI_OFF`，新目录 `/home/huahua/teacher-workbench-staging-linebreak-7198283e`。按已核对脚本，合成答案的网页分行、教师 Word 换行和 AI 关闭在新容器中通过；新旧站登录页 HTTP 200，旧目录/镜像与业务卷保留。助手未直接登录 Ubuntu 或打开真实第 2 版网页，用户 WPS 仍待验。

**第四步：浏览器与 WPS 复验（待用户实际操作）。**用户电脑若仍保持 `18002` 的 SSH 转发窗口，直接在浏览器打开 `http://127.0.0.1:18002/worksheets/1/`；若转发窗口已关闭，在另一个 **Windows PowerShell** 窗口运行下面的命令并保持窗口打开，光标持续闪动是转发正常等待访问，不是卡死。只在浏览器输入已有虚构测试账号 `staging_preview_20261017` 的密码，不发送密码到聊天。

```powershell
ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5
```

登录后刷新作业详情，确认“草稿预览 · 第 2 版”；展开第 1 题“查看参考答案”，观察“第一步”“第二步”是否真正分行、是否仍出现字面 `\n`。点击“历史版本”里的“第 1 版”确认旧稿可看，再点“第 2 版”返回。下载第 2 版“学生卷 Word”和“教师答案版 Word”，在 WPS 打开：确认学生卷不含教师答案，教师版对应预览且分步换行，`x²` 等公式可编辑，答案正确，打印预览排版正常。**不要点“提交修改要求”或重新运行任务 2**；本次复验不需新 AI 调用。只反馈上述检查哪些正常、哪些有问题；问题截图不要包含密码或其他私人教学资料。实际纸张打印和厂商账单仍按先前决定另行核对。

**第四步现场结果（用户 2026-10-17 实际反馈；上方验收步骤勿重复）：**用户回答“三项正常”，对应实际第 2 版答案分行、字面 `\n` 消失、历史第 1 版可查看，以及两份第 2 版 Word 在 WPS 的答案、公式编辑和打印预览正常。技术部署与教师实际验收分别记录；没有运行新的付费任务。助手未直接控制浏览器/WPS，纸张打印和厂商账单仍未验证。

## 第 2 版虚构备份转存专用 NAS（2026-10-17，现场已完成）

**目的与边界：**将已经在 Ubuntu 本机备份并独立恢复过的第 1/2 版虚构资料、草稿及双 Word，连同其匹配的旧代码包、已部署的两文件换行补丁和更新脚本，复制到 OMV 的 `teacher-workbench-backup` 专用 NFS 新目录。脚本先核对源文件、镜像标识和 SHA-256，再临时挂载 NAS、逐文件复制校验并卸载。它不读运行中的数据库或私有卷，不停止服务，不运行模型，不覆盖旧 NAS 副本。下方命令为当时执行步骤，现场结果记录在其后，**请勿重复执行**。

**历史执行命令（已完成，请勿重跑）：**在用户电脑的 **Windows PowerShell** 中先确认 Ubuntu 家目录没有同名脚本，再上传、校验脚本，最后在 **Ubuntu 257** 上通过 `sudo` 运行。SSH/sudo 密码只在本机终端输入，不发送到聊天。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/copy_staging_revised_backup_to_nas.py && test ! -L ~/copy_staging_revised_backup_to_nas.py && echo REVISED_NAS_COPY_HELPER_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'REVISED_NAS_COPY_HELPER_TARGET_FREE') { throw '服务器目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\copy_staging_revised_backup_to_nas.py huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "61529b2cdc303c6a9c4ddac742305ecebe6be96463eace18f697e326cbf0fa70  copy_staging_revised_backup_to_nas.py" | sha256sum -c - && sudo python3 ~/copy_staging_revised_backup_to_nas.py'
```

成功时应看到 `REVISED_STAGING_SOURCE_BACKUP_VERIFIED`、`DEDICATED_NAS_MOUNT_VERIFIED`、九项 `NAS_COPY_FILE_VERIFIED=...`、`NAS_REVISED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_BACKUP_NAME=staging-revised-X7Bv9cfE-...` 和最终 `NAS_REVISED_STAGING_COPY_DONE`。只需反馈最后几行标记及 NAS 副本名。此时仅能说明转存完成；**还需从该 NAS 副本只读导入并恢复到新的隔离 Docker 卷**，才算第 2 版 NAS 来源恢复验证通过。已编写导入与恢复脚本，但本节不要求提前运行。

**转存现场结果（用户 2026-10-17 终端输出；上方复制命令勿重跑）：**九项文件分别返回 `NAS_COPY_FILE_VERIFIED=...`，随后是 `NAS_REVISED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED` 和 `NAS_REVISED_STAGING_COPY_DONE`；副本名为 `staging-revised-X7Bv9cfE-8fb7b9d72c41`。这证明转存脚本的核对和卸载步骤按其成功路径执行；助手未直接挂载 NAS，也未把复制成功等同于恢复成功。

## 从第 2 版 NAS 副本只读导入并独立恢复（2026-10-17，现场已完成）

**目的与边界：**只读挂载上述专用 NAS 副本，核对 9 项载荷及清单后复制到 Ubuntu 新私有目录，再用全新的 PostgreSQL/私有文件 Docker 卷恢复虚构资料。恢复检查会核对两版草稿、四份可解析 Word、资料原件哈希与另一账号访问被拒绝；源预发布站和旧测试站登录页也会核对。新恢复容器在结束时停止，新卷保留；不覆盖现有预发布卷或 NAS 副本，不运行付费 AI。配对备份在换行修复前制作，恢复演练使用旧镜像验证**数据**；补丁文件随副本保存，恢复副本不会自动应用补丁或被当作现有页面显示验收。

**历史执行命令（已完成，请勿重跑）：**用户在 Windows PowerShell 中先确认 Ubuntu 家目录中三个辅助脚本的目标位置均为空，再上传并核对哈希，随后顺序运行只读导入和独立恢复。SSH/sudo 密码未发到聊天。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'for p in ~/import_staging_revised_nas_backup.py ~/verify_staging_revised_nas_snapshot.py ~/restore_ubuntu_staging_revised_from_nas.sh; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo REVISED_NAS_RESTORE_HELPER_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'REVISED_NAS_RESTORE_HELPER_TARGETS_FREE') { throw '服务器目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\import_staging_revised_nas_backup.py .\scripts\verify_staging_revised_nas_snapshot.py .\scripts\restore_ubuntu_staging_revised_from_nas.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '脚本上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "61bdfbff14a8b8536ad04524fb2ddd0a0f387f390ae2506220bf8d0cde20abd1  import_staging_revised_nas_backup.py" | sha256sum -c - && echo "4b3afde68284266c9f3b3937b27252b93485d31486c8d2220d17e4b7b834b682  verify_staging_revised_nas_snapshot.py" | sha256sum -c - && echo "77b57a35d0e5839ccccb1a30527f974fb1d2709dd3e6c8147d0f480ef835a016  restore_ubuntu_staging_revised_from_nas.sh" | sha256sum -c - && bash -n restore_ubuntu_staging_revised_from_nas.sh && sudo python3 ~/import_staging_revised_nas_backup.py staging-revised-X7Bv9cfE-8fb7b9d72c41 && bash ~/restore_ubuntu_staging_revised_from_nas.sh /home/huahua/teacher-workbench-nas-import-staging-revised-X7Bv9cfE-8fb7b9d72c41'
```

成功应先看到 `NAS_REVISED_STAGING_IMPORT_DONE` 和 `NAS_MOUNT_CLEANED`，再看到 `STAGING_REVISED_NAS_RESTORE_CONTENT_AND_ACCESS_OK`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 与最终 `STAGING_REVISED_NAS_SOURCE_RESTORE_VERIFIED`。检查器预期的四条 `Not Found` 是另一账号被拒绝，不是恢复失败。

**现场结果（用户 2026-10-17 终端输出；上方命令勿重跑）：**11 项导入文件逐个返回校验标记，临时 NFS 挂载已清理；导入目录 `/home/huahua/teacher-workbench-nas-import-staging-revised-X7Bv9cfE-8fb7b9d72c41`。新数据库和私有文件恢复、两版草稿/四份 Word/跨账号 404 检查通过，源预发布和旧测试站登录页仍 HTTP 200，恢复容器已停、卷保留；最终为 `STAGING_REVISED_NAS_SOURCE_RESTORE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-revised-nas-restore-20261017`。助手未直接连接 Ubuntu 或查看恢复文件。这一步验证了数据恢复，未从 NAS 文件重建当前换行修复镜像。

## 从 NAS 代码包和补丁离线重建已验收的渲染版（2026-10-17，旧方案已在预检退出）

**目的与边界：**上一项使用配对旧镜像验证了**数据**。本项把已经从 NAS 导入的旧代码包与两文件换行补丁放入现有隔离恢复目录，使用离线 wheelhouse 和本机已有基础镜像构建一个**新测试镜像**；构建前要求 Docker 所在文件系统至少有 8 GiB 可用。只短暂启动上一步已停的恢复用数据库，检查第 2 版答案在网页分行、学生与教师 Word 区分且教师版为真实换行，然后再次停库。脚本不会切换正在使用的预发布 Web，不改正式环境，不读取 API Key 或调用模型，也不清理已有镜像和卷。Docker 离线构建可能输出较多日志并持续数分钟。**本地语法及保护检查已通过，Ubuntu 实际构建尚待验证。**

在用户电脑的 **Windows PowerShell** 执行下列整段。先确认 Ubuntu 家目录目标文件不存在，再上传并校验 SHA-256，最后运行脚本。SSH/sudo 密码只在本机终端输入。若出现报错或没有最终标记，保留现场、反馈非敏感末尾输出；**不要重跑、删除构建目录/镜像或启动正式服务**。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/verify_ubuntu_staging_revised_nas_renderer_rebuild.sh && test ! -L ~/verify_ubuntu_staging_revised_nas_renderer_rebuild.sh && echo NAS_RENDERER_HELPER_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'NAS_RENDERER_HELPER_TARGET_FREE') { throw '服务器目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\verify_ubuntu_staging_revised_nas_renderer_rebuild.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '脚本上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "27f7c7ce66cbb4942a3160f6e01db7036ed31ef42424ba778f2e1295d2461e77  verify_ubuntu_staging_revised_nas_renderer_rebuild.sh" | sha256sum -c - && bash -n verify_ubuntu_staging_revised_nas_renderer_rebuild.sh && bash verify_ubuntu_staging_revised_nas_renderer_rebuild.sh'
```

**现场结果（用户提供的 2026-10-17 Ubuntu 输出；以上旧命令不要重跑）：**上传文件哈希检查通过、进入 `sudo` 验证后，Docker 报 `No such image: python:3.12-slim`。按已核对脚本，失败点位于 `NAS_RENDERER_REBUILD_ISOLATION_PREFLIGHT_OK` 之前，也早于创建构建目录、启动恢复数据库或生成新镜像；因此没有得到重建成功证据。本轮改用以下新文件名和已配对的本地应用镜像继续。

## 使用配对应用镜像续做 NAS 渲染代码恢复演练（2026-10-17，现场技术测试通过）

**目的与边界：**新脚本仍从已导入的 NAS 副本取代码与两文件补丁，并先把 `APP_IMAGE_ID` 与本机旧应用镜像 ID 比对。以这份**配对镜像**作为离线构建底座，安装好的 Python 依赖可复用，不需要拉取 `python:3.12-slim`。新建独立镜像和构建目录，只短暂启动此前恢复并已停用的隔离数据库；不切换正在使用的预发布站，也不调用模型。此测试依赖 Ubuntu 上还留有那份配对镜像，**不能代表在一台全新服务器上完成整机恢复**。本机脚本检查已做，Ubuntu 构建与数据验证仍待现场执行。

在用户电脑 **Windows PowerShell** 执行下列整段。检查目标脚本名尚未占用，再上传、核对哈希、执行；SSH/sudo 密码仅在本机终端输入。若没有最后的成功标记，请保留输出并停止，不要清理镜像或卷。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh && test ! -L ~/verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh && echo NAS_RENDERER_PAIRED_HELPER_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'NAS_RENDERER_PAIRED_HELPER_TARGET_FREE') { throw '服务器目标已占用或预检失败，请停止并反馈' }
Write-Output $check
scp .\scripts\verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '脚本上传失败，请停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "6fb09683fbeac7beedd498a26215dd67855df176ab24cda4bef87b70c2b127d1  verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh" | sha256sum -c - && bash -n verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh && bash verify_ubuntu_staging_revised_nas_renderer_rebuild_paired.sh'
```

成功应看到 `NAS_RENDERER_PAIRED_ISOLATION_PREFLIGHT_OK`、`NAS_RENDERER_SOURCE_AND_PATCH_READY`、`NAS_RENDERER_PAIRED_OFFLINE_IMAGE_BUILT`、`NAS_RENDERER_REVISED_PREVIEW_AND_WORD_VERIFIED`、`NAS_RENDERER_SOURCE_LOGIN_HTTP_200`、`NAS_RENDERER_RESTORE_DATABASE_STOPPED` 与最终 `NAS_RENDERER_FROM_NAS_PAIRED_REBUILD_VERIFIED`。仅反馈这些标记或非敏感报错；无需发送资料、备份、密钥或环境文件。

**现场结果（用户提供的 2026-10-17 Ubuntu 输出；以上命令勿重跑）：**构建、虚构第 2 版预览和 Word、两处源站登录页、恢复数据库停止及最终成功标记均返回。按脚本控制流，隔离预检、NAS 代码/补丁哈希和配对镜像 ID 也已通过。新镜像标签为 `teacher-workbench-staging-web:nas-renderer-paired-20261017`；构建目录为隔离恢复目录下的 `nas-renderer-paired-source`。这是复用本机旧应用镜像完成的渲染恢复技术演练，未切换在线预发布 Web，也不能代表全新机器从 NAS 独立启动服务。助手未直接连接 Ubuntu；用户此前对在线预发布第 2 版的 WPS 检查仍为独立证据。

### 阶段 2A 账号功能的预发布升级（2026-10-18；第 1 步已现场完成）

2A 的本机代码与迁移已通过 SQLite 自动测试。按用户 2026-10-17 的现场结果，Ubuntu 预发布站当时运行换行修复版；**本轮未连接服务器复核当前运行状态**。已有 `backup_ubuntu_staging_revised.sh` 固定核对更新前的 `manual-queue-20261017` 镜像与源码，不能直接拿它备份换行修复版，也不能把过去的 `backup-revised-X7Bv9cfE` 当作升级当天的新恢复点。

升级前须为当前预发布状态制作新的数据库与私有文件配对备份，并在隔离新卷恢复核对两版虚构草稿和账号隔离；再用独立镜像构建 2A，核对 `0004_memberaccess_memberaudit` 迁移、登录页、旧虚构账号资料、强制首次改密与管理权限。失败时先停止新 Web/网关，恢复旧镜像；如数据库迁移或数据有异常，应从升级前的**数据库与私有文件配对快照**恢复到新的隔离卷核对，不能认为只换回旧镜像就完成数据回退。所有新脚本、命令和成功标记须在实际编写与检查后补在此处；本节目前**没有可直接执行的 Ubuntu 命令，也不表示已有新备份或新部署**。不使用真实成员密码或 Key 参与测试。

**2026-10-18 补记：下面的四步脚本现已编写，本机静态检查通过，但 Ubuntu 操作均未执行。**上一段“没有可直接执行的命令”是编写前的状态。所有命令仅针对 Ubuntu 虚拟机 257 的独立预发布栈；正式站、旧测试站、PVE 宿主机、OMV 均不修改。备份会暂停预发布 Web/网关，页面会短暂不可用；恢复和更新脚本不删除 Docker 卷。每一步只执行一次，等待该步结果后再运行下一步。SSH、sudo 与测试密码只在自己的终端输入，不发给助手。

**第 1 步：新建当前预发布状态的配对备份（待现场执行）。**在用户电脑的 **Windows PowerShell**，进入 `D:\Projects\teacher-workbench`；此步骤仅上传两个经过本机核对的脚本到 Ubuntu `huahua` 家目录，再检查文件哈希并运行备份。它要求当前在线镜像仍是 `linebreak-20261017`、虚构资料仅一份、任务 1/2 已完成且有两版草稿；任何预检不符便停止，不绕过检查。文件摘要：检查器 `4a4991c504f27717c8c34bdd0863fca8013b7511d1e04d91ff607de8cda8db49`，备份脚本 `aec23499be9b1ed5a66ae2c61359b275f5eaa443e6979317b64271244b13a8f3`。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'for p in ~/verify_staging_phase2a_pre_snapshot.py ~/backup_ubuntu_staging_phase2a_pre.sh; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo PHASE2A_BACKUP_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_BACKUP_TARGETS_FREE') { throw '服务器目标已占用或无法核对；停止并反馈' }
scp .\scripts\verify_staging_phase2a_pre_snapshot.py .\scripts\backup_ubuntu_staging_phase2a_pre.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "4a4991c504f27717c8c34bdd0863fca8013b7511d1e04d91ff607de8cda8db49  verify_staging_phase2a_pre_snapshot.py" | sha256sum -c - && echo "aec23499be9b1ed5a66ae2c61359b275f5eaa443e6979317b64271244b13a8f3  backup_ubuntu_staging_phase2a_pre.sh" | sha256sum -c - && bash -n backup_ubuntu_staging_phase2a_pre.sh && bash backup_ubuntu_staging_phase2a_pre.sh'
```

完成时应出现 `STAGING_PHASE2A_PRE_BACKUP_FILES_VERIFIED` 和 `STAGING_PHASE2A_PRE_BACKUP_DIR=/home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-...`，且站点重新返回 HTTP 200。记录实际目录；失败时反馈最后一条**不含资料或密码**的标记，不关闭仍在运行的终端或重复运行。

**第 2 步：在全新隔离卷恢复（第 1 步成功后待执行）。**脚本 `restore_ubuntu_staging_phase2a_pre.sh` 的 SHA-256 为 `d88403303f7323cf28c18b3989d016eaffdbbbc7dcfe37be6a2f3135c4bdf811`。运行时应传入第 1 步返回的**实际**备份目录，不使用旧的 `backup-revised-X7Bv9cfE`。它只读取新备份，创建名为 `teacher-workbench-staging-phase2a-pre-restore-20261018` 的隔离数据库与私有卷，核对两版草稿、四份 Word 和跨账号 404；结束时停止新容器、保留新卷。源预发布站仍运行。具体含实际目录的单条命令待第 1 步输出后填写，避免误用旧恢复点。成功标记为 `STAGING_PHASE2A_PRE_INDEPENDENT_RESTORE_VERIFIED`。

**第 3 步：离线构建并切换预发布 Web（第 2 步成功后待执行）。**本机生成的 14 文件源码补丁 `data/deploy/teacher-workbench-staging-phase2a.tar.gz` 的 SHA-256 为 `1bf5a500892ffc51233add592cc8230e5ae394472f868783fa3d01f71e0f8082`；部署脚本 `apply_ubuntu_staging_phase2a.sh` 的 SHA-256 为 `7bcc3a3ae2501235d8ce26165472518c9568d752ddd5147787153a847e62dc9e`。部署脚本先核对第 1/2 步备份、独立恢复容器和旧站镜像；以现有 `linebreak-20261017` 本地镜像离线构建 `accounts-20261018`，在**恢复副本**跑 `0004` 迁移和虚构账号测试。全部通过后才让在线预发布 Web/网关使用新镜像；运行时迁移真实预发布数据库仅新增表与权限。失败时尝试恢复旧 Web/网关，不删除数据库或文件卷；若真实库迁移后要撤回数据状态，须从第 1 步配对备份另行恢复，不能只换镜像。具体含实际备份目录的命令待前两步成功后填写。成功标记为 `STAGING_PHASE2A_DEPLOYED_AI_OFF`。

**第 4 步：建立虚构管理账号并用浏览器验收（第 3 步成功后待执行）。**交互脚本 `create_ubuntu_staging_phase2a_manager.sh` 的 SHA-256 为 `22ad8a248e95074441a6d2b71f719476502e3c8ea5b3a40257894c4c018ef19d`。它仅在 2A 新镜像、迁移和 AI 关闭状态已核对后运行；用户在自己的 SSH 终端输入两次测试密码，输出只包含账号 `staging_manager_20261018` 与“password hidden”。用户经现有 SSH 回环隧道登录 `http://127.0.0.1:18002/login/`，从“成员账号管理”创建第二个虚构普通账号，记录临时密码但不发给助手；在另一浏览器窗口验证首次改密、重置、停用、旧会话失效，以及本人旧草稿和别人的资料不可见。先验收页面再考虑下一片，正式发布和真实成员 Key 仍不操作。

**第 1 步现场结果（用户提供，2026-10-18；勿重复运行）：**`STAGING_WEB_RESTARTED_HTTP_200`、`STAGING_PHASE2A_PRE_BACKUP_FILES_VERIFIED`；实际备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-l1gxAffX`。助手未连接 Ubuntu。前文“尚未执行”是编写时的历史状态；当前只进行第 2 步隔离恢复。

**第 2 步执行命令（Windows PowerShell，待用户现场执行）：**在 `D:\Projects\teacher-workbench` 执行以下命令。它先检查 Ubuntu 家目录没有同名目标，再上传经过哈希核对的恢复脚本，仅以第 1 步的实际备份目录创建全新隔离卷。若目标存在或任何预检失败，停下反馈，不覆盖或删除。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/restore_ubuntu_staging_phase2a_pre.sh && test ! -L ~/restore_ubuntu_staging_phase2a_pre.sh && echo PHASE2A_RESTORE_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_RESTORE_TARGET_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\restore_ubuntu_staging_phase2a_pre.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "d88403303f7323cf28c18b3989d016eaffdbbbc7dcfe37be6a2f3135c4bdf811  restore_ubuntu_staging_phase2a_pre.sh" | sha256sum -c - && bash -n restore_ubuntu_staging_phase2a_pre.sh && bash restore_ubuntu_staging_phase2a_pre.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-l1gxAffX'
```

成功应看到 `STAGING_PHASE2A_PRE_INDEPENDENT_RESTORE_VERIFIED` 和 `STAGING_PHASE2A_PRE_RESTORE_DIR=...`。期间的 `Not Found` 是脚本期待的跨账号 404。仅反馈非敏感完成标记；第 3 步要等第 2 步结果。此命令本机尚未对 Ubuntu 执行。

**第 2 步现场结果（用户提供，2026-10-18；勿重复运行）：**返回 `STAGING_PHASE2A_PRE_INDEPENDENT_RESTORE_VERIFIED`、`STAGING_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_AND_OLD_TEST_LOGIN_HTTP_200_AFTER_RESTORE`，恢复目录 `/home/huahua/teacher-workbench-staging-phase2a-pre-restore-20261018`。按脚本完成条件，两版虚构草稿、四份 Word 与跨账号 404 均已技术核对；源站仍可登录。助手未直接连接 Ubuntu，2A 在线迁移仍未执行。

**第 3 步执行命令（Windows PowerShell，待用户现场执行）：**在 `D:\Projects\teacher-workbench` 执行以下命令。先核对 Ubuntu 家目录目标未占用，再上传无业务数据的 2A 源码补丁和部署脚本，并验证哈希。部署脚本先在恢复副本运行 PostgreSQL 迁移和虚构账号测试，通过后才切换预发布 Web/网关；失败时尝试恢复旧 Web/网关，保留备份和数据卷。它会短暂中断预发布网页；不涉及正式环境或付费模型。若失败，停止并反馈最后的非敏感输出，不重跑或自行删除卷。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'for p in ~/apply_ubuntu_staging_phase2a.sh ~/teacher-workbench-staging-phase2a-1bf5a500.tar.gz; do test ! -e "$p" && test ! -L "$p" || exit 1; done; echo PHASE2A_DEPLOY_TARGETS_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_DEPLOY_TARGETS_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\apply_ubuntu_staging_phase2a.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传部署脚本失败；停止并反馈' }
scp .\data\deploy\teacher-workbench-staging-phase2a.tar.gz huahua@10.0.30.5:teacher-workbench-staging-phase2a-1bf5a500.tar.gz
if ($LASTEXITCODE -ne 0) { throw '上传源码补丁失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "7bcc3a3ae2501235d8ce26165472518c9568d752ddd5147787153a847e62dc9e  apply_ubuntu_staging_phase2a.sh" | sha256sum -c - && echo "1bf5a500892ffc51233add592cc8230e5ae394472f868783fa3d01f71e0f8082  teacher-workbench-staging-phase2a-1bf5a500.tar.gz" | sha256sum -c - && bash -n apply_ubuntu_staging_phase2a.sh && bash apply_ubuntu_staging_phase2a.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2a-pre-l1gxAffX'
```

成功标记是 `STAGING_PHASE2A_ISOLATED_POSTGRES_TESTS_OK`、`STAGING_PHASE2A_NEW_AND_OLD_LOGIN_HTTP_200`、`STAGING_PHASE2A_DEPLOYED_AI_OFF`。仅凭这些标记可记录为预发布技术测试通过；成员管理页面仍需第 4 步用户实际验收。脚本先前只通过本机静态检查，现场执行结果待用户反馈。

**第 3 步现场结果（用户提供，2026-10-18；勿重复运行）：**返回 `STAGING_REVISED_SOURCE_VERIFIED`、`STAGING_PHASE2A_NEW_AND_OLD_LOGIN_HTTP_200`、`STAGING_PHASE2A_DEPLOYED_AI_OFF`；新代码目录 `/home/huahua/teacher-workbench-staging-phase2a-1bf5a500`。按脚本控制流，先前的独立恢复副本迁移与虚构账号测试已通过，随后在线预发布 Web/网关切换完成；当前仅有用户终端技术结果，未做浏览器成员流程验收。原配对备份和恢复卷保留，不运行正式发布。

**第 4 步 A：创建虚构管理账号（Windows PowerShell，待用户现场执行）。**先检查 Ubuntu 家目录没有同名脚本，上传并核对 SHA-256；脚本再次核对目标仅为预发布库、2A 镜像/迁移与 AI 关闭状态，然后在用户终端交互输入两次新测试密码。密码输入不显示，助手不接收。脚本只创建 `staging_manager_20261018`，不是正式成员账号；若目标已存在或任何预检失败，停止反馈，不重跑、不覆盖旧账号。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/create_ubuntu_staging_phase2a_manager.sh && test ! -L ~/create_ubuntu_staging_phase2a_manager.sh && echo PHASE2A_MANAGER_SCRIPT_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_MANAGER_SCRIPT_TARGET_FREE') { throw '服务器脚本目标已占用或预检失败；停止并反馈' }
scp .\scripts\create_ubuntu_staging_phase2a_manager.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "22ad8a248e95074441a6d2b71f719476502e3c8ea5b3a40257894c4c018ef19d  create_ubuntu_staging_phase2a_manager.sh" | sha256sum -c - && bash -n create_ubuntu_staging_phase2a_manager.sh && bash create_ubuntu_staging_phase2a_manager.sh'
```

成功应显示 `STAGING_PHASE2A_MANAGER_PREFLIGHT_OK` 和 `STAGING_PHASE2A_MANAGER_READY username=staging_manager_20261018 staff=False; password hidden`。完成后先反馈非敏感标记，再进行第 4 步 B 的浏览器验收；不发送测试密码、Cookie 或截图中的敏感字段。此命令尚未现场执行。

**第 4 步 A 中断情况（用户提供，2026-10-18）：**脚本已上传且哈希输出 `OK`，终端停留在 sudo 认证附近；用户输入密码后关闭原窗口，没有最终建号标记。此时账号是否写入未知。**不要重复上传或直接重跑脚本。**先在 Windows PowerShell 运行下列只读查询；它仅统计隔离预发布库中固定虚构用户名的记录，不读取或显示密码，也不修改数据库。输入 SSH 和 sudo 密码时屏幕不显示字符；只反馈 `0` 或 `1` 及非敏感报错。

```powershell
ssh -t huahua@10.0.30.5 'sudo docker exec teacher-workbench-staging-db-1 psql -U teacher_workbench_staging -d teacher_workbench_staging -Atqc "SELECT COUNT(*) FROM auth_user WHERE username = ''staging_manager_20261018'';"'
```

`0` 表示未建号，可在确认原进程已退出后设计续接；`1` 表示账号存在，不能再创建同名账号，应先检查其权限及是否掌握测试密码。此查询的现场结果待用户反馈。

**纠错（2026-10-18）：上述内联 `psql` 命令在用户 Windows PowerShell→SSH 路径中丢失双引号，Ubuntu Bash 返回 `syntax error near unexpected token '('`，数据库查询没有执行。不要重试该内联命令。**改用 `scripts/check_ubuntu_staging_phase2a_manager_readonly.sh`，本机 SHA-256 为 `10c79cd08deccb68179fbafdb5dbfdf3f8ad993076e20375c8a78fd91edfe690`；本机 Bash 语法和错误主机拒绝已检查。它只统计隔离预发布数据库的固定虚构账号数量，结果以 `STAGING_PHASE2A_MANAGER_COUNT=0` 或 `=1` 输出。下列操作仍待 Ubuntu 现场执行。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/check_ubuntu_staging_phase2a_manager_readonly.sh && test ! -L ~/check_ubuntu_staging_phase2a_manager_readonly.sh && echo PHASE2A_READONLY_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_READONLY_TARGET_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\check_ubuntu_staging_phase2a_manager_readonly.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "10c79cd08deccb68179fbafdb5dbfdf3f8ad993076e20375c8a78fd91edfe690  check_ubuntu_staging_phase2a_manager_readonly.sh" | sha256sum -c - && bash -n check_ubuntu_staging_phase2a_manager_readonly.sh && bash check_ubuntu_staging_phase2a_manager_readonly.sh'
```

输入 SSH 与 sudo 密码时字符不显示；仅反馈最终计数标记或非敏感错误。若未返回计数，保持窗口以便诊断，不关闭后重跑。脚本不触碰原建号脚本和账号。

**只读查询现场结果（用户提供，2026-10-18）：**`STAGING_PHASE2A_MANAGER_COUNT=0`，目标虚构管理账号在查询时不存在。旧建号脚本已上传并通过 SHA-256 检查，无需再次上传。为分清 sudo 与容器交互步骤，用户下一次在 Windows PowerShell 先运行 `ssh huahua@10.0.30.5` 进入 Ubuntu；看到 `huahua@teacher-workbench:~$` 后运行 `sudo -v`，输入 Ubuntu 密码并确认回到同一提示符；再运行 `bash ~/create_ubuntu_staging_phase2a_manager.sh`。此时脚本先完成预检，再提示输入两次**新测试账号密码**，不在聊天中发送。成功标记仍为 `STAGING_PHASE2A_MANAGER_READY username=staging_manager_20261018 staff=False; password hidden`。**该续接操作尚未现场执行。**若输入密码后 30 秒没有新输出，保留原窗口并反馈最后可见行，勿盲目重跑。

**第二次尝试停留（用户提供，2026-10-18）：**`sudo -v` 首次认证失败、第二次返回 Ubuntu shell；执行建号脚本后 30 秒无任何新输出。脚本在输出 `STAGING_PHASE2A_MANAGER_PREFLIGHT_OK` 前有静默预检，因此目前无法判定卡在哪条命令。**保持原终端打开、不输入新密码或重复执行。**另开 Windows PowerShell，运行只读进程快照：

```powershell
ssh huahua@10.0.30.5 'ps -eo pid,ppid,user,etime,stat,wchan:24,comm --forest' | Select-String -Pattern 'PID|bash|sudo|docker|python|ssh'
```

该命令只显示进程名、等待状态和父进程编号，不显示命令参数、环境变量或密码。现场结果待反馈；不得把 30 秒无输出当作建号成功或失败。

**进程定位与替代路径（用户现场快照，2026-10-18）：**原脚本的 `docker-compose` 子进程为 `Tl+` 暂停状态，父 Bash/Sudo/Docker 等待，尚未输出 `STAGING_PHASE2A_MANAGER_PREFLIGHT_OK`，故不能算建号成功。先在原终端按一次 Ctrl+C；只有它返回 `huahua@teacher-workbench:~$` 才续接。新增 `scripts/create_ubuntu_staging_phase2a_manager_direct.sh`，不调用 Compose CLI，采用直接 Docker CLI 且对非交互检查设置超时；在任何创建动作前检查旧脚本进程不在、账号数为 0、2A 镜像与迁移已就绪。仍用镜像内已部署的交互式建号程序，不回显密码。**本机只通过 Bash 语法、LF 与错误主机拒绝检查，Ubuntu 尚未执行。**脚本 SHA-256 为 `dace06a95d3e02b0122488d5f453945943e7dd8dfacbe414c30f0119785ed500`。

原窗口返回 Ubuntu shell 提示符后，在 Windows PowerShell 执行以下上传与运行命令；若原窗口尚未返回，不执行。目标文件是新名称，不覆盖旧脚本；如果目标已存在，停止并反馈。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/create_ubuntu_staging_phase2a_manager_direct.sh && test ! -L ~/create_ubuntu_staging_phase2a_manager_direct.sh && echo PHASE2A_DIRECT_MANAGER_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_DIRECT_MANAGER_TARGET_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\create_ubuntu_staging_phase2a_manager_direct.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "dace06a95d3e02b0122488d5f453945943e7dd8dfacbe414c30f0119785ed500  create_ubuntu_staging_phase2a_manager_direct.sh" | sha256sum -c - && bash -n create_ubuntu_staging_phase2a_manager_direct.sh && bash create_ubuntu_staging_phase2a_manager_direct.sh'
```

正常应依次看到 `STAGING_PHASE2A_DIRECT_LOCAL_PREFLIGHT_OK`、`STAGING_PHASE2A_MANAGER_DIRECT_PREFLIGHT_OK`、终端隐藏输入两次新的测试密码，以及最终 `STAGING_PHASE2A_MANAGER_READY username=staging_manager_20261018 staff=False; password hidden`。如停留在任何标记之前，保持窗口，不重复输入或重跑，只反馈最后可见行和非敏感进程状态。

**2026-10-18 新现场反馈：**用户在原窗口按 Ctrl+C 仍未返回 shell 提示符。上述替代脚本的上传及运行暂缓。保持原窗口；在**另一个 Windows PowerShell 窗口**只读执行以下命令，核对前次快照中的进程是否仍为同一父子链。只反馈输出，不要复制密码或环境变量。

```powershell
ssh huahua@10.0.30.5 'ps -o pid,ppid,pgid,tpgid,user,etime,stat,comm -p 2534242,2534295,2534298,2534299,2534311'
```

预期若故障仍在，可看到 `docker-compose` 的状态以 `T` 开头，父进程为 `docker`；若 PID 已消失，则不对这些 PID 发信号。该复核**尚未现场执行**，不得提前把卡住的进程或建号状态记为已清理。

**复核结果（用户提供，2026-10-18）：**上述快照显示原 Bash PID `2534242` → sudo → Docker PID `2534299` → `docker-compose` PID `2534311`，后者 `Tl+`。只对该已暂停的 Compose CLI 进程解除卡住状态，不能对容器、Docker 服务或整个进程组发信号。在**新 Windows PowerShell 窗口**执行下列命令；它会在发送信号前再次核对 PID、父 PID 和暂停状态，若已变化则输出 `PROCESS_CHANGED_NO_SIGNAL` 并停止。Ubuntu sudo 密码输入时不显示字符。

```powershell
ssh -t huahua@10.0.30.5 'if [ $(ps -p 2534311 -o ppid=) = 2534299 ] && [ $(ps -p 2534311 -o comm=) = docker-compose ] && [ $(ps -p 2534311 -o stat= | cut -c1) = T ]; then sudo kill -TERM 2534311 && { sudo kill -CONT 2534311 2>/dev/null || true; echo STUCK_COMPOSE_SIGNAL_SENT; }; else echo PROCESS_CHANGED_NO_SIGNAL; fi'
```

此命令**尚未现场执行**。成功发送信号后观察原窗口是否返回 `huahua@teacher-workbench:~$`；如果没有，继续保留原窗口并反馈两个窗口的非敏感输出。不要在核对旧脚本已退出前启动替代建号脚本。

**信号现场结果（用户提供，2026-10-18）：**`STUCK_COMPOSE_SIGNAL_SENT`；原窗口提示符、旧 Bash 是否退出及目标账号数量尚未反馈。下一步在新的 Windows PowerShell 窗口运行以下只读复核。第一部分只报告原固定 PID 是否仍在；第二部分调用此前已上传的只读数据库计数脚本。Ubuntu sudo 密码输入不显示。

```powershell
ssh -t huahua@10.0.30.5 'if ps -p 2534242 -o comm= | grep -qx bash; then echo OLD_MANAGER_PROCESS_PRESENT; else echo OLD_MANAGER_PROCESS_GONE; fi; bash ~/check_ubuntu_staging_phase2a_manager_readonly.sh'
```

预期可见 `OLD_MANAGER_PROCESS_GONE` 和 `STAGING_PHASE2A_MANAGER_COUNT=0`。**该复核尚未现场执行**；若任一结果不同，停止，不启动替代建号脚本。

**只读复核现场结果（用户提供，2026-10-18）：**两项预期标记均返回。上文替代脚本的上传与运行步骤现在可执行；不需要原 SSH 窗口继续保持打开。脚本本机 SHA-256 再核对通过，上传时仍须进行远端校验。只有最终显示 `STAGING_PHASE2A_MANAGER_READY` 才算虚构账号创建完成；用户名、临时密码及网页操作验收仍分别核对。

**替代脚本首次现场失败（用户提供，2026-10-18）：**`STAGING_PHASE2A_MANAGER_DIRECT_PREFLIGHT_OK` 后，`python scripts/prepare_ubuntu_staging_phase2a_manager.py` 在导入 Django 配置时报 `No module named 'config'`。这发生在获取测试账号密码和数据库写入之前。已核对当前镜像的 `WORKDIR /app` 且含 `config/`，问题是以脚本路径调用时 Python 的导入路径。保留原上传脚本与镜像不动，改用新文件 `scripts/create_ubuntu_staging_phase2a_manager_pythonpath.sh`，仅为该次容器内建号进程指定 `PYTHONPATH=/app`。脚本重做服务、迁移和账号数预检，本机 SHA-256 为 `1e52088f24f603dba3d8a883281429d4080e592eea40a9e025ec24a259d35dad`，Bash 语法、LF 和错误主机拒绝通过。**以下续接尚未在 Ubuntu 验证。**

在 Windows PowerShell 执行整个命令块；目标若已存在便停止，不覆盖。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/create_ubuntu_staging_phase2a_manager_pythonpath.sh && test ! -L ~/create_ubuntu_staging_phase2a_manager_pythonpath.sh && echo PHASE2A_PYTHONPATH_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'PHASE2A_PYTHONPATH_TARGET_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\create_ubuntu_staging_phase2a_manager_pythonpath.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "1e52088f24f603dba3d8a883281429d4080e592eea40a9e025ec24a259d35dad  create_ubuntu_staging_phase2a_manager_pythonpath.sh" | sha256sum -c - && bash -n create_ubuntu_staging_phase2a_manager_pythonpath.sh && bash create_ubuntu_staging_phase2a_manager_pythonpath.sh'
```

成功应显示 `STAGING_PHASE2A_DIRECT_LOCAL_PREFLIGHT_OK`、`STAGING_PHASE2A_MANAGER_DIRECT_PREFLIGHT_OK`，随后隐藏输入两次新的测试账号密码，最后显示 `STAGING_PHASE2A_MANAGER_READY username=staging_manager_20261018 staff=False; password hidden`。如报错或停留，不要重跑，只反馈非敏感输出。

**续接现场结果（用户提供，2026-10-18）：**最终建号标记已返回，账号为 `staging_manager_20261018`、`staff=False`；密码只由用户在终端输入，未在文档或聊天记录保存。不要再次运行建号脚本。浏览器验收在 Windows PowerShell 保持以下 SSH 隧道窗口打开（该命令只建立本地转发，不修改服务器）：

```powershell
ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5
```

随后在 Windows 浏览器无痕窗口访问 `http://127.0.0.1:18002/login/`，用上述测试账号及用户自己设定的密码登录。预期左侧底部出现“成员账号管理”，打开后可见“成员账号”和“创建普通成员”。该页面步骤尚待用户现场验收；不把页面打开或资料隔离预先记为通过。若隧道提示端口已占用，先确认已有隧道窗口是否仍在运行，不再并行启动第二条同端口隧道。

**浏览器首项结果（用户提供，2026-10-18）：**上述入口和页面内容均已看到，记为用户实际验收通过。后续仍用此隔离预发布管理页面，只创建虚构普通账号 `staging_teacher_a_20261018`；点击“创建账号并显示临时密码”后，预期出现一次性临时密码页面。此操作尚待用户执行；密码由用户自己暂存供首次登录测试，不能提交聊天或 Git。

**普通账号现场结果（用户提供，2026-10-18）：**上述虚构账号与临时密码页面已显示，离开后不再显示。密码不记录。下一步保持管理者浏览器会话，在另一种浏览器的独立会话中访问 `http://127.0.0.1:18002/login/`，用 `staging_teacher_a_20261018` 与用户私存临时密码登录；预期自动到“修改密码”页面。两个浏览器仍共用 Windows 本地 18002 SSH 隧道，不需重复开启。该首次登录验证尚未现场执行。

**首次登录现场结果（用户提供，2026-10-18）：**已进入“修改密码”页面。下一步在同一普通教师会话里填写旧临时密码及两次新测试密码，点击“保存新密码”；预期进入首页并有密码修改成功提示。只有收到用户反馈后才记为实际改密通过；不索取或记录密码。

**首次改密现场结果（用户提供，2026-10-18）：**普通教师账号已返回首页且看到了成功提示。下一步在同一普通教师浏览器会话手动打开 `http://127.0.0.1:18002/members/`；应返回 403/禁止访问，不展示账号管理数据。此直接访问检查尚待用户执行。管理者浏览器会话不用于此检查，避免把不同账号结果混淆。

**管理拒绝现场结果（用户提供，2026-10-18）：**普通教师直接访问 `/members/` 显示 403/禁止访问。下一步仍在此普通教师浏览器会话中手动访问 `http://127.0.0.1:18002/materials/1/download/`；这是另一虚构测试账号的私有资料下载路径，预期 404 且无文件下载。此资料隔离浏览器检查尚待用户执行；若有下载则停止后续验收并反馈，不上传文件。

**资料下载隔离现场结果（用户提供，2026-10-18）：**普通教师访问另一虚构账号的资料 1 下载地址显示 404。下一步同一普通教师会话手动打开 `http://127.0.0.1:18002/worksheets/1/`，预期 404 而非作业预览。这是预发布环境的虚构记录；作业详情检查尚待用户执行。

**作业详情隔离现场结果（用户提供，2026-10-18）：**普通教师访问另一虚构账号作业 1 的详情显示 404。下一步同一会话手动打开 `http://127.0.0.1:18002/worksheets/1/v2/teacher.docx`，预期 404 且不下载教师答案版；该导出隔离尚待现场结果。

**教师 Word 导出隔离现场结果（用户提供，2026-10-18）：**普通教师请求另一虚构账号的第 2 版教师 Word 返回 404。下一步切到**管理者浏览器会话**，在成员账号页准确找到 `staging_teacher_a_20261018` 后点击该行“重置密码”，预期一次性新临时密码页；普通教师浏览器保持原会话，随后验证密码重置导致其旧会话失效。此管理操作只作用于虚构测试账号，尚待用户执行；不要触碰 `staging_preview_20261017` 或其他账号，不提交密码。

**重置与旧会话现场结果（用户提供，2026-10-18）：**该虚构普通账号出现新临时密码页，原浏览器会话失效。下一步在普通教师浏览器登录页仅用重置前已修改的测试密码尝试一次，预期提示用户名或密码不正确；此旧密码拒绝尚待现场验证。不要在聊天记录中输入密码，若意外登录成功则停止后续测试。

**重置后登录现场结果（用户提供，2026-10-18）：**旧测试密码被拒绝；新临时密码可登录且进入改密页。用户截图显示改密页被压成窄列，界面验收未通过，暂不在异常页面继续输入密码。助手经既有 Windows 本地隧道只读获取预发布 18002 的 CSS，返回旧哈希 `f51fd29e1bba4f30df3ea50e5e2d36e99862f2f5c7911860fa1f253125f126a5`，缺少源码已有的改密页布局规则。当前只修复隔离预发布共享静态卷与未来启动时的静态刷新命令；不重启服务、不修改数据库、私有文件或正式环境。

### 预发布改密页样式修复（待在 Ubuntu 执行）

**操作位置：**Windows PowerShell，项目目录 `D:\Projects\teacher-workbench`。现有 18002 浏览器隧道可保持打开。下面的脚本只在固定主机 `teacher-workbench`、用户 `huahua`、固定预发布目录/镜像/容器/端口与新旧 CSS 哈希全部吻合时执行；先在该目录备份旧 CSS 和 Compose。它将本机已写的预发布 Compose 命令改动应用到服务器目录，并更新正在提供的共享 CSS 文件。任何预检失败都停止，不改为手工覆盖或重复运行。

```powershell
cd D:\Projects\teacher-workbench
$check = ssh huahua@10.0.30.5 'test ! -e ~/repair_ubuntu_staging_phase2a_password_css.sh && test ! -L ~/repair_ubuntu_staging_phase2a_password_css.sh && echo STAGING_PASSWORD_CSS_TARGET_FREE'
if ($LASTEXITCODE -ne 0 -or $check -notcontains 'STAGING_PASSWORD_CSS_TARGET_FREE') { throw '服务器目标已占用或预检失败；停止并反馈' }
scp .\scripts\repair_ubuntu_staging_phase2a_password_css.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "10e0d2f61ff6255c6b118d34ea7707171ff2273b778af3c20fdcd00bbbcc7886  repair_ubuntu_staging_phase2a_password_css.sh" | sha256sum -c - && bash -n repair_ubuntu_staging_phase2a_password_css.sh && bash repair_ubuntu_staging_phase2a_password_css.sh'
if ($LASTEXITCODE -ne 0) { throw '修复脚本未完成；请反馈最后几行输出' }
```

**预期可见结果：**依次出现 `STAGING_PASSWORD_CSS_PREFLIGHT_OK`、`STAGING_PASSWORD_CSS_BACKUPS_READY`、`STAGING_PASSWORD_CSS_ATOMIC_REPLACE_OK`、`STAGING_PASSWORD_CSS_HTTP_AND_LOGIN_OK`、`STAGING_PASSWORD_LAYOUT_STATIC_FIXED`，最后回到 PowerShell。需要输入的是 SSH 与 sudo 的本机认证密码，终端不会要求输入工作台账号密码或 API Key。若出现其他错误、停留不动或缺少最终标记，保存非敏感输出反馈，不重复执行；脚本在备份后才改动，部分失败需按输出位置判断。

**验收方法：**收到最终标记后，助手再经已有隧道只读核对 18002 提供的 CSS 哈希；用户在普通教师浏览器对改密页按 `Ctrl+F5` 强制刷新，确认表单居中且旧密码、新密码、确认密码输入框宽度正常，再完成该虚构账号的改密。浏览器实际布局与提交成功只有收到用户反馈后才记为用户验收通过。此处为待执行步骤，不记录为服务器已修复。

**修复现场结果（用户提供，2026-10-18）：**用户返回 `STAGING_PASSWORD_CSS_PREFLIGHT_OK`、`STAGING_PASSWORD_CSS_BACKUPS_READY`、`STAGING_PASSWORD_CSS_ATOMIC_REPLACE_OK`、`STAGING_PASSWORD_CSS_HTTP_AND_LOGIN_OK`、`STAGING_PASSWORD_LAYOUT_STATIC_FIXED`，命令已结束。助手随后经已存在的 Windows 18002 隧道独立只读下载实际提供的 CSS，HTTP 200，SHA-256 为 `e69350c56233cc5adb34dd7ba2719abdb4378c17d90c85022f0ec8b317b9326b`，且存在改密页布局规则。服务器实际提供新版样式已经技术验证；浏览器缓存清理后的可见排版、再次改密提交及首页结果仍待用户实际验收。正式环境未更新。

**改密页复验现场结果（用户提供，2026-10-18）：**用户在普通教师浏览器反馈“排版正常了、保存后进入了首页”，记为该虚构账号重置后再次改密的页面验收通过。下一项在管理者浏览器的成员列表仅对 `staging_teacher_a_20261018` 点击“停用”，预期该行显示“已停用”；随后在该普通教师浏览器刷新首页，预期旧会话被要求重新登录。此停用与会话失效检查尚未执行；重新启用需下一项单独核对。

**停用现场结果（用户提供，2026-10-18）：**管理者列表显示 `staging_teacher_a_20261018`“已停用”；普通教师旧会话刷新后转到登录页，该账号不能登录。下一项仅在管理者浏览器对应行点击“重新启用并生成新密码”，预期出现只显示一次的新临时密码页；密码由用户私下保存，不发送聊天或截图。重新启用后的旧密码拒绝、临时密码登录及再次改密仍待后续验证。

**重新启用现场结果（用户提供，2026-10-18）：**用户反馈一次性新临时密码页已出现，新密码可登录并要求修改，保存后进入首页。该操作仅作用于预发布虚构账号 `staging_teacher_a_20261018`；没有上传或记录密码。2A 主要页面流程到此完成限定验收，后续阶段 2B 仅先在本机用虚构 Key 开发和验证，不把现有预发布站的模型调用闸门自动打开。

### 阶段 2B 本机密钥先行片（未在 Ubuntu 执行）

- **已执行：**本机虚拟环境安装固定版 `cryptography==50.0.2`；下载 Linux x86_64/Python 3.12 的 `cryptography`、`cffi`、`pycparser` 三个 wheel 到 Git 忽略的 `data/wheelhouse`，总数 21；按目标平台使用 `pip install --dry-run --no-index` 验证整份 `requirements.txt` 可由本地 wheel 解析。没有生成或上传真实主密钥。
- **已执行：**新迁移生成、专项虚构 Key 测试 8 项通过；完整 `workbench` 回归在最后轮换及输入处理修正前 59 项通过（3 项 PostgreSQL 专用跳过），修正后专项复测通过。新代码没有部署到 18002，预发布模型调用仍保持原有关闭状态。
- **部署前必须完成：**制作与当前 2A 预发布镜像/源码配对的新数据库与私有文件备份，并在隔离卷恢复；准备独立于代码和数据库备份的主密钥文件及离线保管方案；在新隔离容器验证 Linux 0600 权限、只读挂载、假 Key 保存/跨账号拒绝、正确密钥恢复与错误密钥安全失败。之后才考虑切换预发布 Web；正式环境与真实 Key 另行审批与验收。当前没有可直接照抄执行的 2B Ubuntu 升级命令。
- **仅已写、本机未在 Ubuntu 执行：**`scripts/prepare_ubuntu_staging_model_keyring.py` 固定只接受主机 `teacher-workbench`、用户 `huahua`，在项目外的新目录 `/home/huahua/teacher-workbench-staging-model-keyring` 生成随机 `v1.key`，不打印内容；文件若已存在则拒绝。脚本 SHA-256 `9c1d1f1af67fb03d880e1dbf826e8bf998289bcf46f202277de696f6bcf946d0`，本机 Python 语法与错误主机拒绝已检查。它尚未上传、运行或接入容器；不要单独运行此脚本代替完整的备份和恢复方案。

### 阶段 2B 当前预发布版的配对备份准备（待在 Ubuntu 执行）

**目标与边界：**先确认阶段 2A 正在运行的虚构预发布四服务、镜像、账号及现有作业，再制作数据库、私有文件、旧镜像和源码的配对备份，并在全新卷做独立恢复。以下操作仅限 Ubuntu 257，不碰正式站、NAS、真实 Key，也不触发模型请求。三个脚本在 Windows 本机通过 Bash 语法检查和错误主机拒绝；这不等于 Ubuntu 现场验证。旧版 2A 备份脚本针对上一镜像，不能用于当前账号状态。

**第 1 步，只读预检，操作位置：Windows PowerShell，项目目录。**复制粘贴逐行执行；第一条确认远端目标尚未存在，第二条上传审阅过的脚本，第三条校验 SHA-256 并执行。只上传脚本属于服务器文件写入，预检本身不修改容器、数据库、账号或密钥。需要输入 SSH/sudo 认证密码时在本机终端输入，不向聊天发送。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'test ! -e ~/check_ubuntu_staging_phase2b_readonly.sh && test ! -L ~/check_ubuntu_staging_phase2b_readonly.sh && echo STAGING_PHASE2B_CHECK_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '服务器目标已占用或连接失败；停止并反馈' }
scp .\scripts\check_ubuntu_staging_phase2b_readonly.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "a73ca7231b3d0511cc39d3e1e4306bb7237b7791c7c48dc5a6d2bdd17cbc399a  check_ubuntu_staging_phase2b_readonly.sh" | sha256sum -c - && bash -n check_ubuntu_staging_phase2b_readonly.sh && bash check_ubuntu_staging_phase2b_readonly.sh'
if ($LASTEXITCODE -ne 0) { throw '预检未通过；不要执行备份或恢复，请反馈最后几行' }
```

每一条若报错即停止，不继续下一条。**成功标准：**末尾依次出现 `STAGING_PHASE2B_SOURCE_CONFIG_OK`、`STAGING_PHASE2B_FOUR_SERVICES_MATCH_IMAGES`、`STAGING_PHASE2B_KEYRING_NOT_CREATED`、`STAGING_PHASE2B_EXISTING_FIXTURES_OK`、`STAGING_PHASE2B_STAGING_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_READONLY_PREFLIGHT_OK`，并回到 PowerShell。只反馈不含凭据的标记或错误；不发送 `.env.staging`、密码、Cookie 或密钥。

**第 2 步，配对备份：预检通过后才执行。**脚本 SHA-256 为 `60b6007bb5537a9b2cafbf31a5cd300abf3735b64ea8a681eafb89426adaa074`。它会短暂停止预发布 Web 和网关写入，打包 2A 虚构数据库、私有文件、旧镜像及白名单源码，再启动服务，确认 18002 登录页 HTTP 200，才标记备份完成；备份目录权限 0700，文件 0600。不删除卷。若脚本未输出最终完成标记，需先检查服务恢复情况，不重复执行或继续恢复。

**第 3 步，独立恢复：只有第 2 步拿到完整备份目录后才执行。**脚本 SHA-256 为 `999ad7fcd58b0c073ab40441bb03d51c8e1bef4ffc058cb4f4713ec830abb87c`。它验证备份哈希，在新命名网络、数据库卷和私有文件卷恢复虚构内容，不开放端口；检查两个普通账号、既有第 2 版草稿与跨账号 404，最后停止恢复用数据库/Redis 容器并保留卷供审计。成功标记是 `STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`；恢复失败不得推进新镜像或创建主密钥。

**2026-10-20 第 1 步现场结果（用户终端输出）：**`STAGING_PHASE2B_FOUR_SERVICES_MATCH_IMAGES`、`STAGING_PHASE2B_KEYRING_NOT_CREATED`、`STAGING_PHASE2B_EXISTING_FIXTURES_OK`、`STAGING_PHASE2B_STAGING_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_READONLY_PREFLIGHT_OK`。由脚本最终标记推知前置的配置检查也通过；该行未见于用户摘录。按脚本控制流，只读预检成功。用户尚未执行第 2 步备份或第 3 步恢复；不触发密钥创建或模型请求。

**第 2 步执行位置：Windows PowerShell，项目目录。**先检查服务器上目标脚本名未占用；上传后核对哈希和 Bash 语法，再运行。此脚本会短时停止预发布站 Web/网关并随后恢复，因此请在无需使用预发布网页时执行。完成后应同时出现 `STAGING_PHASE2B_WEB_RESTARTED_HTTP_200`、`STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED` 和 `STAGING_PHASE2B_PRE_BACKUP_DIR=...`。若缺任何一个或长时间停留，先反馈最后非敏感输出，不重试、不运行恢复脚本。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'test ! -e ~/backup_ubuntu_staging_phase2b_pre.sh && test ! -L ~/backup_ubuntu_staging_phase2b_pre.sh && echo STAGING_PHASE2B_BACKUP_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '备份脚本目标已占用或连接失败；停止并反馈' }
scp .\scripts\backup_ubuntu_staging_phase2b_pre.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "60b6007bb5537a9b2cafbf31a5cd300abf3735b64ea8a681eafb89426adaa074  backup_ubuntu_staging_phase2b_pre.sh" | sha256sum -c - && bash -n backup_ubuntu_staging_phase2b_pre.sh && bash backup_ubuntu_staging_phase2b_pre.sh'
if ($LASTEXITCODE -ne 0) { throw '备份未完成；不要重试或执行恢复，请反馈最后几行' }
```

**2026-10-20 第 2 步现场结果（用户终端输出）：**`STAGING_PHASE2B_POSTGRES_DUMP_READY`、`STAGING_PHASE2B_PRIVATE_ARCHIVE_READY`、`STAGING_PHASE2B_OLD_IMAGE_ARCHIVE_READY`、`STAGING_PHASE2B_SOURCE_ARCHIVE_READY`、`STAGING_PHASE2B_WEB_RESTARTED_HTTP_200`、`STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED`。备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-lESMk1Nj`。这是用户提供的技术结果，说明脚本完成备份校验并恢复网页；尚未独立恢复，也未从镜像归档重载。

**第 3 步执行位置：Windows PowerShell，项目目录。**脚本使用上述固定备份路径，先校验备份文件和旧镜像归档，再在新命名 Docker 网络、数据库卷和私有文件卷恢复；不开放端口，不修改当前预发布站数据库或私有卷。恢复容器在检查后停止，新卷保留。末尾需出现 `STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK`、`STAGING_PHASE2B_SOURCE_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 和 `STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`。若任何一步报错，不重复运行，也不继续创建主密钥，先反馈不含凭据的末尾输出。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'test ! -e ~/restore_ubuntu_staging_phase2b_pre.sh && test ! -L ~/restore_ubuntu_staging_phase2b_pre.sh && echo STAGING_PHASE2B_RESTORE_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '恢复脚本目标已占用或连接失败；停止并反馈' }
scp .\scripts\restore_ubuntu_staging_phase2b_pre.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "999ad7fcd58b0c073ab40441bb03d51c8e1bef4ffc058cb4f4713ec830abb87c  restore_ubuntu_staging_phase2b_pre.sh" | sha256sum -c - && bash -n restore_ubuntu_staging_phase2b_pre.sh && bash restore_ubuntu_staging_phase2b_pre.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-lESMk1Nj'
if ($LASTEXITCODE -ne 0) { throw '独立恢复未完成；停止并反馈最后几行' }
```

**2026-10-20 第 3 步现场结果（用户终端输出）：**`STAGING_PHASE2B_RESTORE_ISOLATION_PREFLIGHT_OK`、`STAGING_PHASE2B_RESTORE_POSTGRES_READY`、`STAGING_PHASE2B_RESTORE_PRIVATE_READY`、`STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK`、`STAGING_PHASE2B_SOURCE_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、最终 `STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`；目录 `/home/huahua/teacher-workbench-staging-phase2b-pre-restore-lESMk1Nj`。`Not Found` 两行是预期跨账号 404。恢复数据库/Redis 容器停止，新卷保留。下一阶段才构建 2B 新镜像并只在隔离恢复库迁移、用假 Key 检查；在线预发布站仍为 2A，AI 调用关闭。

### 阶段 2B 离线构建与假 Key 恢复

**顺序与边界：**先把单独命名的 2B 离线包和源码准备/构建脚本上传 Ubuntu 257，使用现存 `accounts-20261018` 镜像离线构建新镜像；这一步不创建主密钥、不迁移数据库、不切换网页。镜像构建已通过用户终端技术检查。之后才在已停止的 2A 恢复副本上生成随机主密钥、迁移、保存一条 `sk-fictional-` 假 Key，并将加密数据库与主密钥副本在另一个新卷恢复。在线预发布站和旧测试站持续保持原状，AI 模型调用关闭。假 Key 的同机主密钥副本只是演练材料，真实 Key 上线前仍需独立的离线保管与恢复方案。

**第 4 步，离线构建。操作位置：Windows PowerShell，项目目录。**先检查 Ubuntu 家目录中三个目标名均未被占用，上传后核对每个 SHA-256，再运行固定脚本。需要 SSH/sudo 认证时只在终端输入。离线包约 25 MB，镜像构建可能持续数分钟；脚本有 1200 秒上限和构建进度。成功时应出现 `STAGING_PHASE2B_SOURCE_AND_COMPOSE_READY`、`STAGING_PHASE2B_NEW_COMPOSE_GUARDS_OK`、`STAGING_PHASE2B_CRYPTOGRAPHY_IMPORT_OK`、`STAGING_PHASE2B_OLD_SITES_UNCHANGED_HTTP_200`、`STAGING_PHASE2B_OFFLINE_IMAGE_BUILT_NO_SWITCH`。如失败，不重复运行或手工覆盖新目录/镜像，先反馈非敏感输出。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && for f in teacher-workbench-staging-phase2b.tar.gz prepare_ubuntu_staging_phase2b_source.py build_ubuntu_staging_phase2b_isolated.sh; do test ! -e "$f" && test ! -L "$f" || exit 1; done && echo STAGING_PHASE2B_BUILD_TARGETS_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\data\deploy\teacher-workbench-staging-phase2b.tar.gz .\scripts\prepare_ubuntu_staging_phase2b_source.py .\scripts\build_ubuntu_staging_phase2b_isolated.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "b3558bd2cee54bc508772f065596b88aa3579f171b931ff7a711b04f0e18f0a8  teacher-workbench-staging-phase2b.tar.gz" | sha256sum -c - && echo "8726004b745144b21ca4dbe990584999d70ece431d9bae354fba7849261eac29  prepare_ubuntu_staging_phase2b_source.py" | sha256sum -c - && echo "c309f34d64850a2d4ea0d28273e66b72bdfe970ceaf099b9b3f93e40024178e9  build_ubuntu_staging_phase2b_isolated.sh" | sha256sum -c - && python3 -m py_compile prepare_ubuntu_staging_phase2b_source.py && bash -n build_ubuntu_staging_phase2b_isolated.sh && bash build_ubuntu_staging_phase2b_isolated.sh'
if ($LASTEXITCODE -ne 0) { throw '离线构建未完成；停止并反馈最后几行' }
```

**第 5 步，假 Key 恢复演练：只在第 4 步成功后执行。**上传并核对 `prepare_ubuntu_staging_model_keyring.py`（SHA-256 `9c1d1f1af67fb03d880e1dbf826e8bf998289bcf46f202277de696f6bcf946d0`）和 `verify_ubuntu_staging_phase2b_key_restore.sh`（SHA-256 `2c80c0c62a2627489ee02aabc84d863412431e404f551e69e2f0a490d0f7787d`）。脚本先生成只用于隔离预发布的随机主密钥，不显示其内容；把恢复副本迁移到 2B、跑虚构 Key 专项测试，再备份密文与主密钥副本并在另一个新卷验证正确/错误/缺失密钥结果。**不使用真实 API Key，也不向百炼发送请求。**实际执行命令在第 4 步现场成功后提供，避免对未知镜像状态提前写入。

**2026-10-20 第 4 步现场结果（用户终端输出）：**`STAGING_PHASE2B_CRYPTOGRAPHY_IMPORT_OK`、`STAGING_PHASE2B_OLD_SITES_UNCHANGED_HTTP_200`、`STAGING_PHASE2B_OFFLINE_IMAGE_BUILT_NO_SWITCH`；新目录 `/home/huahua/teacher-workbench-staging-phase2b-20261020`。这证明离线镜像构建及加密库导入通过，原站登录页当时仍可访问。未切换在线服务或迁移在线库；第 5 步仍待执行。

**第 5 步执行命令（待执行）。操作位置：Windows PowerShell，项目目录。**本机复核该脚本 Bash 语法、8 段内嵌 Python 语法、LF 行尾、错误主机拒绝及固定哈希均通过。先检查 Ubuntu 家目录两个目标文件不存在，再上传并在 Ubuntu 校验哈希和语法；最后运行一次。脚本会短暂启动已停止的隔离恢复数据库，并在退出时停止它们；不访问在线数据库。若失败，**不要重跑、手动删除主密钥或清理卷**，只反馈最后的非敏感标记；程序遇到已存在目录会拒绝覆盖。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && for f in prepare_ubuntu_staging_model_keyring.py verify_ubuntu_staging_phase2b_key_restore.sh; do test ! -e "$f" && test ! -L "$f" || exit 1; done && echo STAGING_PHASE2B_KEY_SCRIPT_TARGETS_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\scripts\prepare_ubuntu_staging_model_keyring.py .\scripts\verify_ubuntu_staging_phase2b_key_restore.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "9c1d1f1af67fb03d880e1dbf826e8bf998289bcf46f202277de696f6bcf946d0  prepare_ubuntu_staging_model_keyring.py" | sha256sum -c - && echo "2c80c0c62a2627489ee02aabc84d863412431e404f551e69e2f0a490d0f7787d  verify_ubuntu_staging_phase2b_key_restore.sh" | sha256sum -c - && python3 -m py_compile prepare_ubuntu_staging_model_keyring.py && bash -n verify_ubuntu_staging_phase2b_key_restore.sh && bash verify_ubuntu_staging_phase2b_key_restore.sh'
if ($LASTEXITCODE -ne 0) { throw '隔离假 Key 恢复未完成；停止并反馈最后几行' }
```

**成功标准：**依次看到 `STAGING_PHASE2B_ISOLATED_MIGRATION_AND_TESTS_OK`、`STAGING_PHASE2B_FICTIONAL_ENCRYPTED_BACKUP_VERIFIED`、`STAGING_PHASE2B_CORRECT_KEY_RESTORE_OK`、`STAGING_PHASE2B_WRONG_KEY_FAILS_CLOSED`、`STAGING_PHASE2B_MISSING_KEY_FAILS_CLOSED`，以及最终 `STAGING_PHASE2B_FICTIONAL_KEY_RESTORE_VERIFIED_NO_ONLINE_SWITCH`。此成功仅证明同一 Ubuntu 主机的新卷虚构 Key 演练；不等于独立设备保管主密钥或允许录入真实 Key。

**2026-10-20 第 5 步现场结果（用户终端输出）：**上述迁移、9 项专项测试、虚构 Key 密文备份、正确/错误/缺失主密钥恢复全部出现成功标记，最终 `STAGING_PHASE2B_FICTIONAL_KEY_RESTORE_VERIFIED_NO_ONLINE_SWITCH`；私有恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-fictional-recovery-lESMk1Nj`。原预发布及旧测试站登录页当时 HTTP 200；在线站尚未切换。按脚本，已启动的隔离 DB/Redis 在退出前停止，原数据库及现有资料没有被脚本迁移。同机主密钥副本不是异机备份。

### 阶段 2B 预发布切换准备与回退

**当前状态：代码已写，本机静态检查通过；下列第 6 步尚未在 Ubuntu 执行。**在线预发布仍是阶段 2A。先重新备份当前 2A 数据与镜像并独立恢复，避免依赖数小时前的快照。新增包装脚本只调用 Ubuntu 上已经用过的 `backup_ubuntu_staging_phase2b_pre.sh` 与 `restore_ubuntu_staging_phase2b_pre.sh`，先核对它们的固定哈希；它会短暂停止预发布 Web/网关进行配对备份，并在新隔离卷检查恢复，原站随后继续运行。脚本输出新备份和新恢复目录，不自动切换 2B。失败时不要再次运行或手动删除卷，先反馈非敏感输出。旧备份 `backup-phase2b-pre-lESMk1Nj`、原恢复卷和假 Key 演练材料继续保留。

**第 6 步执行命令（待执行）。位置：Windows PowerShell，项目目录。**本机 `prepare_ubuntu_staging_phase2b_switch_snapshot.sh` SHA-256 为 `dccf3291ab1e286bf38b099b645711e35f0e51f205a771f8f06d158e7ba99f45`。先确认 Ubuntu 家目录目标名未占用，上传、核对哈希与 Bash 语法，然后运行一次。需要 sudo 时仅在本机终端输入密码。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e prepare_ubuntu_staging_phase2b_switch_snapshot.sh && test ! -L prepare_ubuntu_staging_phase2b_switch_snapshot.sh && echo STAGING_PHASE2B_SWITCH_SNAPSHOT_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\scripts\prepare_ubuntu_staging_phase2b_switch_snapshot.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "dccf3291ab1e286bf38b099b645711e35f0e51f205a771f8f06d158e7ba99f45  prepare_ubuntu_staging_phase2b_switch_snapshot.sh" | sha256sum -c - && bash -n prepare_ubuntu_staging_phase2b_switch_snapshot.sh && bash prepare_ubuntu_staging_phase2b_switch_snapshot.sh'
if ($LASTEXITCODE -ne 0) { throw '切换前新备份与独立恢复未完成；停止并反馈最后几行' }
```

**第 6 步成功标准：**输出 `STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED`、`STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`，以及最终 `STAGING_PHASE2B_FRESH_PRE_SWITCH_BACKUP_AND_RESTORE_OK` 与新的备份/恢复目录。此时在线站仍应是 2A，AI 关闭。用户返回这些标记后，再将具体新备份目录交给第 7 步切换脚本。

**第 7 步切换脚本已写、未执行：**`scripts/apply_ubuntu_staging_phase2b.sh` 仅接受第 6 步的新备份路径；先检查原镜像、只读主密钥挂载、恢复卷、两站登录页和在线旧迁移状态，在新恢复卷迁移并重跑 9 项虚构 Key 测试，然后才短暂停止预发布 Web/网关、向在线库应用只新增一张表的 `0005`、切换新镜像。上线后检查迁移、主密钥只读挂载、旧草稿和两站登录页；失败时自动尝试恢复旧 Web/网关。**代码回退不会自动撤销已应用的数据库迁移；新备份保留作数据恢复依据。**本机 Bash 语法、6 段内嵌 Python 语法、LF 与错误主机拒绝通过；Ubuntu Docker 行为和实际回退尚未测试。第 6 步成功并核对新路径后，才给出固定上传、哈希校验和执行命令。

**2026-10-20 第 6 步现场结果（用户终端输出）：**新备份返回 `STAGING_PHASE2B_PRE_BACKUP_FILES_VERIFIED`，目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-3D3OilvA`；新独立恢复返回 `STAGING_PHASE2B_RESTORE_ACCOUNTS_CONTENT_AND_ACCESS_OK`、`STAGING_PHASE2B_PRE_INDEPENDENT_RESTORE_VERIFIED`，目录 `/home/huahua/teacher-workbench-staging-phase2b-pre-restore-3D3OilvA`；最终 `STAGING_PHASE2B_FRESH_PRE_SWITCH_BACKUP_AND_RESTORE_OK`。原站登录页当时 HTTP 200，两条 `Not Found` 是预期跨账号 404。按脚本恢复容器已停止、卷保留，在线预发布仍为 2A。证据来自用户终端，助手未直接连接 Ubuntu。

**第 7 步执行命令（待执行）。位置：Windows PowerShell，项目目录。**本机 `scripts/apply_ubuntu_staging_phase2b.sh` SHA-256 为 `46f810e75b167e0976739198baf55e22097b2283e4c2048f339cb0b691b632a0`；经本机 Bash 语法、6 段 Python 语法、LF 和错误主机拒绝检查。脚本仅接受本次新备份路径，先在对应新恢复卷运行 2B 迁移、Django 检查和 9 项虚构 Key 测试；这些通过后才停止预发布 Web/网关、迁移在线预发布库并切换。若切换后检查失败，脚本尝试恢复旧 Web/网关；**已应用的新增表迁移不会自动撤销，数据备份与旧镜像仍保留**。脚本可能数分钟，期间预发布页面短暂不可用。若没有最终成功标记，切勿重复运行或手工回滚数据库，先反馈末尾非敏感输出和旧站/预发布登录页是否可打开。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e apply_ubuntu_staging_phase2b.sh && test ! -L apply_ubuntu_staging_phase2b.sh && echo STAGING_PHASE2B_SWITCH_SCRIPT_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\scripts\apply_ubuntu_staging_phase2b.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "46f810e75b167e0976739198baf55e22097b2283e4c2048f339cb0b691b632a0  apply_ubuntu_staging_phase2b.sh" | sha256sum -c - && bash -n apply_ubuntu_staging_phase2b.sh && bash apply_ubuntu_staging_phase2b.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-3D3OilvA'
if ($LASTEXITCODE -ne 0) { throw '预发布 2B 切换未完成；停止并反馈最后几行' }
```

**成功标准：**`STAGING_PHASE2B_SWITCH_PREFLIGHT_OK`、`STAGING_PHASE2B_FRESH_RESTORE_TESTS_OK`、`STAGING_PHASE2B_ONLINE_ADDITIVE_MIGRATION_OK`、`STAGING_PHASE2B_ONLINE_SCHEMA_KEYRING_AND_FIXTURE_OK`、`STAGING_PHASE2B_NEW_AND_OLD_TEST_LOGIN_HTTP_200`，最后 `STAGING_PHASE2B_DEPLOYED_FICTIONAL_KEYS_ONLY_AI_OFF`。完成这些技术检查后，还须用浏览器中的虚构教师账号验收模型配置页面与 Key 不回显；不录入真实 Key。

**2026-10-20 第 7 步现场结果（用户终端输出）：**末尾返回 `STAGING_PHASE2B_ONLINE_SCHEMA_KEYRING_AND_FIXTURE_OK`、`STAGING_PHASE2B_NEW_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_PHASE2B_DEPLOYED_FICTIONAL_KEYS_ONLY_AI_OFF`。按脚本控制流，新的恢复卷测试和在线新增表迁移先完成，Web/网关切换后核对新镜像、只读主密钥挂载、旧草稿与两个登录页。用户只贴末尾，前面的单独标记由最终标记推断；助手未直接登录 Ubuntu。新源码目录 `/home/huahua/teacher-workbench-staging-phase2b-20261020`，切换前备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-pre-3D3OilvA` 保留。故障回退未触发，也未现场验证。预发布现在只接受 `sk-fictional-` 虚构 Key，AI 调用关闭；下一步为用户浏览器验收。

**阶段 2B 浏览器验收第 1 组（原定步骤；后续已执行）：**保持 Windows→Ubuntu 的 18002 SSH 回环隧道，在普通虚构教师 `staging_teacher_a_20261018` 的浏览器会话打开 `http://127.0.0.1:18002/model-config/`。若本地 18002 连接拒绝，先在另一个 PowerShell 窗口运行 `ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5` 并保持该窗口打开。页面应见“我的模型配置”、可用的“保存配置”按钮，不应出现“服务端密钥保管尚未配置”。然后仅保存一条虚构配置：名称 `阶段2B虚构验收`，Base URL `https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`，模型 `qwen-flash`，Key `sk-fictional-stage2b-ui-123456`。保存后应显示“模型配置已保存；尚未启用模型调用。”；刷新页面，已保存列表应有名称、厂商、模型和“已保存 Key”，不得出现完整虚构 Key。页面只保存配置，不会发送模型请求；不填真实 Key。若保存按钮不可用、报错或 Key 回显，则停止后续步骤并反馈现象。后续再在不同账号会话核对隔离与管理员预配。

**2026-10-20 第 1 组用户浏览器结果：**用户反馈页面正常、虚构配置保存成功、刷新后 Key 隐藏；截图中仅有配置元数据和“已保存 Key”。第 1 组按用户实际验收通过记录，未据此推断管理员或其他普通教师的权限。

**阶段 2B 浏览器验收第 2 组（原定步骤；后续已执行）：**保持现有 18002 隧道，在单独的无痕窗口登录虚构管理员 `staging_manager_20261018`。先打开 `http://127.0.0.1:18002/model-config/`，确认管理员自己的列表不出现普通教师的 `阶段2B虚构验收`，也不显示其 Key。再从“成员账号管理”找到 `staging_teacher_a_20261018`，点击“预配模型配置”；只使用虚构数据另建一条：名称 `管理员预配虚构验收`，Base URL `https://ws-fictional123.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`，模型 `qwen-flash`，Key `sk-fictional-stage2b-manager-123456`。保存后确认页面不回显完整 Key；返回普通教师原窗口刷新 `/model-config/`，应看到本人原配置和管理员预配配置，均不显示完整 Key。任何意外可见、报错或回显时停止并反馈页面现象，不发送密码、Cookie 或真实 Key。此组只保存虚构配置，AI 调用保持关闭。

**2026-10-20 第 2 组用户浏览器结果：**用户回复三项均正常；记录为管理员本人列表隔离、虚构预配及教师刷新后可见两条配置且 Key 不回显的用户实际验收通过。尚未通过这组页面操作验证跨账号直接提交替换/删除的 404，后续技术测试与备份恢复分开记录。

### 阶段 2B 保存虚构配置后的配对备份与独立恢复（2026-10-20 准备，现场待执行）

仅针对 Ubuntu 257 的隔离预发布栈。新备份脚本要求已验收的两条虚构配置存在、在线镜像和只读主密钥挂载匹配、AI 关闭；临时停 Web/网关后保存数据库、私有资料、镜像和脱敏源码，主密钥副本存放在同一 Ubuntu 主机的另一私有目录。**两个目录均在同一台机器上；这不是异机或离线灾备，也不应将主密钥副本和数据库备份一起复制到 NAS。**备份失败会尝试重启应用；完成后要用全新隔离卷做恢复验收。程序不会发起模型请求，不能填写真实 Key。

**2026-10-20 第 1 次尝试未通过：**用户终端只返回容器内 Python `AssertionError`（第 11 行），未出现 `STAGING_2B_SNAPSHOT_PREFLIGHT_OK`。已对照脚本定位为“配置名称必须与示例文字完全一致”的断言；失败发生在创建备份目录、停 Web/网关及导出数据之前，**没有完成备份**。仅凭此报错不能判断实际保存的两条名称，也不能说明页面验收失败。原上传的 `backup_ubuntu_staging_phase2b_credentials.sh` 不再运行、不覆盖。

第 1 步修正版在自己的 **Windows PowerShell** 执行，成功后只反馈末尾非敏感标记和两个目录路径。新脚本改为核对指定教师至少两条配置、主密钥版本和虚构预发布开关，不再要求页面名称逐字匹配；恢复脚本也按实际恢复的配置检查。先核对 Ubuntu 家目录没有 **v2** 同名脚本，再上传并验证本地固定 SHA-256；若已存在就停止，不覆盖：

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e backup_ubuntu_staging_phase2b_credentials_v2.sh && test ! -L backup_ubuntu_staging_phase2b_credentials_v2.sh && echo STAGING_2B_BACKUP_V2_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\scripts\backup_ubuntu_staging_phase2b_credentials.sh huahua@10.0.30.5:backup_ubuntu_staging_phase2b_credentials_v2.sh
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "15f1a05afb3a11af649f85bdac99d27968687af88780b336d059b4fe8e9e39c5  backup_ubuntu_staging_phase2b_credentials_v2.sh" | sha256sum -c - && bash -n backup_ubuntu_staging_phase2b_credentials_v2.sh && bash backup_ubuntu_staging_phase2b_credentials_v2.sh'
if ($LASTEXITCODE -ne 0) { throw '预发布 2B 备份未完成；停止并反馈最后几行' }
```

预期出现 `STAGING_2B_SNAPSHOT_FICTIONAL_ROWS_READY count=...`、`STAGING_2B_PAIRED_FILES_VERIFIED`、`STAGING_2B_BACKUP_DIR=...`、`STAGING_2B_ESCROW_DIR=...`。`sudo` 可能在 Ubuntu 终端请求认证；密码输入不显示，不发送密码。**第 2 步恢复脚本已修正但暂不运行**，先用第 1 步实际返回的随机备份目录生成准确命令。恢复只使用单独的同机虚构主密钥副本，新建网络和卷，不覆盖在线栈；最终应出现 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK` 与 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`。恢复脚本 SHA-256 为 `a0a3e402d736dfa4dbbb37d965ed4b88180092c6d94ae70e311a5ba7104a3e22`，当前仅通过本机静态检查。

**2026-10-21 第 1 步现场结果（用户终端）：**返回 `STAGING_2B_SNAPSHOT_FICTIONAL_ROWS_READY count=2`、`STAGING_2B_WEB_RESTARTED_HTTP_200`、最终 `STAGING_2B_PAIRED_FILES_VERIFIED`。备份目录为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-X6F4w9bJ`，单独的同机虚构主密钥副本目录为 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-X6F4w9bJ`。按脚本顺序，数据库、私有文件、镜像与源码已停写归档并校验；助手未直连 Ubuntu 或读取内容。**第 2 步独立恢复仍待执行。**

第 2 步在自己的 **Windows PowerShell** 执行。脚本会检查上述两个目录的完成标记、权限和校验值，再使用全新隔离 Docker 网络/卷恢复虚构数据库及私有文件，用同机密钥副本核对可解密性和跨账号 404。它不覆盖在线预发布服务；结束时停止新建的恢复容器并保留卷。先确认 Ubuntu 家目录没有同名脚本，不覆盖旧文件：

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e restore_ubuntu_staging_phase2b_credentials.sh && test ! -L restore_ubuntu_staging_phase2b_credentials.sh && echo STAGING_2B_RESTORE_SCRIPT_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '目标已占用或连接失败；停止并反馈' }
scp .\scripts\restore_ubuntu_staging_phase2b_credentials.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "a0a3e402d736dfa4dbbb37d965ed4b88180092c6d94ae70e311a5ba7104a3e22  restore_ubuntu_staging_phase2b_credentials.sh" | sha256sum -c - && bash -n restore_ubuntu_staging_phase2b_credentials.sh && bash restore_ubuntu_staging_phase2b_credentials.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-X6F4w9bJ'
if ($LASTEXITCODE -ne 0) { throw '预发布 2B 独立恢复未完成；停止并反馈最后几行' }
```

成功标记为 `STAGING_2B_RESTORE_BACKUP_AND_KEY_VERIFIED`、`STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2B_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 和最终 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`。预期可能打印访问拒绝的 `Not Found`，它们须与最终成功标记一起判断。只反馈末尾非敏感标记和恢复目录；不发送密码、Key 或备份文件。

**2026-10-21 实际执行记录（用户终端输出）：**上述恢复返回 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、源站登录 HTTP 200、恢复容器停止且卷保留及最终 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-keys-restore-X6F4w9bJ`。四条 `Not Found` 分别对应跨账号资料、作业、模型配置替换和删除的预期 404。助手未登录 Ubuntu 或读取密钥。数据备份及密钥副本仍在同一 Ubuntu 主机；本次不构成 NAS/异机灾难恢复。

## 阶段 2B 虚构配置的数据备份转存 NAS（2026-10-21 准备，现场未执行）

**目标：**只转存已完成的 `backup-phase2b-keys-X6F4w9bJ` 数据备份到专用 NFS 共享，然后从 NAS 只读导入并在新 Docker 卷核对。`v1.key` 留在 Ubuntu 的独立私有密钥目录，不进入 NAS 转存清单。`KEY_SHA256` 只是用于匹配密钥副本的摘要。此流程只能证明“NAS 数据副本 + 原 Ubuntu 上的密钥副本”可恢复；不能证明 Ubuntu 主机丢失后可恢复。只使用虚构账号与假 Key；在线预发布服务、旧测试站、现有 NAS 备份均不应被覆盖。

**本机准备结果：**新增 `scripts/transfer_staging_phase2b_data_nas.py` 和 `scripts/restore_ubuntu_staging_phase2b_from_nas_data.sh`。Python AST、错误主机拒绝、转存清单不含 `v1.key`、清单非法路径拒绝、Shell 文件 LF 与恢复脚本和原已验收脚本的差异已核对；当前 Windows 环境没有 Bash，因此**新恢复脚本的 `bash -n` 及 Ubuntu 实际运行尚未验证**。上传时再用 Ubuntu `bash -n` 验证。脚本 SHA-256 分别为 `c7df9387af85ca0a60d4363593c2a51606925dd2fca89b155e7751bea5f4a2e4`、`f4c9abf04abddecd22396291ad012f35a3de7d1e1eee4b5af247a5680f482d98`。

**第 1 步：Windows PowerShell，仅复制虚构数据备份到 NAS。**先确认远端文件名未占用，再上传并检查哈希；脚本会验证本机已完成备份、挂载专用 `10.0.30.6:/teacher-workbench-backup`、在新 NAS 目录逐文件比较 SHA-256、卸载。不得上传或复制 `v1.key`、整个密钥目录或 `.env.staging`。执行完成后仅反馈 `STAGING_2B_NAS_DATA_COPY_DONE` 与 `NAS_BACKUP_NAME=...`；出现错误或未见 `NAS_MOUNT_CLEANED` 时停止，不重复运行。

**2026-10-21 第 1 步实际执行结果（用户终端）：**八项数据文件逐个校验成功，`NAS_MOUNT_CLEANED` 与 `STAGING_2B_NAS_DATA_COPY_DONE` 均出现；固定 NAS 目录名为 `staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b`。助手未直连 Ubuntu/NAS；第 2 步只读导入及第 3 步恢复尚未执行。

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e transfer_staging_phase2b_data_nas.py && test ! -L transfer_staging_phase2b_data_nas.py && echo STAGING_2B_NAS_SCRIPT_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '远端文件名已占用或连接失败；停止并反馈' }
scp .\scripts\transfer_staging_phase2b_data_nas.py huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 'cd ~ && echo "c7df9387af85ca0a60d4363593c2a51606925dd2fca89b155e7751bea5f4a2e4  transfer_staging_phase2b_data_nas.py" | sha256sum -c - && sudo -v && sudo -n python3 transfer_staging_phase2b_data_nas.py copy'
if ($LASTEXITCODE -ne 0) { throw 'NAS 虚构数据转存未完成；停止并反馈最后几行' }
```

**第 2 步：等待第 1 步返回准确的新目录名后再填入。**仍在 Windows PowerShell 通过 SSH 运行同一个已上传脚本的 `import` 模式；它只读挂载 NFS、验证 NAS 与原始双重清单，导入 Ubuntu 家目录下新的 0700 私有目录并卸载。这里的 `<NAS_BACKUP_NAME>` 是第 1 步输出的完整目录名，不能把尖括号原样复制执行。成功标记为 `STAGING_2B_NAS_DATA_IMPORT_DONE`、`NAS_LOCAL_IMPORT_DIR=...` 和 `NAS_MOUNT_CLEANED`。**现场尚未执行。**

**2026-10-21 第 2 步实际执行结果（用户终端）：**十个文件逐项导入校验成功，`NAS_MOUNT_CLEANED` 和 `STAGING_2B_NAS_DATA_IMPORT_DONE` 均出现；本机新私有目录为 `/home/huahua/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b`。助手未直连 Ubuntu/NAS；第 3 步来源新卷恢复尚未执行。

```powershell
cd D:\Projects\teacher-workbench
$nasName = Read-Host '输入第 1 步返回的 NAS_BACKUP_NAME'
if ($nasName -cnotmatch '^staging-phase2b-data-X6F4w9bJ-[0-9a-f]{12}$') { throw 'NAS 目录名格式不符；停止' }
ssh -t huahua@10.0.30.5 "cd ~ && echo 'c7df9387af85ca0a60d4363593c2a51606925dd2fca89b155e7751bea5f4a2e4  transfer_staging_phase2b_data_nas.py' | sha256sum -c - && sudo -v && sudo -n python3 transfer_staging_phase2b_data_nas.py import $nasName"
if ($LASTEXITCODE -ne 0) { throw 'NAS 虚构数据只读导入未完成；停止并反馈最后几行' }
```

**第 3 步：第 2 步成功后再运行。**上传 `restore_ubuntu_staging_phase2b_from_nas_data.sh`，先在 Ubuntu 检查 SHA-256 与 `bash -n`，再以第 2 步的 `NAS_LOCAL_IMPORT_DIR` 为唯一参数；脚本使用原 Ubuntu 的同机 `keyring-X6F4w9bJ`，建立全新隔离网络与卷，核对两条虚构配置、原资料及跨账号 404，最后停止恢复容器并保留卷。成功标记为 `STAGING_2B_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。**现场尚未执行；原 Ubuntu 主密钥副本仍是单点，不能作为异机或离线密钥恢复的验收。**

**2026-10-21 第 3 步实际执行结果（用户终端）：**返回 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、原站登录 HTTP 200、恢复容器停止且卷保留和最终 `STAGING_2B_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`；恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-nas-restore-c9e68dfefb4b`。四条 `Not Found` 为预期跨账号 404。按脚本，恢复读取 NAS 导入的数据，但主密钥取自原 Ubuntu 同机副本；本次不构成异机/离线密钥灾备。助手未直连服务器或读取密钥。

```powershell
cd D:\Projects\teacher-workbench
$nasName = Read-Host '再次输入第 1 步返回的 NAS_BACKUP_NAME'
if ($nasName -cnotmatch '^staging-phase2b-data-X6F4w9bJ-[0-9a-f]{12}$') { throw 'NAS 目录名格式不符；停止' }
$importDir = "/home/huahua/teacher-workbench-nas-import-$nasName"
ssh huahua@10.0.30.5 'cd ~ && test ! -e restore_ubuntu_staging_phase2b_from_nas_data.sh && test ! -L restore_ubuntu_staging_phase2b_from_nas_data.sh && echo STAGING_2B_NAS_RESTORE_SCRIPT_TARGET_FREE'
if ($LASTEXITCODE -ne 0) { throw '远端文件名已占用或连接失败；停止并反馈' }
scp .\scripts\restore_ubuntu_staging_phase2b_from_nas_data.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '上传失败；停止并反馈' }
ssh -t huahua@10.0.30.5 "cd ~ && echo 'f4c9abf04abddecd22396291ad012f35a3de7d1e1eee4b5af247a5680f482d98  restore_ubuntu_staging_phase2b_from_nas_data.sh' | sha256sum -c - && bash -n restore_ubuntu_staging_phase2b_from_nas_data.sh && bash restore_ubuntu_staging_phase2b_from_nas_data.sh $importDir"
if ($LASTEXITCODE -ne 0) { throw 'NAS 来源独立恢复未完成；停止并反馈最后几行' }
```

## 阶段 2B 虚构主密钥的离线 U 盘恢复包（2026-10-21，代码已写；现场未执行）

用户已选择本人保管的离线 U 盘。完整四阶段及边界见 [offline-key-recovery.md](offline-key-recovery.md)。当前仅进行**第 1 阶段：在 Ubuntu 257 导出虚构主密钥的加密包**。此步骤会读取已有虚构 `v1.key`，只在禁网容器里加密到新的私有目录；不会读取真实教学资料或触发模型。先在 **Windows PowerShell，项目目录 `D:\Projects\teacher-workbench`** 执行：

```powershell
cd D:\Projects\teacher-workbench
ssh huahua@10.0.30.5 'cd ~ && test ! -e offline_model_key_package.py && test ! -L offline_model_key_package.py && test ! -e export_ubuntu_staging_offline_key_package.sh && test ! -L export_ubuntu_staging_offline_key_package.sh && echo OFFLINE_KEY_SCRIPT_TARGETS_FREE'
if ($LASTEXITCODE -ne 0) { throw '远端脚本名已占用或连接失败；停止并反馈' }
scp .\scripts\offline_model_key_package.py .\scripts\export_ubuntu_staging_offline_key_package.sh huahua@10.0.30.5:
if ($LASTEXITCODE -ne 0) { throw '脚本上传失败；停止并反馈' }
ssh -tt huahua@10.0.30.5 'cd ~ && chmod 600 offline_model_key_package.py && echo "f37d85043c9485030dd1c7626d3edb49c7f0cb03ee5b0104aa1f14d8b6966ce0  offline_model_key_package.py" | sha256sum -c - && echo "910df3faed425165431293544bbe607337db8c9e0c206ad797b196feeaf96ae6  export_ubuntu_staging_offline_key_package.sh" | sha256sum -c - && bash -n export_ubuntu_staging_offline_key_package.sh && bash export_ubuntu_staging_offline_key_package.sh'
if ($LASTEXITCODE -ne 0) { throw '离线加密包导出未完成；停止并反馈最后几行非敏感输出' }
```

预期先出现两项 `OK`、`OFFLINE_KEY_EXPORT_PREFLIGHT_OK`，然后终端提示输入两次独立的长口令（输入不显示）；完成后出现 `OFFLINE_KEY_ENCRYPTED_EXPORT_READY`、`OFFLINE_KEY_PACKAGE_PATH=...`、`OFFLINE_KEY_PACKAGE_SHA256=...`。**不要把口令、`v1.key`、加密包内容或原始文件上传聊天；只反馈最终三个标记和 SHA-256。**若未见最终标记，停止；已有新目录不应重复覆盖。U 盘盘符及复制命令待导出结果确认后提供，解密与 NAS 配对恢复脚本当前未上传或执行。

**2026-10-21 首次现场尝试（用户终端）：**源站登录 HTTP 200、导出预检通过，交互输入后返回 `PASSPHRASE_TOO_SHORT`，脚本非零退出。口令长度校验先于加密和包写入；未生成加密包，可能留下一处空的随机私有目录。已上传脚本不用重传，重试只运行下面的哈希/语法检查与导出命令；脚本每次使用新的随机目录，不覆盖上次目录。口令至少 20 字符，建议使用独立的较长随机口令；不要把口令写入 PowerShell 命令或聊天。

```powershell
ssh -tt huahua@10.0.30.5 'cd ~ && echo "f37d85043c9485030dd1c7626d3edb49c7f0cb03ee5b0104aa1f14d8b6966ce0  offline_model_key_package.py" | sha256sum -c - && echo "910df3faed425165431293544bbe607337db8c9e0c206ad797b196feeaf96ae6  export_ubuntu_staging_offline_key_package.sh" | sha256sum -c - && bash -n export_ubuntu_staging_offline_key_package.sh && bash export_ubuntu_staging_offline_key_package.sh'
if ($LASTEXITCODE -ne 0) { throw '离线加密包导出仍未完成；停止并反馈最后几行非敏感输出' }
```

**2026-10-21 第二次导出现场结果（用户终端）：**`OFFLINE_KEY_PACKAGE_CREATED_ENCRYPTED_ONLY`、包结构检查与最终 `OFFLINE_KEY_ENCRYPTED_EXPORT_READY` 通过；包路径为 `/home/huahua/teacher-workbench-staging-offline-key-packages/package-X0ad1NB4/teacher-workbench-staging-model-key-v1.json`，两次 SHA-256 同为 `969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc`。助手未读取包或口令。**下一步仅把单个加密文件直接复制到可移动 U 盘并核对摘要**；未执行 U 盘返回、解密或 NAS 配对恢复。

**第一次 U 盘复制说明已废止，不要再运行其逐行命令。**用户将卷标“U盘”误当成盘符 `U:`；盘符检查失败后继续逐行运行，仍启动了 `scp`。当前本机只读显示实际可移动盘为 `E:\`（卷标“U盘”）；先由用户在原 PowerShell 窗口按 Ctrl+C，确认 `scp` 已停止，并核对项目目录未误落加密 JSON。此前未得到任何 U 盘校验成功标记。

**随后只读复查与用户确认：**`scp` 已结束，项目根目录及目标 U 盘子目录均无加密 JSON；`E:\` 为可移动盘、当前卷标“huahua”。用户明确回复“是的”，确认这就是打算用于离线备份的 U 盘。下方脚本块已按当前卷标修订，执行时还会再次核对设备类型与卷标。

确认停止后，在 **Windows PowerShell** 将以下包含 `& {` 和末尾 `}` 的**整块**粘贴并执行。所有检查都在同一脚本块内，失败会中止后续复制；目标盘固定为当前读到的 `E:\`，再次核对可移动类型和卷标。若 U 盘盘符或卷标已变化，停止反馈，不要自行改写命令。目标目录已存在时不覆盖。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $expected = '969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc'
    if (Get-Process scp -ErrorAction SilentlyContinue) { throw '仍有 scp 进程；先在原窗口按 Ctrl+C' }
    $accidental = 'D:\Projects\teacher-workbench\teacher-workbench-staging-model-key-v1.json'
    if (Test-Path -LiteralPath $accidental) { throw '项目目录出现加密文件；先停止并核对，不能继续复制' }
    $usbRoot = 'E:\'
    $usb = [System.IO.DriveInfo]::new($usbRoot)
    if (-not $usb.IsReady -or $usb.DriveType -ne [System.IO.DriveType]::Removable -or $usb.VolumeLabel -ne 'huahua') {
        throw 'E 盘不是当前核对的可移动 U 盘；停止'
    }
    $usbDir = Join-Path $usbRoot 'teacher-workbench-offline-key-X0ad1NB4'
    if (Test-Path -LiteralPath $usbDir) { throw 'U 盘目标目录已存在；停止，避免覆盖' }
    New-Item -ItemType Directory -Path $usbDir | Out-Null
    Push-Location -LiteralPath $usbDir
    try {
        scp 'huahua@10.0.30.5:/home/huahua/teacher-workbench-staging-offline-key-packages/package-X0ad1NB4/teacher-workbench-staging-model-key-v1.json' .
        if ($LASTEXITCODE -ne 0) { throw '加密包复制到 U 盘失败；停止' }
    } finally { Pop-Location }
    $usbFile = Join-Path $usbDir 'teacher-workbench-staging-model-key-v1.json'
    $actual = (Get-FileHash -LiteralPath $usbFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $expected) { throw 'U 盘副本 SHA-256 不符；停止' }
    Write-Output 'USB_ENCRYPTED_PACKAGE_SHA256_OK'
    Write-Output "USB_PACKAGE_PATH=$usbFile"
}
```

成功时只反馈 `USB_ENCRYPTED_PACKAGE_SHA256_OK` 和 U 盘路径；**不要发送文件内容或口令**。随后在 Windows 中安全弹出 U 盘，保持离线。重新接入并从 U 盘带回 Ubuntu 的恢复验证命令将在此项通过后提供。

**2026-10-21 修订后的复制现场技术结果（用户终端及本机只读检查）：**用户返回 `USB_ENCRYPTED_PACKAGE_SHA256_OK`、目标 `E:\teacher-workbench-offline-key-X0ad1NB4\teacher-workbench-staging-model-key-v1.json`；助手只读检查该可移动盘卷标“huahua”、文件 349 字节、SHA-256 与 Ubuntu 导出值一致。此时 U 盘仍连接，尚未证明物理重新插入后的可读性。下一项用户只需在 Windows 安全弹出、拔下并重新插入，然后告知助手；助手将做只读摘要复核，不需要用户重新复制或发送文件内容。

### 物理重插后返回 Ubuntu（已现场执行）

**2026-10-21 用户报告已重新插入，本机只读复核通过：**`E:\` 仍为可移动盘、卷标“huahua”，加密包 349 字节，SHA-256 与导出值一致。物理操作本身由用户报告。现在可以运行下面**整块** PowerShell。它只取唯一一个持有正确哈希加密包的可移动盘，在 Ubuntu 家目录创建新的 0700 随机目录，仅复制该加密 JSON，远端设为 0600 并再次比对 SHA-256。失败不自动删除目标，避免误覆盖；如遇错误先反馈。口令与明文密钥不在命令中。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $expected = '969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc'
    $relative = 'teacher-workbench-offline-key-X0ad1NB4\teacher-workbench-staging-model-key-v1.json'
    $matches = @(
        [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.IsReady -and $_.DriveType -eq [System.IO.DriveType]::Removable } |
            ForEach-Object {
                $path = Join-Path $_.Name $relative
                if ((Test-Path -LiteralPath $path) -and
                    (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expected) {
                    [pscustomobject]@{ Path = $path }
                }
            }
    )
    if ($matches.Count -ne 1) { throw '没有找到唯一的可移动 U 盘加密包；停止' }
    $usbFile = $matches[0].Path
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
    $remoteName = "teacher-workbench-staging-offline-key-return-$suffix"
    $remoteDir = "/home/huahua/$remoteName"
    $remoteFile = "$remoteDir/teacher-workbench-staging-model-key-v1.json"
    ssh huahua@10.0.30.5 "cd /home/huahua && umask 077 && test ! -e $remoteName && test ! -L $remoteName && mkdir -m 700 $remoteName"
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 私有返回目录创建失败；停止' }
    Push-Location -LiteralPath (Split-Path -Parent $usbFile)
    try {
        scp '.\teacher-workbench-staging-model-key-v1.json' ("huahua@10.0.30.5:{0}" -f $remoteFile)
        if ($LASTEXITCODE -ne 0) { throw '从 U 盘返回 Ubuntu 的复制失败；停止' }
    } finally { Pop-Location }
    $hashLine = [string](ssh huahua@10.0.30.5 "cd /home/huahua && chmod 600 $remoteName/teacher-workbench-staging-model-key-v1.json && sha256sum $remoteName/teacher-workbench-staging-model-key-v1.json" | Select-Object -Last 1)
    if ($LASTEXITCODE -ne 0 -or $hashLine -notmatch ("^" + $expected + "\s+")) { throw 'Ubuntu 返回文件 SHA-256 不符；停止' }
    Write-Output 'USB_RETURN_FILE_SHA256_OK'
    Write-Output "USB_RETURN_PACKAGE=$remoteFile"
}
```

最终只反馈 `USB_RETURN_FILE_SHA256_OK` 和返回路径；不发送加密包内容或口令。下一阶段才运行独立解密脚本，且必须用该返回目录作为输入，不能直接使用原 Ubuntu 在线密钥或同机 escrow。

**2026-10-21 用户现场终端结果：**`USB_RETURN_FILE_SHA256_OK`，返回路径 `/home/huahua/teacher-workbench-staging-offline-key-return-ddfae9d5abc1/teacher-workbench-staging-model-key-v1.json`。此为用户提供的 Ubuntu 摘要结果，助手未直连；下面的独立解密命令尚未执行。

### 从 U 盘返回的包独立解密（首次失败；结果见安全重试）

在 Windows PowerShell 一次性运行整块命令。它先核对本地包装器 SHA-256、确认 Ubuntu 同名目标不存在，再只上传该脚本；Ubuntu 核对摘要和 Bash 语法后，以本次 U 盘返回的加密 JSON 运行。解锁口令仅在远端交互终端输入，不放在命令、项目文件或聊天。脚本会在新的 0700 目录生成 0600 的虚构主密钥，随后对比 NAS 导入数据中的 `KEY_SHA256`；不挂载在线密钥或同机 escrow，不进行模型调用。遇错停止并反馈非敏感输出，不要自行重跑或覆盖目标。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $local = 'D:\Projects\teacher-workbench\scripts\restore_ubuntu_staging_offline_key_package.sh'
    $scriptHash = '81161621daba92ad9e7410e194b951178232c70bb1a3a56a9f099b0f3c56a5b1'
    if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -cne $scriptHash) {
        throw '本地离线恢复脚本摘要不符；停止'
    }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e restore_ubuntu_staging_offline_key_package.sh && test ! -L restore_ubuntu_staging_offline_key_package.sh && test -f teacher-workbench-staging-offline-key-return-ddfae9d5abc1/teacher-workbench-staging-model-key-v1.json && echo OFFLINE_KEY_RESTORE_UPLOAD_PREFLIGHT_OK'
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 上传预检失败；停止' }
    scp $local 'huahua@10.0.30.5:/home/huahua/restore_ubuntu_staging_offline_key_package.sh'
    if ($LASTEXITCODE -ne 0) { throw '离线恢复脚本上传失败；停止' }
    ssh -tt huahua@10.0.30.5 "cd /home/huahua && chmod 600 restore_ubuntu_staging_offline_key_package.sh && echo '$scriptHash  restore_ubuntu_staging_offline_key_package.sh' | sha256sum -c - && bash -n restore_ubuntu_staging_offline_key_package.sh && bash restore_ubuntu_staging_offline_key_package.sh /home/huahua/teacher-workbench-staging-offline-key-return-ddfae9d5abc1/teacher-workbench-staging-model-key-v1.json 969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc"
    if ($LASTEXITCODE -ne 0) { throw 'U 盘返回包的独立解密未完成；停止并反馈末尾非敏感输出' }
}
```

成功标准：`OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA`、`OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED` 和 `OFFLINE_KEY_RECOVERED_DIR=...`。不要发送解锁口令、加密包或恢复出的 `v1.key` 内容。后续另行运行 NAS 数据隔离新卷恢复。

**2026-10-22 首次执行的用户现场结果：**容器已进入口令输入，随后输出 `PASSPHRASE_OR_PACKAGE_INVALID`，SSH 以非零退出；没有恢复成功标记。原脚本先建 0700 目标目录，然后才解密；失败时 Python 不写明文，但目录当前内容仍须现场核对。禁止原样重跑或删除目标。第二次成功导出的程序曾以当时口令自检，返回包 SHA-256 与导出值相同，因此首先核对是否输入了第二次成功导出的原口令。不要向助手透露口令。

### 仅在原失败目标为空时安全重试（已现场执行）

本地专用包装器 `scripts/retry_ubuntu_staging_offline_key_restore.sh` 已写，固定本次 U 盘返回包与 NAS 导入目录，检查本人所有的 0700 原目标目录**为空**，检查包、帮助程序及数据摘要，然后在禁网容器中再次交互解密。成功后只写原先预定位置的虚构 `v1.key`，核对 NAS `KEY_SHA256`。不会使用在线密钥或同机 escrow，也不会调用模型。用户在 Windows PowerShell 一次性运行下面整块；如未记住第二次成功导出时设置的口令，先不要执行，应另行计划重新导出新包。失败不自行重跑或清理。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $local = 'D:\Projects\teacher-workbench\scripts\retry_ubuntu_staging_offline_key_restore.sh'
    $scriptHash = '888e060364eb3455161cacec14813b52df3440f972f35756649d03c7fe6cea3f'
    if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -cne $scriptHash) {
        throw '本地安全重试脚本摘要不符；停止'
    }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e retry_ubuntu_staging_offline_key_restore.sh && test ! -L retry_ubuntu_staging_offline_key_restore.sh && echo OFFLINE_KEY_RETRY_UPLOAD_PREFLIGHT_OK'
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 安全重试上传预检失败；停止' }
    scp $local 'huahua@10.0.30.5:/home/huahua/retry_ubuntu_staging_offline_key_restore.sh'
    if ($LASTEXITCODE -ne 0) { throw '安全重试脚本上传失败；停止' }
    ssh -tt huahua@10.0.30.5 "cd /home/huahua && chmod 600 retry_ubuntu_staging_offline_key_restore.sh && echo '$scriptHash  retry_ubuntu_staging_offline_key_restore.sh' | sha256sum -c - && bash -n retry_ubuntu_staging_offline_key_restore.sh && bash retry_ubuntu_staging_offline_key_restore.sh"
    if ($LASTEXITCODE -ne 0) { throw '离线包安全重试未完成；停止并反馈末尾非敏感输出' }
}
```

成功标记为 `OFFLINE_KEY_RETRY_EMPTY_TARGET_AND_DATA_VERIFIED`、`OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA`、`OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED`。如果再次 `PASSPHRASE_OR_PACKAGE_INVALID`，不要继续猜测或泄露口令；后续可从仍在的原 Ubuntu 在线虚构密钥重新生成一份**新的**加密包，并重新执行 U 盘往返验收。

**2026-10-22 用户现场安全重试通过：**`OFFLINE_KEY_RESTORED_TO_NEW_DIRECTORY`、`OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA`、`OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1`。这是用户终端输出，助手未直连 Ubuntu 或读取口令与密钥。下列 NAS 数据配对隔离恢复尚未运行。

### 用 U 盘恢复密钥与 NAS 导入数据做隔离新卷恢复（已现场执行）

在 Windows PowerShell 一次性运行整块。先检查本地脚本 SHA-256、Ubuntu 上传目标不存在，再上传、核对哈希和 Bash 语法。恢复脚本读取固定 NAS 导入目录及上一步新恢复的虚构 `v1.key`；预检后创建独立 Docker 网络、数据库卷和私有文件卷，用随机测试数据库密码恢复并核对两条虚构配置、资料访问及跨账号 404。完成时停止恢复容器但保留新卷；在线预发布不切换，不调用模型。此过程可能数分钟，看到 PostgreSQL 等待日志时不要关闭窗口。失败停止并反馈末尾非敏感输出，不要自行清卷或重跑。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $local = 'D:\Projects\teacher-workbench\scripts\restore_ubuntu_staging_phase2b_from_usb_key.sh'
    $scriptHash = 'add286eeb7978ba928f48ece3cc3f66041db61079adbf63ff581c23d822e67f8'
    if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -cne $scriptHash) {
        throw '本地 NAS 配对恢复脚本摘要不符；停止'
    }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e restore_ubuntu_staging_phase2b_from_usb_key.sh && test ! -L restore_ubuntu_staging_phase2b_from_usb_key.sh && echo STAGING_2B_USB_RESTORE_UPLOAD_PREFLIGHT_OK'
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 上传预检失败；停止' }
    scp $local 'huahua@10.0.30.5:/home/huahua/restore_ubuntu_staging_phase2b_from_usb_key.sh'
    if ($LASTEXITCODE -ne 0) { throw 'NAS 配对恢复脚本上传失败；停止' }
    ssh -tt huahua@10.0.30.5 "cd /home/huahua && chmod 600 restore_ubuntu_staging_phase2b_from_usb_key.sh && echo '$scriptHash  restore_ubuntu_staging_phase2b_from_usb_key.sh' | sha256sum -c - && bash -n restore_ubuntu_staging_phase2b_from_usb_key.sh && bash restore_ubuntu_staging_phase2b_from_usb_key.sh /home/huahua/teacher-workbench-nas-import-staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b /home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1"
    if ($LASTEXITCODE -ne 0) { throw 'U 盘密钥与 NAS 数据的隔离恢复未完成；停止并反馈末尾非敏感输出' }
}
```

成功标记 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2B_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_2B_USB_KEY_NAS_DATA_RESTORE_VERIFIED`。四条 `Not Found` 是预期的跨账号 404；若无最终成功标记则不能按通过记录。

**2026-10-22 用户现场技术结果：**上述隔离恢复依次返回源登录 HTTP 200、隔离预检、PostgreSQL/私有文件恢复、`STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、恢复后源预发布登录 HTTP 200、恢复容器停止且新卷保留，最终 `STAGING_2B_USB_KEY_NAS_DATA_RESTORE_VERIFIED`。目录 `/home/huahua/teacher-workbench-staging-phase2b-usb-restore-ddfae9d5abc1`。四条 `Not Found` 是脚本故意测试的跨账号 404。此为用户终端输出，助手未直连；无需重跑或清除卷。离线 U 盘加密包和口令分别保管，勿将恢复出的明文 `v1.key` 复制到项目、聊天或 NAS 数据备份。

### 阶段 2C 本机代码边界（2026-10-22，未部署）

本机新增 `0006`、`0007` 数据库迁移及调用次数页/服务。**尚未对 Ubuntu 或预发布执行迁移或切换**，也没有新的付费调用。后续若准备预发布部署，先锁定源码/镜像版本，重新完成对应数据库与私有文件的配对备份和独立恢复，再在隔离副本验证迁移、既有账号/资料及权限；镜像回退不能撤销数据库迁移。预留状态的进程故障清理和任务执行接线完成前，2C 页面只能作额度设置试验，不对外宣称具有线上费用控制能力。

**2026-10-22 本机后续代码（未部署）：**新增 `0008` 可选成员模式/配置字段，以及只接受显式假接口的独立任务执行器；现有进程级执行器拒绝成员模式。调用记录增加预留时额度快照；预留超时和发送后结果丢失的保守清理函数已通过本机测试。清理函数目前没有定时任务或远端命令包装器，不会自行扫描线上任务。后续预发布部署前仍须完成成员页面入口、真实接口适配的独立安全验收和新配对备份/恢复演练；不能把本机假接口成功视为已启用线上额度限制。

**2026-10-22 本机第三片（未部署）：**成员页面选择本人配置、按任务模式分流的队列入口、百炼北京兼容接口适配已写；默认 `AI_MEMBER_TASKS_ENABLED=0`，且只有同时显式设置 `AI_ENABLED=1` 才可启用。现有独立预发布 Compose 仍把 `AI_ENABLED` 设为 `0`，本轮未改配置、未上传或迁移。35 项专项与 97 项完整本机回归通过，后者有 3 项 PostgreSQL 专用跳过；本机假 HTTP 测试没有读取实际 Key 或联网。**部署前**须用虚构账号在隔离 PostgreSQL 复核并发额度、迁移和旧资料访问；重新做数据库、私有文件、主密钥版本与应用镜像的配对备份和新卷独立恢复。镜像回退不能撤销 `0006`～`0008` 的数据库迁移；不能把调用次数当成厂商金额上限。

**PostgreSQL 并发测试待执行：**`workbench.tests_pg_call_gate` 已写为双线程争用一条虚构额度的 `TransactionTestCase`，不触发模型请求。本机 SQLite 单项执行按预期跳过。需在带新源码的隔离 PostgreSQL 测试库运行，并看到案例真正执行且通过；不能在在线预发布业务库运行测试命令，也不能把本机跳过结果写成通过。本轮没有连接 Ubuntu 或改动服务器。

### 阶段 2C 预发布只读预检（代码已写，Ubuntu 待执行）

Windows PowerShell 在 `D:\Projects\teacher-workbench` 执行以下**整块**。先检查本机脚本摘要和远端同名文件不存在，再上传到 Ubuntu 用户家目录，核对摘要与 Bash 语法后运行。脚本只读查看虚构预发布的当前 Compose、镜像、数据库迁移版本和新旧登录页；不读取 Key 或业务内容，不建数据库、不迁移、不调用模型。需要输入 SSH 和 `sudo` 密码时在终端输入，不发给助手。如果任一检查失败，停止并反馈末尾非敏感输出，不自行修改服务器状态。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $local = 'D:\Projects\teacher-workbench\scripts\check_ubuntu_staging_phase2c_readonly.sh'
    $scriptHash = '4cdafd55cce1d8a374d5c124343c31b6f74948e86d6c0e0ecc979939acb4af05'
    if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -cne $scriptHash) {
        throw '本地只读预检脚本摘要不符；停止'
    }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e check_ubuntu_staging_phase2c_readonly.sh && test ! -L check_ubuntu_staging_phase2c_readonly.sh && echo STAGING_2C_UPLOAD_PREFLIGHT_OK'
    if ($LASTEXITCODE -ne 0) { throw '远端上传位置不安全；停止' }
    scp $local 'huahua@10.0.30.5:/home/huahua/check_ubuntu_staging_phase2c_readonly.sh'
    if ($LASTEXITCODE -ne 0) { throw '只读预检脚本上传失败；停止' }
    ssh -tt huahua@10.0.30.5 "cd /home/huahua && chmod 600 check_ubuntu_staging_phase2c_readonly.sh && echo '$scriptHash  check_ubuntu_staging_phase2c_readonly.sh' | sha256sum -c - && bash -n check_ubuntu_staging_phase2c_readonly.sh && bash check_ubuntu_staging_phase2c_readonly.sh"
    if ($LASTEXITCODE -ne 0) { throw '2C 只读预检未完成；停止并反馈末尾非敏感输出' }
}
```

成功标准：末尾依次包含 `STAGING_2C_SOURCE_CONFIG_AI_OFF`、`STAGING_2C_FOUR_SERVICES_MATCH_IMAGES`、`STAGING_2C_ONLINE_SCHEMA_2B_AI_OFF`、`STAGING_2C_NEW_AND_OLD_LOGIN_HTTP_200`、`STAGING_2C_READONLY_PREFLIGHT_OK`。这些标记只证明当前预发布状态可供规划，不证明 2C 已部署或 PostgreSQL 并发测试通过。

**2026-10-22 用户现场进度：**上传 3221 字节、远端摘要检查 `check_ubuntu_staging_phase2c_readonly.sh: OK`，随后输出 `STAGING_2C_SOURCE_CONFIG_AI_OFF`，此后用户报告终端停在该处。脚本下一行为 `timeout 60s sudo -v`，属于本机终端的 sudo 身份验证；尚未得到后续四容器、数据库迁移与 HTTP 成功标记。需在原终端输入 sudo 密码并观察输出；超时或失败后停止并反馈，不重跑。

**同日中断结果与恢复顺序：**用户报告等待超过 60 秒没有新输出，无法在原窗口输入密码，随后 Ctrl+C。不能将此记为四服务或数据库核对通过。不要重跑上传块；远端脚本已存在且摘要检查 `OK`。先从**新的 Windows PowerShell 窗口**执行 `ssh -tt huahua@10.0.30.5`，看到 Ubuntu shell 提示符后在该 shell 单独执行 `sudo -v`。如果出现密码提示，在终端输入 Ubuntu sudo 密码（输入不回显）；成功时应返回 `huahua@teacher-workbench:~$` 一类提示符，无额外成功文本。若仍无法输入或 30 秒不返回，用 Ctrl+C 停止并反馈非敏感输出。只在这一步成功后，才从同一交互式 SSH shell 继续运行已上传且已核对摘要的脚本；后续命令另行给出。

**同日用户反馈：**新交互式 SSH 会话的 `sudo -v` 已返回 shell 提示符。下一步在**同一个 Ubuntu shell**执行：

```bash
cd /home/huahua && echo '4cdafd55cce1d8a374d5c124343c31b6f74948e86d6c0e0ecc979939acb4af05  check_ubuntu_staging_phase2c_readonly.sh' | sha256sum -c - && bash -n check_ubuntu_staging_phase2c_readonly.sh && bash check_ubuntu_staging_phase2c_readonly.sh
```

这会再次核对已上传脚本摘要后只读运行，不修改应用、数据库或密钥。成功须出现 `STAGING_2C_READONLY_PREFLIGHT_OK`；若失败，保留现场并反馈末尾非敏感输出，不重跑上传。

**2026-10-22 用户现场完成标记：**五项标记 `STAGING_2C_SOURCE_CONFIG_AI_OFF`、`STAGING_2C_FOUR_SERVICES_MATCH_IMAGES`、`STAGING_2C_ONLINE_SCHEMA_2B_AI_OFF`、`STAGING_2C_NEW_AND_OLD_LOGIN_HTTP_200`、`STAGING_2C_READONLY_PREFLIGHT_OK` 均出现。此处只完成对现有虚构预发布 2B 栈的只读盘点；后续独立 PostgreSQL 环境测试另行执行。助手未直连服务器。

### 阶段 2C 独立 PostgreSQL 专项测试（代码已写，Ubuntu 待执行）

本机 `scripts/build_staging_phase2c_pg_bundle.py` 从白名单生成离线源码包 `data/deploy/teacher-workbench-stage2c-pg-source.tar.gz`，74 个文件、64,064 字节，SHA-256 `36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303`；不含 `.env`、教学资料、数据库、备份、主密钥或 wheel。执行脚本 `scripts/verify_ubuntu_staging_phase2c_pg_isolated.sh` SHA-256 为 `6f4482e0684723cf8827cfc38169c0faf636dac9e553e7fb67e221e17fc3c3b9`，本机 Bash `-n`、LF、错误主机拒绝和内嵌 Python 语法检查通过。本机没有运行 Docker 测试。脚本只运行 1 项 PostgreSQL 并发、17 项额度和 8 项执行器专项；页面/假 HTTP 专项仍保留本机 SQLite 测试证据。

脚本会验证当前虚构预发布仍为已盘点的 2B 镜像，用该现有镜像启动一次性 Python 测试容器，**只读**挂载新的 2C 源码；创建新内部 Docker 网络和新 PostgreSQL 17 卷，不暴露宿主端口，不挂载在线数据库、文件卷、在线 `.env` 或主密钥。测试环境用随机密码和虚构账号，模型开关关闭。测试完成时停止隔离数据库，保留测试卷和私有目录以便核对；失败时也请求停止所建隔离容器，不清除卷或网络。**这仍是服务器上的新资源写入，不是只读预检；在线应用及业务数据库不切换、不迁移。**

**第 1 步：只上传并验证离线源码和执行脚本。**在 Windows PowerShell 运行下面整块。先核对本机两份 SHA-256、远端同名目标不存在，再复制、核对远端摘要及 Bash 语法。遇错停止，不覆盖、不删除现有文件。

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $bundle = 'D:\Projects\teacher-workbench\data\deploy\teacher-workbench-stage2c-pg-source.tar.gz'
    $script = 'D:\Projects\teacher-workbench\scripts\verify_ubuntu_staging_phase2c_pg_isolated.sh'
    $bundleHash = '36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303'
    $scriptHash = '6f4482e0684723cf8827cfc38169c0faf636dac9e553e7fb67e221e17fc3c3b9'
    if ((Get-FileHash -LiteralPath $bundle -Algorithm SHA256).Hash.ToLowerInvariant() -cne $bundleHash) { throw '2C 源码包摘要不符；停止' }
    if ((Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash.ToLowerInvariant() -cne $scriptHash) { throw '2C 测试脚本摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e teacher-workbench-stage2c-pg-source.tar.gz && test ! -L teacher-workbench-stage2c-pg-source.tar.gz && test ! -e verify_ubuntu_staging_phase2c_pg_isolated.sh && test ! -L verify_ubuntu_staging_phase2c_pg_isolated.sh && echo STAGING_2C_PG_UPLOAD_TARGETS_EMPTY'
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu 目标已有文件或预检失败；停止' }
    scp $bundle $script 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 测试文件上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$bundleHash  teacher-workbench-stage2c-pg-source.tar.gz' | sha256sum -c - && echo '$scriptHash  verify_ubuntu_staging_phase2c_pg_isolated.sh' | sha256sum -c - && bash -n verify_ubuntu_staging_phase2c_pg_isolated.sh && echo STAGING_2C_PG_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '2C 上传摘要或语法核对失败；停止' }
}
```

成功标记 `STAGING_2C_PG_UPLOAD_VERIFIED` 只证明传输完整；此步不创建容器或运行测试。**第 2 步执行脚本**将在上传结果核对后单独给出；需先在交互式 SSH 会话执行 `sudo -v`，脚本使用 `sudo -n`，缓存失效就立即停止而不等待隐藏的密码提示。

**2026-10-22 第 1 步用户现场完成：**用户粘贴两份远端文件的 `sha256sum -c` 均为 `OK`，以及 `STAGING_2C_PG_UPLOAD_VERIFIED`。这只验收测试材料上传，尚未运行隔离 PostgreSQL 测试；助手未直连 Ubuntu。

**第 2 步：在 Ubuntu 257 的交互式 SSH 会话运行隔离测试。**先在 Windows PowerShell 执行 `ssh -tt huahua@10.0.30.5`，看到 `huahua@teacher-workbench:~$` 后，在**同一 Ubuntu shell**单独执行 `sudo -v`；若要求密码，只在该终端输入，字符不回显，成功应返回提示符。然后在同一 shell 粘贴下面整行；摘要或语法失败就停止，不启动容器：

```bash
cd /home/huahua && echo '36c91614eb039ad3afcc9ccdbc794d3a3fa03603dd97965056efc7a0dee72303  teacher-workbench-stage2c-pg-source.tar.gz' | sha256sum -c - && echo '6f4482e0684723cf8827cfc38169c0faf636dac9e553e7fb67e221e17fc3c3b9  verify_ubuntu_staging_phase2c_pg_isolated.sh' | sha256sum -c - && bash -n verify_ubuntu_staging_phase2c_pg_isolated.sh && bash verify_ubuntu_staging_phase2c_pg_isolated.sh
```

脚本会在服务器创建单独的内部 Docker 网络、PostgreSQL 卷和测试容器/私有目录，使用虚构测试密码且关闭 AI；不迁移、切换或挂载在线预发布库与密钥。测试最多可能运行数分钟，保持窗口打开。成功时应有 26 项测试 `OK`、`STAGING_2C_PG_CONCURRENCY_AND_SPECIALIZED_TESTS_OK`、`STAGING_2C_PG_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_PG_DB_STOPPED_VOLUME_PRESERVED` 与最终 `STAGING_2C_PG_ISOLATED_TEST_VERIFIED`。失败或超时应保留末尾非敏感输出，**不要直接重跑或删除测试目录/卷**，因为脚本拒绝覆盖已有目标；据失败点再设计核对/续测步骤。

**2026-10-22 第 2 步用户现场完成：**用户返回测试库销毁 `OK`、并发与专项标记、双登录页 HTTP 200、测试库已停止且卷保留、最终 `STAGING_2C_PG_ISOLATED_TEST_VERIFIED`；目录 `/home/huahua/teacher-workbench-stage2c-pg-36c91614eb03`。据已审核脚本，26 项在隔离 PostgreSQL 17 测试库通过；没有在线迁移或新版本切换。助手未直连 Ubuntu。后续须先对当前在线虚构预发布状态做新配对备份及新卷恢复，再准备迁移/切换，不能用本次空白测试库替代在线数据的恢复演练。

### 阶段 2C 切换前：刷新当前 2B 虚构预发布配对备份（待现场执行）

当前预发布仍运行 2B 镜像和迁移 `0005`。已于 2026-10-21 现场通过的修正版 `backup_ubuntu_staging_phase2b_credentials_v2.sh` 可按随机新后缀再次保存**当前**数据库、私有文件、应用镜像与脱敏源码；同时在独立 0700 目录保存同机虚构主密钥副本。脚本不覆盖旧备份，停 Web/网关期间暂停预发布写入，完成后重启并核对 18002 登录页。它不部署 2C、不迁移在线库、不调用模型。该次新备份尚未执行，也未取得新目录名。

在 Windows PowerShell 进入交互式 SSH：`ssh -tt huahua@10.0.30.5`。看到 Ubuntu 提示符后，先在该 shell 单独执行 `sudo -v`；若要求密码，只在终端输入。返回提示符后，在**同一 shell**运行：

```bash
cd /home/huahua && echo '15f1a05afb3a11af649f85bdac99d27968687af88780b336d059b4fe8e9e39c5  backup_ubuntu_staging_phase2b_credentials_v2.sh' | sha256sum -c - && bash -n backup_ubuntu_staging_phase2b_credentials_v2.sh && bash backup_ubuntu_staging_phase2b_credentials_v2.sh
```

成功须见 `STAGING_2B_WEB_RESTARTED_HTTP_200` 和 `STAGING_2B_PAIRED_FILES_VERIFIED`，并记下本次新 `STAGING_2B_BACKUP_DIR` 与 `STAGING_2B_ESCROW_DIR`。后续用已有恢复脚本在**新卷**演练这次快照，完成后才准备 2C 迁移/切换。若命令失败，保留末尾非敏感输出及现有文件，不重复执行、不手工清理；先检查预发布是否已重新启动。

**2026-10-22 新快照用户现场完成：**`STAGING_2B_SNAPSHOT_FICTIONAL_ROWS_READY count=2`、停写后四类归档、`STAGING_2B_WEB_RESTARTED_HTTP_200` 和 `STAGING_2B_PAIRED_FILES_VERIFIED` 均出现。本次数据目录 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-F6yZnxfi`，同机密钥副本目录 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-F6yZnxfi`。证据由用户提供，助手未直连 Ubuntu；不能据此宣称新备份已恢复。

**下一步：从本次快照在新 Docker 网络和卷独立恢复。**Windows PowerShell 用 `ssh -tt huahua@10.0.30.5` 进入 Ubuntu；在同一交互式 shell 单独执行 `sudo -v`，返回提示符后运行：

```bash
cd /home/huahua && echo 'a0a3e402d736dfa4dbbb37d965ed4b88180092c6d94ae70e311a5ba7104a3e22  restore_ubuntu_staging_phase2b_credentials.sh' | sha256sum -c - && bash -n restore_ubuntu_staging_phase2b_credentials.sh && bash restore_ubuntu_staging_phase2b_credentials.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-F6yZnxfi
```

脚本只读取新备份与同后缀密钥副本，在新的隔离网络/卷恢复并检查旧虚构资料、草稿和两条虚构配置及跨账号拒绝；不替换在线预发布，不触发模型。成功须见 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2B_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2B_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 和最终 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`。预期可能出现几条跨账号 `Not Found`（404）；失败时不重跑或删除目标卷，反馈末尾非敏感输出。完成后才准备 2C 迁移与切换。

**2026-10-22 新快照独立恢复用户现场完成：**用户提供远端脚本摘要 `OK`、备份与密钥核对、隔离恢复、`STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、源站 HTTP 200、容器停且卷保留和最终 `STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`。恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-keys-restore-F6yZnxfi`。四条 `Not Found` 是预期跨账号 404；助手未直连 Ubuntu。在线站仍未执行 2C 迁移。

### 阶段 2C：先在新恢复副本试跑数据库迁移（代码已写，未上传或执行）

本机脚本 `scripts/verify_ubuntu_staging_phase2c_restored_migration.sh` 固定操作新恢复副本 `F6yZnxfi` 的已停止容器和卷。先核对 2B 备份清单、配对虚构密钥、2C 源包摘要、恢复卷挂载及在线 2B 镜像；仅在隔离副本启动数据库/Redis 并挂载新源码，执行 `0006`～`0008` 迁移和旧资料/虚构 Key/跨账号检查，最后停止隔离容器、保留卷。脚本不读取在线数据库内容、不迁移在线库、不切换镜像或打开 AI。SHA-256 `ccc817fc50afcb20c3f8051a7ade5af4e6cdba7acefe7ab1e24f2a69285cbc18`；本机 LF 和三段嵌入式 Python 语法通过，Bash 语法需 Ubuntu 上传后检查。

**第 1 步只上传并核对脚本。**在 Windows PowerShell 运行整个代码块；遇错停止，不覆盖远端现有同名文件：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\verify_ubuntu_staging_phase2c_restored_migration.sh'
    $expectedHash = 'ccc817fc50afcb20c3f8051a7ade5af4e6cdba7acefe7ab1e24f2a69285cbc18'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 2C 迁移演练脚本摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e verify_ubuntu_staging_phase2c_restored_migration.sh && test ! -L verify_ubuntu_staging_phase2c_restored_migration.sh && echo STAGING_2C_RESTORE_MIGRATION_UPLOAD_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端已有同名脚本或预检失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 迁移演练脚本上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  verify_ubuntu_staging_phase2c_restored_migration.sh' | sha256sum -c - && bash -n verify_ubuntu_staging_phase2c_restored_migration.sh && echo STAGING_2C_RESTORE_MIGRATION_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '2C 迁移演练脚本远端摘要或 Bash 语法失败；停止' }
}
```

上传成功标记只证明文件与语法，**不会启动恢复容器或执行迁移**。取得现场上传结果后，再单独给出交互式 SSH 中的运行命令；运行前仍须先 `sudo -v`。若脚本运行失败，保留隔离卷和目录、核对容器停止状态后再定修复路径，不直接重跑。

**2026-10-22 第 1 步用户现场完成：**远端 `verify_ubuntu_staging_phase2c_restored_migration.sh: OK` 和 `STAGING_2C_RESTORE_MIGRATION_UPLOAD_VERIFIED`；仅完成摘要及 Bash 语法核对，尚未启动恢复库或迁移。助手未直连 Ubuntu。

**第 2 步在固定隔离恢复卷执行 2C 迁移演练。**Windows PowerShell 运行 `ssh -tt huahua@10.0.30.5`，进入 Ubuntu 后在**同一交互式 shell**单独执行 `sudo -v`，如需密码只在终端输入。返回提示符后运行：

```bash
cd /home/huahua && echo 'ccc817fc50afcb20c3f8051a7ade5af4e6cdba7acefe7ab1e24f2a69285cbc18  verify_ubuntu_staging_phase2c_restored_migration.sh' | sha256sum -c - && bash -n verify_ubuntu_staging_phase2c_restored_migration.sh && bash verify_ubuntu_staging_phase2c_restored_migration.sh
```

脚本仅启动 `F6yZnxfi` 的隔离恢复 PostgreSQL/Redis 容器，使用原 2B 镜像加只读 2C 源码在该副本执行迁移。成功须见 `STAGING_2C_RESTORE_MIGRATIONS_APPLIED`、`STAGING_2C_RESTORE_OLD_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2C_RESTORE_MIGRATIONS_COMPLETE`、`STAGING_2C_RESTORE_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED` 与最终 `STAGING_2C_RESTORE_MIGRATION_VERIFIED`。四条跨账号 `Not Found` 是预期 404。失败时**不要重跑或清理**，保留末尾非敏感输出；目标卷可能已部分迁移，须先核对状态。在线预发布不会由本脚本迁移或切换。

**2026-10-22 第 2 步用户现场完成：**原恢复库迁移止于 `0005` 的预检通过，`workbench.0006`、`0007`、`0008` 均显示 `OK`，旧虚构资料/密钥/跨账号检查、迁移完整性、在线双登录页 HTTP 200、隔离容器停止且卷保留与最终 `STAGING_2C_RESTORE_MIGRATION_VERIFIED` 均出现。演练目录 `/home/huahua/teacher-workbench-staging-phase2c-migration-F6yZnxfi`；四条 `Not Found` 为预期 404。助手未直连 Ubuntu；在线预发布仍在 2B。

### 阶段 2C：离线构建新镜像并用已迁移恢复副本烟测（脚本已上传，构建待执行）

固定脚本 `scripts/build_ubuntu_staging_phase2c_offline.sh` SHA-256 `1d909dbf353d956cc28c377858d171a2a603e62b73d95616a161b9a828aaf8b6`。它核对现有 2B 在线镜像与配对备份、2C 源码包和已迁移的 `F6yZnxfi` 恢复卷，再从本地 2B 镜像禁网构建新标签 `teacher-workbench-staging-web:member-quota-20261022`，用清单核对镜像内 74 个源码文件，并在隔离库以 AI 关闭模式做 Django/旧数据烟测。新镜像不用于在线 Web；脚本不迁移在线数据库，不发送模型请求。脚本本机 LF 和四段 Python 语法通过，Ubuntu `bash -n` 与实际构建未执行。

**第 1 步只上传并核对执行脚本。**Windows PowerShell 运行整个代码块，若远端已有同名文件则停止，不覆盖：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\build_ubuntu_staging_phase2c_offline.sh'
    $expectedHash = '1d909dbf353d956cc28c377858d171a2a603e62b73d95616a161b9a828aaf8b6'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '2C 离线镜像脚本本地摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e build_ubuntu_staging_phase2c_offline.sh && test ! -L build_ubuntu_staging_phase2c_offline.sh && echo STAGING_2C_IMAGE_UPLOAD_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端已有同名脚本或预检失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 离线镜像脚本上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  build_ubuntu_staging_phase2c_offline.sh' | sha256sum -c - && bash -n build_ubuntu_staging_phase2c_offline.sh && echo STAGING_2C_IMAGE_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '远端摘要或 Bash 语法核对失败；停止' }
}
```

这一步只上传文件，不构建镜像。取得 `STAGING_2C_IMAGE_UPLOAD_VERIFIED` 后再给交互式 SSH 的执行命令；构建或烟测若失败，保留原镜像、测试卷及脚本输出，不直接重试或清理。

**2026-10-22 第 1 步用户现场完成：**远端 `build_ubuntu_staging_phase2c_offline.sh: OK` 和 `STAGING_2C_IMAGE_UPLOAD_VERIFIED`；仅完成摘要与 Bash 语法检查，尚未构建镜像。助手未直连 Ubuntu。

**第 2 步离线构建并在隔离恢复库烟测。**在 Windows PowerShell 执行 `ssh -tt huahua@10.0.30.5`，进入 Ubuntu 后在同一个交互式 shell 先单独运行 `sudo -v`，按提示只在该终端输入 sudo 密码。返回提示符后运行：

```bash
cd /home/huahua && echo '1d909dbf353d956cc28c377858d171a2a603e62b73d95616a161b9a828aaf8b6  build_ubuntu_staging_phase2c_offline.sh' | sha256sum -c - && bash -n build_ubuntu_staging_phase2c_offline.sh && bash build_ubuntu_staging_phase2c_offline.sh
```

脚本以本机旧镜像为基础，禁网构建新标签并只连接已迁移的 `F6yZnxfi` 隔离恢复卷；不切换在线 Web、不迁移在线数据库或调用模型。成功须见 `STAGING_2C_OFFLINE_IMAGE_SOURCE_MATCH_OK`、`STAGING_2C_OFFLINE_IMAGE_RESTORED_CONTENT_OK`、`STAGING_2C_OFFLINE_IMAGE_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_OFFLINE_IMAGE_RESTORE_CONTAINERS_STOPPED` 和最终 `STAGING_2C_OFFLINE_IMAGE_BUILT_SMOKE_VERIFIED_NO_SWITCH`。可能需要数分钟，保持窗口打开。若报错或未出现最终标记，不直接重跑或清理；保留末尾非敏感输出供检查，构建可能已留下新标签或临时目录。

**2026-10-22 第 2 步用户现场完成：**源码匹配、Django 检查、恢复副本旧内容、在线双登录页、隔离容器停止及最终 `STAGING_2C_OFFLINE_IMAGE_BUILT_SMOKE_VERIFIED_NO_SWITCH` 均有用户终端标记；新镜像 ID `sha256:0b9224e320fd2941696fa8743cba22adaad55117af80f88b369daf151e50b63a`。助手未直连 Ubuntu；此时在线预发布仍为 2B。

### 阶段 2C：仅准备新预发布配置目录（代码已写，Ubuntu 待执行）

本机脚本 `scripts/prepare_ubuntu_staging_phase2c_source.py` SHA-256 `fbeeecaa8fe78a8f8bf7f1c48aec7bf8cd4aa127da623d3ac4ae9686dcfd7663`。它要求旧 2B Compose 和离线镜像完成记录匹配，复制现有预发布 `.env.staging` 与 Nginx 配置至新私有目录，指定已验新镜像，移除 Compose 的构建块并显式将 `AI_MEMBER_TASKS_ENABLED` 保持为 `0`。不运行 Docker，不切换站点，不迁移在线数据库；新目录已存在时拒绝覆盖。

在 Windows PowerShell **整体运行**下方代码块；成功标记为 `STAGING_2C_CONFIG_PREPARED_AI_OFF`。若任一步失败，不继续后续切换，也不要直接重跑覆盖新目录，保留末尾非敏感输出：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\prepare_ubuntu_staging_phase2c_source.py'
    $expectedHash = 'fbeeecaa8fe78a8f8bf7f1c48aec7bf8cd4aa127da623d3ac4ae9686dcfd7663'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 2C 配置脚本摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e prepare_ubuntu_staging_phase2c_source.py && test ! -L prepare_ubuntu_staging_phase2c_source.py && echo STAGING_2C_CONFIG_UPLOAD_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端已有同名脚本或预检失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 配置脚本上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  prepare_ubuntu_staging_phase2c_source.py' | sha256sum -c - && python3 -m py_compile prepare_ubuntu_staging_phase2c_source.py && python3 prepare_ubuntu_staging_phase2c_source.py"
    if ($LASTEXITCODE -ne 0) { throw '2C 配置目录准备失败；停止并反馈末尾非敏感输出' }
}
```

生成目录 `/home/huahua/teacher-workbench-staging-phase2c-20261022` 后，还必须用新配置做只读 Compose 和在线状态预检，再准备紧邻切换时的新配对备份与独立恢复。此前任何成功标记都不代表在线 2C 已上线。

**2026-10-22 用户现场完成目录准备：**`prepare_ubuntu_staging_phase2c_source.py: OK`、`STAGING_2C_CONFIG_PREPARED_AI_OFF` 和新目录 `/home/huahua/teacher-workbench-staging-phase2c-20261022`；助手未直连 Ubuntu，Compose 解析和在线状态尚待核对。

### 阶段 2C：新配置与在线现状只读预检（代码已写，未现场执行）

脚本 `scripts/check_ubuntu_staging_phase2c_config_readonly.sh` SHA-256 `92b6c91a914de58540a71c4a9fa807048edcba45f189a7e24646b655b32291e9`。它不修改服务或读取密钥内容；要求交互式 SSH 中预先完成 `sudo -v`，避免非交互密码提示卡住。先在 Windows PowerShell 整体运行上传和远端语法核对：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\check_ubuntu_staging_phase2c_config_readonly.sh'
    $expectedHash = '92b6c91a914de58540a71c4a9fa807048edcba45f189a7e24646b655b32291e9'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 2C 预检脚本摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e check_ubuntu_staging_phase2c_config_readonly.sh && test ! -L check_ubuntu_staging_phase2c_config_readonly.sh && echo STAGING_2C_CONFIG_PREFLIGHT_UPLOAD_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端已有同名脚本或预检失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 预检脚本上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  check_ubuntu_staging_phase2c_config_readonly.sh' | sha256sum -c - && bash -n check_ubuntu_staging_phase2c_config_readonly.sh && echo STAGING_2C_CONFIG_PREFLIGHT_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '远端摘要或 Bash 语法核对失败；停止' }
}
```

上传成功后，在 Windows PowerShell 执行 `ssh -tt huahua@10.0.30.5`。进入 Ubuntu 后在同一交互式 shell 先单独执行 `sudo -v`，仅在该终端输入密码；返回提示符后运行：

```bash
cd /home/huahua && echo '92b6c91a914de58540a71c4a9fa807048edcba45f189a7e24646b655b32291e9  check_ubuntu_staging_phase2c_config_readonly.sh' | sha256sum -c - && bash -n check_ubuntu_staging_phase2c_config_readonly.sh && bash check_ubuntu_staging_phase2c_config_readonly.sh
```

成功须见 `STAGING_2C_CONFIG_CONTENT_MATCH_OK`、`STAGING_2C_CONFIG_COMPOSE_VALID`、`STAGING_2C_CONFIG_ONLINE_STILL_2B_AI_OFF`、`STAGING_2C_CONFIG_BOTH_LOGINS_HTTP_200` 和最终 `STAGING_2C_CONFIG_READONLY_PREFLIGHT_OK`。如失败，勿继续切换，反馈末尾非敏感输出。即使通过，下一步仍是新配对备份及独立恢复，不由本预检自动执行。

**2026-10-22 用户首次执行结果：**脚本摘要与配置内容核对通过，但 `sudo -n -v` 报 `interactive authentication is required`，最终 `STAGING_2C_CONFIG_PREFLIGHT_SUDO_REQUIRED`。该只读脚本在 Docker 检查前停止；无需重传。请在 Windows PowerShell 先输入 `ssh -tt huahua@10.0.30.5`，进入 Ubuntu 后**单独**运行 `sudo -v` 并在该终端输入密码。看到 `huahua@teacher-workbench:~$` 返回后，在**同一窗口**执行上方 Bash 命令。不要把 `sudo -v` 放进非交互 `ssh ... '命令'` 中；不要将密码发给助手。完成前不运行备份或切换脚本。

**2026-10-22 用户复验通过：**配置内容匹配、Compose 解析、旧 2B 在线镜像与 AI 关闭、双登录页 HTTP 200 及最终 `STAGING_2C_CONFIG_READONLY_PREFLIGHT_OK` 均出现。助手未直连 Ubuntu；不由此推断新备份或 2C 切换已完成。

### 阶段 2C：后续备份与切换脚本（旧包装器已停用，使用下方 v2）

- `scripts/prepare_ubuntu_staging_phase2c_switch_snapshot.sh` SHA-256 `d438bd7cbf59c2a1696c82edd670a84bf7fd9feaec20d2d1228e326d760a6b4d`：历史包装器将修正版 2B 备份脚本的摘要与旧文件名配对，现场已证实提前退出，**不得再执行**。改用下方新的 `..._v2.sh` 包装器；旧文件保留用于审计。
- `scripts/apply_ubuntu_staging_phase2c.sh` SHA-256 `e200ef6a28dbc0b90935a339f0ee40063597170a603d94f582c12011b8c845e2`：仅接受该新备份路径，检查一小时内完成、旧在线镜像和新镜像的固定 ID。先在新恢复卷用新镜像应用 2C 迁移及核对旧资料/虚构 Key；验证通过后才停止预发布 Web/Gateway、迁移在线库并切换新镜像。成功标记预期为 `STAGING_2C_DEPLOYED_AI_OFF`。失败会尝试恢复旧 Web/Gateway；在线数据库可能已部分或全部执行新增迁移，**不能把服务回滚当作数据回滚**。必须保留配对备份并根据现场结果决定是否需要独立恢复。

两脚本均尚未上传 Ubuntu 或运行，本机仅检验 LF 与嵌入式 Python 语法；Windows 无 Bash/Docker。先完成上方只读预检，并根据其现场结果再提供备份/切换操作命令，不从脚本编写推断预发布已升级。

**历史命令，已停用：不要再运行下方旧包装器命令。**旧包装器误指向 `backup_ubuntu_staging_phase2b_credentials.sh`，而正确的修正版文件是 `backup_ubuntu_staging_phase2b_credentials_v2.sh`。以下内容仅保留失败过程；现行操作见本节末尾 v2 段落。

**只读预检通过后的下一现场步骤：新配对备份及独立恢复。**包装器会重新核对现状，使用固定 SHA-256 的旧 2B 备份/恢复脚本。备份期间会短暂停止虚构预发布 Web/Gateway，完成后启动；隔离恢复使用新网络/卷，不迁移在线数据库或切换镜像。Windows PowerShell 整体运行上传与语法检查：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\prepare_ubuntu_staging_phase2c_switch_snapshot.sh'
    $expectedHash = 'd438bd7cbf59c2a1696c82edd670a84bf7fd9feaec20d2d1228e326d760a6b4d'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 2C 备份包装器摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e prepare_ubuntu_staging_phase2c_switch_snapshot.sh && test ! -L prepare_ubuntu_staging_phase2c_switch_snapshot.sh && echo STAGING_2C_SNAPSHOT_UPLOAD_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端已有同名脚本或预检失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 备份包装器上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  prepare_ubuntu_staging_phase2c_switch_snapshot.sh' | sha256sum -c - && bash -n prepare_ubuntu_staging_phase2c_switch_snapshot.sh && echo STAGING_2C_SNAPSHOT_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '远端摘要或 Bash 语法核对失败；停止' }
}
```

上传成功后，在 Windows PowerShell 执行 `ssh -tt huahua@10.0.30.5`，进入 Ubuntu 后先**单独**执行 `sudo -v`，只在终端输入密码；返回提示符后在同一窗口运行：

```bash
cd /home/huahua && echo 'd438bd7cbf59c2a1696c82edd670a84bf7fd9feaec20d2d1228e326d760a6b4d  prepare_ubuntu_staging_phase2c_switch_snapshot.sh' | sha256sum -c - && bash -n prepare_ubuntu_staging_phase2c_switch_snapshot.sh && bash prepare_ubuntu_staging_phase2c_switch_snapshot.sh
```

成功须见 `STAGING_2B_PAIRED_FILES_VERIFIED`、`STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`、最终 `STAGING_2C_FRESH_2B_BACKUP_RESTORE_OK`，并记录新 `STAGING_2C_FRESH_BACKUP_DIR`。镜像归档与数据库恢复可能耗时；保持窗口打开。如失败或长时间无新输出，先反馈末尾非敏感内容，不关闭窗口、不直接重跑或执行切换。后续切换脚本只接受这次新备份，且要求备份完成不超过一小时；超时则另做新备份。

**2026-10-22 用户现场上传进度：**`prepare_ubuntu_staging_phase2c_switch_snapshot.sh: OK`，用户进一步确认 `STAGING_2C_SNAPSHOT_UPLOAD_VERIFIED` 已显示。仅完成远端摘要和 Bash 语法检查；上方交互式 Ubuntu 执行步骤尚无结果。执行时先在同一 SSH 窗口单独 `sudo -v`，再运行固定哈希命令；若备份或恢复中断，保留窗口并反馈末尾非敏感输出，不直接重跑或切换。

**2026-10-22 用户现场运行中的部分输出：**Ubuntu 运行命令已返回 `prepare_ubuntu_staging_phase2c_switch_snapshot.sh: OK`，后续预检/备份/恢复输出尚未回传。此行只证明脚本摘要校验通过；保留原终端，待确认是否有后续标记或已返回提示符，再决定处理方式。暂不重复执行备份包装器。

**2026-10-22 提前返回提示符：**用户确认只有脚本摘要 `OK`，随后返回 Ubuntu shell。暂不重跑包装器或执行 2C 切换；在同一终端立即运行 `printf 'SNAPSHOT_LAST_EXIT=%s\n' "$?"` 读取上一命令状态，随后按退出码做只读检查。该操作不读取密钥或修改服务。

**2026-10-22 返回码与诊断方向：**用户在原 Ubuntu 窗口得到 `SNAPSHOT_LAST_EXIT=1`。包装器在首个 `STAGING_2C_SNAPSHOT_PREFLIGHT_OK` 前可能因依赖脚本摘要不符而静默退出；先只读检查 `bash -n` 及预检、旧备份、旧恢复脚本的 SHA-256，不直接重跑。仅将 SHA-256 与普通文件元数据回传，不输出 `.env`、密钥或备份内容。

**2026-10-22 根因确认（用户终端只读诊断）：**`SNAPSHOT_SYNTAX_OK`；备份根目录为 `huahua` 所有、权限 0700、普通目录。预检脚本摘要 `92b6...` 与恢复脚本摘要 `a0a3...` 均匹配；旧文件名 `backup_ubuntu_staging_phase2b_credentials.sh` 的现场摘要是 `4dc7bc83a32ba9ae315ccf3e6204cbe17018c9653d96fa489251858e1f215793`，正是项目记录中的初版。包装器却要求修正版摘要 `15f1...`，且该修正版先前已上传为 `backup_ubuntu_staging_phase2b_credentials_v2.sh`。原包装器在执行备份前的哈希比较处退出；不需更改旧脚本或旧备份。

### 阶段 2C：修正后的 v2 配对备份与独立恢复（代码已写，现场待执行）

本机新文件 `scripts/prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh` SHA-256 `0804341f6d64dfeb74f6c9ed82d94a74bad921ccd6f059f4dffa001d52c93dd0`，只改为引用现场已有的修正版 `backup_ubuntu_staging_phase2b_credentials_v2.sh`，并在依赖脚本摘要不符时明确输出文件名。原包装器保留，不覆盖。新包装器仍会先跑 2C 配置只读预检，再创建一套新随机名称的 2B 配对备份和隔离恢复；它不切换在线镜像、不迁移在线数据库。备份期间虚构预发布 Web/Gateway 短暂停止，完成后重启。**本机已核对 LF、依赖摘要和代码路径，Windows 无 Bash；须远端 `bash -n` 验证后再运行。**

本机补充检查：下方 Windows PowerShell 上传代码块解析通过；v2 脚本仍为 LF，摘要与上述记录一致。此为本机静态检查，未代替 Ubuntu Bash 或实际备份/恢复验收。

先在 Windows PowerShell **整体运行**上传与只读校验代码块；成功标记为 `STAGING_2C_SNAPSHOT_V2_UPLOAD_VERIFIED`。任一步失败即停，不进入备份：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh'
    $expectedHash = '0804341f6d64dfeb74f6c9ed82d94a74bad921ccd6f059f4dffa001d52c93dd0'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 v2 包装器摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh && test ! -L prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh && echo STAGING_2C_SNAPSHOT_V2_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端目标已存在或检查失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw 'v2 包装器上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh' | sha256sum -c - && bash -n prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh && echo '15f1a05afb3a11af649f85bdac99d27968687af88780b336d059b4fe8e9e39c5  backup_ubuntu_staging_phase2b_credentials_v2.sh' | sha256sum -c - && echo STAGING_2C_SNAPSHOT_V2_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '远端 v2 摘要、语法或依赖核对失败；停止' }
}
```

上传标记出现后，在 Windows PowerShell 运行 `ssh -tt huahua@10.0.30.5`，进入 Ubuntu 后**单独**运行 `sudo -v`，只在终端输入密码；返回提示符后在同一窗口执行：

```bash
cd /home/huahua && echo '0804341f6d64dfeb74f6c9ed82d94a74bad921ccd6f059f4dffa001d52c93dd0  prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh' | sha256sum -c - && bash -n prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh && bash prepare_ubuntu_staging_phase2c_switch_snapshot_v2.sh
```

成功须见 `STAGING_2C_SNAPSHOT_DEPENDENCIES_VERIFIED`、`STAGING_2B_PAIRED_FILES_VERIFIED`、`STAGING_2B_INDEPENDENT_RESTORE_VERIFIED`、`STAGING_2C_FRESH_2B_BACKUP_RESTORE_OK` 和新的 `STAGING_2C_FRESH_BACKUP_DIR=...`。若失败，保留窗口和末尾非敏感输出，不直接重跑、清理或切换；单行 `..._v2.sh: OK` 仅代表摘要通过。

**2026-10-22 用户现场上传通过：**v2 包装器与修正版备份依赖的远端摘要均 `OK`，最终 `STAGING_2C_SNAPSHOT_V2_UPLOAD_VERIFIED`。上方交互式 Ubuntu 执行命令尚未由用户回传成功标记；此刻不记为备份完成。

**2026-10-22 用户现场备份及独立恢复通过：**用户提供 `STAGING_2B_WEB_RESTARTED_HTTP_200`、`STAGING_2B_PAIRED_FILES_VERIFIED`、`STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、`STAGING_2B_INDEPENDENT_RESTORE_VERIFIED` 与最终 `STAGING_2C_FRESH_2B_BACKUP_RESTORE_OK`。新备份为 `/home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-N1yfMAgN`，同机密钥副本为 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-N1yfMAgN`，独立恢复目录为 `/home/huahua/teacher-workbench-staging-phase2b-keys-restore-N1yfMAgN`。四条 `Not Found` 是预期 404。按包装器尚未触及在线 2C 镜像或迁移；助手未直连服务器。下一步上传并核对 `apply_ubuntu_staging_phase2c.sh`；执行前注意其备份一小时新鲜度限制。

### 阶段 2C：在线切换脚本先上传核对（未执行）

本机 `scripts/apply_ubuntu_staging_phase2c.sh` SHA-256 `e200ef6a28dbc0b90935a339f0ee40063597170a603d94f582c12011b8c845e2`。它只针对虚构预发布：先在**本次新恢复副本**用 2C 镜像验证迁移、旧资料与假 Key，再短暂停止预发布 Web/Gateway、对在线预发布数据库执行迁移并切换镜像；AI 与成员任务调用均关闭。失败时尝试重启旧 Web/Gateway，但**数据库迁移不会自动回退**；原备份保持不动，必须按现场标记判断。备份完成超过一小时时脚本会在改动在线服务前拒绝执行，须重做新备份/恢复。正式环境不在此脚本范围。以下只上传和检查，**不会启动切换**。

在 Windows PowerShell 整体运行；成功标记 `STAGING_2C_SWITCH_UPLOAD_VERIFIED`。目标存在、摘要或 Bash 语法失败时立即停止：

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $localScript = 'D:\Projects\teacher-workbench\scripts\apply_ubuntu_staging_phase2c.sh'
    $expectedHash = 'e200ef6a28dbc0b90935a339f0ee40063597170a603d94f582c12011b8c845e2'
    if ((Get-FileHash -LiteralPath $localScript -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) { throw '本地 2C 切换脚本摘要不符；停止' }
    ssh huahua@10.0.30.5 'cd /home/huahua && test ! -e apply_ubuntu_staging_phase2c.sh && test ! -L apply_ubuntu_staging_phase2c.sh && echo STAGING_2C_SWITCH_TARGET_FREE'
    if ($LASTEXITCODE -ne 0) { throw '远端目标已存在或检查失败；停止' }
    scp $localScript 'huahua@10.0.30.5:/home/huahua/'
    if ($LASTEXITCODE -ne 0) { throw '2C 切换脚本上传失败；停止' }
    ssh huahua@10.0.30.5 "cd /home/huahua && echo '$expectedHash  apply_ubuntu_staging_phase2c.sh' | sha256sum -c - && bash -n apply_ubuntu_staging_phase2c.sh && echo STAGING_2C_SWITCH_UPLOAD_VERIFIED"
    if ($LASTEXITCODE -ne 0) { throw '远端摘要或 Bash 语法检查失败；停止' }
}
```

获得上传标记后，才安排交互式 Ubuntu 执行；本段上传检查**不等于**在线 2C 已上线。

**2026-10-22 用户现场上传通过：**`apply_ubuntu_staging_phase2c.sh: OK`、`STAGING_2C_SWITCH_UPLOAD_VERIFIED`。助手未直连 Ubuntu；尚未见脚本执行输出，在线预发布状态仍按最后一次 2B 只读预检记录。下步执行固定新备份路径；若一小时新鲜度检查失败，脚本在在线迁移前停止，再做新配对备份及恢复，不用旧目录强行继续。

交互式 Ubuntu 执行：Windows PowerShell 运行 `ssh -tt huahua@10.0.30.5`；在同一 Ubuntu shell 单独运行 `sudo -v` 并等提示符返回，再运行：

```bash
cd /home/huahua && echo 'e200ef6a28dbc0b90935a339f0ee40063597170a603d94f582c12011b8c845e2  apply_ubuntu_staging_phase2c.sh' | sha256sum -c - && bash -n apply_ubuntu_staging_phase2c.sh && bash apply_ubuntu_staging_phase2c.sh /home/huahua/teacher-workbench-staging-backups/backup-phase2b-keys-N1yfMAgN
```

成功须见 `STAGING_2C_FRESH_RESTORE_MIGRATION_PROVED`、`STAGING_2C_ONLINE_ADDITIVE_MIGRATIONS_OK`、`STAGING_2C_ONLINE_SCHEMA_AI_OFF_AND_OLD_CONTENT_OK`、`STAGING_2C_NEW_AND_OLD_TEST_LOGIN_HTTP_200` 和最终 `STAGING_2C_DEPLOYED_AI_OFF`。这一步会对**在线虚构预发布数据库**应用新增迁移并短暂停止预发布 Web/Gateway；不涉及正式环境。若失败，保留原终端及末尾非敏感输出，勿重跑或自行恢复数据库；脚本重启旧服务不代表数据已回退。

**2026-10-22 用户现场切换通过：**用户提供末尾 `STAGING_2C_ONLINE_SCHEMA_AI_OFF_AND_OLD_CONTENT_OK`、`STAGING_2C_NEW_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_2C_DEPLOYED_AI_OFF`，新目录 `/home/huahua/teacher-workbench-staging-phase2c-20261022`，切换前备份 `backup-phase2b-keys-N1yfMAgN`。按固定脚本顺序，技术切换和在线虚构预发布数据库迁移已完成；仍需用户在浏览器验收 2C 新页面及权限。助手未直连 Ubuntu；本机目前无 18002 隧道，不能把本机 HTTP 访问失败当作服务器故障。旧备份与独立密钥副本保留，不手工清理。正式环境未发布。

**下一现场步骤（浏览器只读验收，尚未执行）：**从 Ubuntu SSH 返回 Windows PowerShell，保持一个窗口运行 `ssh -N -L 127.0.0.1:18002:127.0.0.1:18002 huahua@10.0.30.5`；该窗口无提示符属正常隧道占用。在浏览器使用 `http://127.0.0.1:18002/members/`，**登录账号是虚构管理者 `staging_manager_20261018`，其密码由用户自己保管；`staging_teacher_a_20261018` 只是列表中的被管理对象，此步不需要教师密码**。点击该教师旁的“调用次数”，只观察页面和“尚未设置调用次数”提示，不保存设置或触发模型请求。结果待用户反馈后再进入保存与权限检查。若本机 18002 已被已有隧道占用，复用原隧道，不重复启动。

**2026-10-22 用户浏览器只读验收通过：**用户反馈并截图显示 `staging_teacher_a_20261018` 的“调用次数”页正常显示用户名、尚未设置提示、次数与有效期表单；用户确认未看到教学资料或模型 Key。该步骤未提交表单或调用模型，不能推断额度已保存。

**下一浏览器步骤（待执行）：**在当前虚构管理者会话和该教师额度页填“累计允许调用次数”=`0`，有效期选 `2026-10-30 23:00`（若执行日已晚于此时，则选下一周的未来日期），点击“保存设置”，刷新页面。预期状态显示累计上限 0、已使用 0、已预留 0，表单值仍在；这只验证数据持久化且继续禁止成员模型调用，不测试付费模型或账单。失败时保留页面错误截图，不重复提交其他值。

**2026-10-22 用户截图回传：**额度页显示 `staging_teacher_a_20261018` 的累计上限、已使用、已预留均为 0，截止 `2026-10-30 23:00`，表单保留相同值。按用户上一项操作上下文记录；截图本身没有保存提示或刷新证据。此处不记录为助手直接访问服务器、真实调用或账单核对。后续普通成员权限和本人配置入口验收不得要求用户向聊天提供密码；如果没有已登录的普通成员会话，先做只读服务端权限验证。

**2026-10-22 用户刷新确认：**用户随后回复“刷新后仍正常”；额度页的 0/0/0 与截止时间在刷新后仍可见，零额度保存/读取浏览器验收通过。仅据用户反馈，不代表助手连接了 Ubuntu 或核验厂商费用。下一项为普通成员的管理页访问拒绝和本人生成/修改页入口，继续保持 AI 关闭；不要为测试索取或猜测教师密码。

**2026-10-22 两窗口权限检查反馈：**用户报告无痕窗口“可以进入”，非无痕窗口显示 403；尚不知无痕窗口登录账号和最终地址。先让用户只看无痕窗口页面右上角用户名、地址栏与页面标题；不要索取密码、Cookie、浏览器存储或重复重置账号。确认身份后再评估是否为权限问题，不以浏览器模式本身推断权限。

**2026-10-22 无痕窗口地址已核：**用户提供 `http://127.0.0.1:18002/members/3/allowance/`。下一步只确认该无痕窗口页面右上角登录用户名；若显示管理者则可进入属预期，若显示无管理权限的普通成员却能看到额度表单，则停止进一步写操作并排查权限。不要尝试保存或变更额度。

**2026-10-22 无痕窗口身份已核：**用户确认当前账号为 `staging_manager_20261018`，管理额度页可访问属预期。下一现场动作只在返回 403 的非无痕窗口打开预发布首页查看右上角用户名；若被重定向到登录页，记录该事实即可。不需要输入或发送密码，也不修改额度。

**2026-10-22 非无痕窗口身份已核：**用户确认登录 `staging_teacher_a_20261018`，其访问管理页面返回 403；管理者窗口访问额度页成功。浏览器权限验收通过。下一只读检查可在普通教师窗口打开 `http://127.0.0.1:18002/create/`，查看“模型状态”是否显示预发布手动排队提示、页面是否没有成员模型配置选择器；不要上传资料或点击生成。在线配置 `AI_MEMBER_TASKS_ENABLED=0` 且 `AI_STAGING_MANUAL_QUEUE=1`，旧手动排队按钮可能可用，但排队本身不自动发送模型请求。

**2026-10-22 普通教师生成页截图反馈：**“模型状态”显示预发布手动排队已启用，生成只会建立待处理任务；管理员人工核对并临时输入 Key 前不会自动发送。截图没有覆盖整个页面，故不能据此确认是否存在或不存在选择器，也没有任何点击/上传行为证据。成员 0 次额度仅约束未来成员调用路径，不约束旧手动队列；备份及后续开关设计须明确这一区别。

**2026-10-22 阶段 2C 保存后备份脚本准备（本机通过，Ubuntu 未执行）：**新脚本为 `scripts/backup_ubuntu_staging_phase2c_allowance.sh`（SHA-256 `dec1728ae8ab982164f2c48eb80db4f39346a2948831c04a4dc73e4ae2dc58d1`）及 `scripts/restore_ubuntu_staging_phase2c_allowance.sh`（SHA-256 `a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d`）。本机 Bash 语法、内嵌 Python 语法、LF 与错误主机拒绝通过；尚未上传、备份或恢复。第一现场动作只上传两个新文件并核对远端 SHA-256 与 Bash 语法；得到上传标记后再执行会短暂停止预发布 Web/网关的备份。不要在 2C 在线状态运行固定旧镜像的 2B 备份脚本，也不要记录未执行的现场结果。

**2026-10-22 首次上传未执行：**用户完整 PowerShell 历史表明粘贴顺序变为先运行远端校验，再运行错误处理，`scp` 排在抛错之后而未执行。远端脚本缺失由此解释；没有传输失败的证据，更没有备份/恢复行为。改用本机 `scripts/upload_ubuntu_staging_phase2c_allowance.ps1` 单入口顺序执行本地哈希、远端无目标与固定主机预检、`scp`、远端摘要和 Bash 语法；本机 `-LocalCheckOnly` 返回 `STAGING_2C_UPLOAD_LOCAL_HASHES_OK`，完整远端流程未执行。用户下一步只运行该文件，最后应见 `STAGING_2C_ALLOWANCE_SCRIPTS_UPLOAD_VERIFIED`；若远端已出现目标或任一环节失败，停止并反馈非敏感输出，不覆盖文件。

**2026-10-22 单入口上传器用户进度：**目前只见 `STAGING_2C_UPLOAD_LOCAL_HASHES_OK`；远端预检、传输及最终校验状态未知。先核对原 PowerShell 窗口是否处在 SSH 密码提示或已返回提示符；不在该状态未明时重复上传。

**2026-10-22 上传器首次 SSH 预检中止：**用户 PowerShell 报 `Connection closed by 10.0.30.5 port 22` 及上传器第 28 行预检失败；按脚本顺序本次未执行 `scp`，无上传或备份操作。不要仅凭合并错误提示断言远端文件存在或覆盖它们。下一现场动作仅在用户自己的 Windows PowerShell 运行 `Test-NetConnection 10.0.30.5 -Port 22 | Select-Object ComputerName,RemotePort,TcpTestSucceeded`；若为 `False`，先恢复 EasyTier/网络/SSH 连通，若为 `True`，再作只读 SSH 主机名、用户及目标存在性诊断，不直接重跑上传器。

**2026-10-22 用户端口结果及下一诊断：**用户反馈 TCP 22 为 `True`。下一个操作只在同一 Windows PowerShell 使用 `ssh -tt huahua@10.0.30.5 "hostname; id -un; ls -ld -- /home/huahua/backup_ubuntu_staging_phase2c_allowance.sh /home/huahua/restore_ubuntu_staging_phase2c_allowance.sh 2>&1; echo STAGING_2C_SSH_DIAGNOSTIC_DONE"`。该命令只读；末尾标记表示远端命令已执行，前面的主机名、用户名和路径状态用于诊断。密码仅在本机 SSH 提示输入，不发聊天。此步不上传、不覆盖或运行备份。

**2026-10-22 用户 SSH 诊断及修订上传器：**现场输出 `teacher-workbench`、`huahua`、两个目标均不存在、`STAGING_2C_SSH_DIAGNOSTIC_DONE`。可继续上传，但仍以脚本运行时目标不存在的预检为准。`scripts/upload_ubuntu_staging_phase2c_allowance.ps1` 已在本机改为远端 `ssh -tt`，新摘要 `5a2266974f6d9fee7c5755bde074ba830be38480ce22e3767649b5d5d0d42f95`，PowerShell 语法及本地摘要检查通过。下一现场操作在 `D:\Projects\teacher-workbench` 的 Windows PowerShell 执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\upload_ubuntu_staging_phase2c_allowance.ps1`；预期顺序为本地摘要标记、目标空闲标记、两文件 `scp`、远端摘要和 Bash 语法、最终 `STAGING_2C_ALLOWANCE_SCRIPTS_UPLOAD_VERIFIED`。若中途 SSH 或 SCP 失败，停止并反馈末尾非敏感输出；不直接运行备份。

**2026-10-22 2C 脚本上传现场通过；下一备份操作：**用户返回两份脚本摘要 `OK` 和最终 `STAGING_2C_ALLOWANCE_SCRIPTS_UPLOAD_VERIFIED`。在 Windows PowerShell 执行 `ssh -tt huahua@10.0.30.5 "cd /home/huahua && echo 'dec1728ae8ab982164f2c48eb80db4f39346a2948831c04a4dc73e4ae2dc58d1  backup_ubuntu_staging_phase2c_allowance.sh' | sha256sum -c - && bash -n backup_ubuntu_staging_phase2c_allowance.sh && bash backup_ubuntu_staging_phase2c_allowance.sh"`。SSH 和脚本内 `sudo -v` 可能各提示一次密码，只在终端输入。脚本仅触及虚构预发布，预检通过后会短暂停 Web/网关并自动尝试重启；不要关闭窗口或并发运行其他备份。成功以 `STAGING_2C_WEB_RESTARTED_HTTP_200`、`STAGING_2C_PAIRED_FILES_VERIFIED`、`STAGING_2C_BACKUP_DIR=` 和 `STAGING_2C_ESCROW_DIR=` 为准；失败时不要重跑，先反馈末尾非敏感输出并检查预发布是否恢复。独立恢复将在备份成功后单独运行。

**2026-10-22 原备份脚本预检失败与 v2 重试计划：**用户仅见原脚本摘要 `OK` 后 `python3: can't open file .../teacher-workbench-staging-phase2c-20261022/scripts/check_staging_env.py`。按脚本顺序，失败在 `sudo -v` 和 `STAGING_2C_APPLICATION_STOP_START` 之前，原脚本没有停止服务或创建新备份。原 2C 配置目录没有完整源码，不得在其下寻找检查器或归档 `manage.py`。本机新建 `backup_ubuntu_staging_phase2c_allowance_v2.sh`（SHA-256 `fecb5bc9fd5f118e75d25a72cab467a768912279ff59fa61cb302d09684c6a47`），前置核对旧 2B 检查器、2C 构建清单及镜像 ID，并在停 Web/网关前归档 2C 源码、Compose 与 Nginx 配置。保留原脚本。下一用户操作只在 Windows PowerShell 执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_allowance_backup_v2.ps1"`；包装器先核对本地哈希、远端新目标不存在、`scp`、远端摘要和 Bash 语法，再运行 v2。仅最终 `STAGING_2C_PAIRED_FILES_VERIFIED` 与两个目录表示备份通过；中途失败不重复执行，先反馈末尾非敏感输出。v2 包装器本机语法与 `-LocalCheckOnly` 通过，Ubuntu 实际运行待验。

**2026-10-22 v2 备份早期退出；下一步仅只读诊断：**用户见 v2 远端摘要 `OK`，未见第一个脚本预检标记，SSH 结束，包装器报非零退出。不要再次执行 v2，也不要推断备份已生成或在线 HTTP 正常。新诊断脚本只读检查备份脚本的前置条件，不调用 sudo 或 Docker；本机 SHA-256 `73d9f9237916c9fbc055d3f5d8d88cce880252ada34dfd962cff56c938943f7b`、Bash 语法和 LF 通过。下一用户操作在 Windows PowerShell 只运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_backup_diagnostic.ps1"`；它先确认远端诊断目标不存在并上传，之后逐项只输出非敏感 `OK/FAIL` 与 `STAGING_2C_BACKUP_PREFLIGHT_DIAG_DONE`。包装器本机语法与摘要预检通过；如有 `FAIL`，先修复本地脚本或查明现场状态，暂不运行备份。

**2026-10-22 用户诊断结果及 v3 重试计划：**用户现场仅 `STAGING_2C_DIAG_CONFIG_STATE=FAIL`，其余固定路径/权限/配置/镜像匹配/源码摘要均 `OK`。`apply_ubuntu_staging_phase2c.sh` 在成功结束前写 `STAGING_2C_ONLINE_SWITCH_COMPLETE`，v2 错将在线目录按未切换状态 `STAGING_2C_CONFIG_PREPARED` 校验。v3 备份脚本改为只接受在线完成状态，显式报 `STAGING_2C_SNAPSHOT_ONLINE_STATE_UNEXPECTED`，并在 sudo 后增加 Docker 预检开始标记；SHA-256 `2ccf1d8fe99d79107ad350717a2e9e2a31de8236b80887cd4cd310f83a86c531`。新的单入口包装器 SHA-256 `2f5068872a8787e4230dcece5e776f24c0180dcc67ac5a47962e899aa7973cef`，本机语法与本地摘要通过。下一用户操作在 Windows PowerShell 只执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_allowance_backup_v3.ps1"`；它先确认新目标不存在、上传并核对摘要/语法，然后运行 v3。可能要求 SSH、sudo 密码，只在终端输入。成功须见零额度校验、预发布 Web 重启 HTTP 200、`STAGING_2C_PAIRED_FILES_VERIFIED` 及两条目录；若失败保留末尾输出，不重跑或清理旧目录。独立恢复仍单独验收。

**2026-10-22 v3 备份实际执行（用户终端成功）：**用户输出零额度和 2 条虚构配置校验、源站登录页 HTTP 200、停止预发布 Web/网关写入、数据库及私有文件和镜像归档、应用重启 HTTP 200、配对文件校验及 `STAGING_2C_BACKUP_V3_WRAPPER_DONE`。备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-j33bqT1R`，同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-j33bqT1R`。下一现场操作在 Windows PowerShell 运行已上传的 `restore_ubuntu_staging_phase2c_allowance.sh`（SHA-256 `a0ec855318de8200c70a684048ea18b50bc526499da3670536ac67198a538e8d`），参数为上述备份目录。脚本只建隔离网络/卷并留存恢复卷，不切换在线服务；成功需见 `STAGING_2C_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_2C_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE` 和 `STAGING_2C_INDEPENDENT_RESTORE_VERIFIED`。失败不直接重跑或清理，反馈非敏感末尾输出。
**2026-10-22 2C 新卷独立恢复实际执行（用户终端成功）：**备份 `backup-phase2c-allowance-j33bqT1R` 使用同机密钥副本恢复到 `/home/huahua/teacher-workbench-staging-phase2c-allowance-restore-j33bqT1R`；最终 `STAGING_2C_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_2C_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2C_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_2C_INDEPENDENT_RESTORE_VERIFIED`。脚本创建独立容器/网络/卷，结束后停止恢复容器、保留卷；没有切换在线站点。`Forbidden` 和 `Not Found` 属有意检查普通教师与跨账号拒绝，不能当恢复失败。后续 NAS 数据复制和单独密钥恢复仍须配对验证；助手未直连 Ubuntu。
**2026-10-22 2C NAS 专用脚本准备（仅本机验证）：**`scripts/transfer_staging_phase2c_allowance_nas.py` SHA-256 `8c787c3bbdcae98c56eea8faff3ffee3363a855628c3220fdd9e148c8c854bdd`，固定源 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-j33bqT1R`，只传数据库、私有文件、镜像、源码及摘要，**不传主密钥**。`scripts/restore_ubuntu_staging_phase2c_from_nas_usb.sh` SHA-256 `9020a7c7420dd926cf057ec1ca36c517c58b00193df61610f7cbc90367f6637e`，需 NAS 导入目录及此前 USB 返回包恢复目录 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1`，并在新卷核对密钥指纹、0 次额度及权限。本机 Python 语法、5 段内嵌 Python、PowerShell 语法、LF 和固定路径检查通过；Ubuntu Bash 语法与全部现场流程未验证。下一用户动作在 **Windows PowerShell** 只运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_nas_copy.ps1"`；包装器先核对本地 SHA、远端新目标不存在、上传并核对远端 SHA 与 Python 语法，然后运行 NAS 数据复制。成功须见 `STAGING_2C_NAS_DATA_FILES_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_BACKUP_NAME=`、`STAGING_2C_NAS_DATA_COPY_DONE` 与包装器结束标记；失败不要重跑或手工清理 NAS staging 目录，反馈非敏感末尾输出。
**2026-10-22 2C NAS 数据复制实际执行（用户终端成功）：**NAS 名称 `staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0`；八个数据文件逐项校验、`STAGING_2C_NAS_DATA_FILES_VERIFIED`、专用挂载清理和最终 `STAGING_2C_NAS_COPY_WRAPPER_DONE` 均出现。下一用户动作仅在 Windows PowerShell 运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_staging_phase2c_nas_import.ps1" -NasBackupName "staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0"`。它核对已上传脚本 SHA，再以只读 NFS 挂载导入并校验至新本地目录；成功须见 `STAGING_2C_NAS_LOCAL_IMPORT_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_LOCAL_IMPORT_DIR=`、`STAGING_2C_NAS_DATA_IMPORT_DONE` 和包装器完成标记。若失败先反馈非敏感输出，不覆盖或清理现有备份。

**2026-10-22 2C NAS 数据只读导入实际执行（用户终端成功）：**NAS 名称 `staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0`，导入目录 `/home/huahua/teacher-workbench-nas-import-staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0`；10 个文件逐项校验、`STAGING_2C_NAS_LOCAL_IMPORT_VERIFIED`、专用挂载清理、`STAGING_2C_NAS_DATA_IMPORT_DONE` 与包装器完成标记均出现。下一现场动作在 Windows PowerShell 运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_nas_usb_restore.ps1" -NasBackupName "staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0"`。包装器先校验本地恢复脚本 SHA、远端目标不存在、上传并在远端校验 SHA/Bash 语法；恢复脚本核对 NAS 导入文件和此前 U 盘返回密钥的指纹，然后只在新网络/卷恢复，在线站点保持原样。成功需见 `STAGING_2C_NAS_USB_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_2C_NAS_USB_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2C_NAS_USB_INDEPENDENT_RESTORE_VERIFIED` 与包装器完成标记；失败不要重跑或清理，先反馈非敏感末尾输出。


**2026-10-22 2C NAS+USB 首次恢复失败（用户终端）：**数据库和私有文件导入至第一套隔离卷后，内容验证容器的 `DB_HOST` 使用过长容器名，Python IDNA 解析报 `UnicodeError: label too long`。脚本原有 EXIT trap 应尝试停止隔离 DB/Redis，但用户输出未含停止确认；不要直接重跑原脚本或清理卷。原导入目录和先前本机备份不修改。后续 v2 脚本将用短 Docker 网络/容器/卷名称和新隔离目录，先核对旧隔离容器状态，再完整重新恢复与验收。


**2026-10-22 2C NAS+USB v2 修订与下一操作（本机检查通过，现场未执行）：**新脚本 `restore_ubuntu_staging_phase2c_from_nas_usb_v2.sh` SHA-256 `68ad19950ad5880ecbaa3be2398e9c997c31d6f722bdd4530fb57422eea564e8`，短 Docker 名称避开首次失败的 DNS 标签长度限制；保留旧失败卷，只读检查旧两个容器 `exited`，新建另一套隔离资源。包装器 `upload_and_run_ubuntu_staging_phase2c_nas_usb_restore_v2.ps1` SHA-256 `acecec6527543a7f2b27798d04724dfbc1ad23de0ca94652c5c7d355d980aef3`，本地语法/摘要检查通过。下一用户动作在 Windows PowerShell 只运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_nas_usb_restore_v2.ps1"`。包装器先校验本地 SHA、远端新脚本目标不存在、上传并核对远端 SHA/Bash 语法，再运行 v2；不切换在线站点。成功标记为 `STAGING_2C_NAS_USB_V2_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_2C_NAS_USB_V2_SOURCE_LOGIN_HTTP_200_AFTER_RESTORE`、`STAGING_2C_NAS_USB_V2_INDEPENDENT_RESTORE_VERIFIED` 和包装器完成标记；若旧容器不是 `exited` 或其他失败，停止并反馈非敏感输出，不重跑或清理。


**2026-10-22 2C NAS＋U 盘返回密钥 v2 独立恢复实际执行（用户终端成功）：**首次失败隔离容器均为 `exited`；v2 从 `/home/huahua/teacher-workbench-nas-import-staging-phase2c-allowance-data-j33bqT1R-35ee25496ce0` 与 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1` 配对，在另一套新网络/卷恢复，输出内容/Key/额度/访问断言通过、源站登录页 HTTP 200、恢复容器停止且卷保留，最终 `STAGING_2C_NAS_USB_V2_INDEPENDENT_RESTORE_VERIFIED` 和 `STAGING_2C_NAS_USB_V2_WRAPPER_DONE`。新目录 `/home/huahua/teacher-workbench-staging-phase2c-nas-usb-restore-35ee25496ce0-v2`。旧失败卷、成功恢复卷、NAS 原件及导入目录均保留；本轮不清理。该结果限同一 Ubuntu 主机，不宣称整机替换或自动定时备份通过。

**滞留成员调用维护命令（本机代码已写，Ubuntu 未安装）：**先在隔离测试库运行 `python manage.py reconcile_member_calls`，只输出过期的未发送预留数和已发送滞留任务数，不展示账号、资料或 Key。`--min-age-minutes` 默认 60 且不可低于 10；执行前还应确认没有正在等待厂商响应的工作进程。经核对备份和预览结果后，显式 `python manage.py reconcile_member_calls --apply` 才会更新状态：未发送预留释放；已标记发送的调用保留次数，滞留任务失败并提示核对厂商账单。命令不会重试请求或核对真实账单。当前 Ubuntu 镜像尚无此命令，不得把上述示例当成已执行的服务器操作，也不在在线预发布库直接演练。

**阶段 2C 零额度与维护命令隔离 PostgreSQL 复验（本机准备完成，Ubuntu 未执行）：**`scripts/build_staging_phase2c_guard_bundle.py` 生成仅含 76 个白名单源码文件的 `data/deploy/teacher-workbench-stage2c-guard-source.tar.gz`，SHA-256 `cb133427b8f693582747d708cd4d21f5199f8328da7731e2ee64a01ae4a0799e`；不含环境文件、资料、数据库、主密钥或依赖轮子。`scripts/verify_ubuntu_staging_phase2c_guard_pg.sh` SHA-256 `8c5535e6be10e0ac4d7ede0cd713f9a9d058a0be674b3fb80544ed3f78beec26`，只建立新的内部 Docker 网络、PostgreSQL 测试卷及一次性测试容器；使用在线 2C 镜像作为只读依赖来源，挂载新源码，显式设置 AI 关闭和空 Key 路径，运行虚构测试。测试后停止隔离数据库、保留测试卷，并只读核对两个原登录页 HTTP 200。不会迁移在线库、切换镜像、安装维护命令或访问厂商。单入口包装器 `scripts/upload_and_run_ubuntu_staging_phase2c_guard_pg.ps1` SHA-256 `36dc44f36f37d8258d801add8fdc979e08e88ba05f673e2f643a8e6017a609c8`。本机语法、清单、摘要、错误主机拒绝与 `-LocalCheckOnly` 通过；Docker/PostgreSQL 现场测试未执行。

用户下一步在 **Windows PowerShell** 只执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_guard_pg.ps1"
```

该命令先校验本地两个文件摘要、检查 Ubuntu 新目标不存在，上传后核对远端摘要与 Bash 语法，再在交互式 SSH 中提示输入 `sudo` 密码并运行隔离测试；密码只在终端输入。成功标准为 `STAGING_2C_GUARD_PG_TESTS_OK`、`STAGING_2C_GUARD_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_GUARD_DB_STOPPED_VOLUME_PRESERVED`、`STAGING_2C_GUARD_PG_ISOLATED_VERIFIED` 和 `STAGING_2C_GUARD_PG_WRAPPER_DONE`。若失败，不重跑或清理已创建的隔离资源，先反馈末尾非敏感输出；现场状态核对后再决定处理。

**2026-10-22 首次隔离 PostgreSQL 测试实际失败（用户终端）：**原包装器上传与清单、隔离预检均通过，创建全新测试 DB 后 40 项有 1 项失败。原因是生成页面测试把 SQLite 的“不调用队列”断言套用到 PostgreSQL；现场 mock `Queue` 收到受额度保护的成员任务路径，并非模型请求。脚本返回 `STAGING_2C_GUARD_DB_STOP_REQUESTED_VOLUME_PRESERVED`、`STAGING_2C_GUARD_ISOLATED_TEST_FAILED`；未到在线双登录页核对和 DB `exited` 确认。原脚本、归档、测试目录、网络和卷保留，不重复运行。修订版先只读检查旧 DB `tw2c-guard-cb133427b8f6-db` 已停止，失败即退出，不自动清理。

**隔离 PostgreSQL v2 准备（本机通过，Ubuntu 尚未执行）：**生成与修改页面测试都已按 SQLite/PostgreSQL 各自队列路径明确断言，并核对任务确实保持排队。v2 独立源码归档 `teacher-workbench-stage2c-guard-v2-source.tar.gz` SHA-256 `ee34113e8aa9fe17554b0c19d70f02701c56f8a016a8ce0a7cbed42433e830cc`，仍为 76 个白名单文件；`verify_ubuntu_staging_phase2c_guard_pg_v2.sh` SHA-256 `fafeee74194b46d30cbfc232656ba0053317cd2b2281215a9c605552739e8f9c`，使用新的 `tw2c-gv2-ee34113e8aa9-*` 资源；包装器 `upload_and_run_ubuntu_staging_phase2c_guard_pg_v2.ps1` SHA-256 `b7fa9c22eae843eae3d82c0a93418aeb7f6d54416d40ccdc0fe390d44ee8247e`。本机 39 项 SQLite 测试、Django 检查、迁移检查、归档清单、Bash/PowerShell 语法、嵌入 Python、错误主机拒绝和包装器本地哈希检查均通过。**前一条原版包装器不再运行。**

下一现场操作仅在 **Windows PowerShell** 执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_guard_pg_v2.ps1"
```

该包装器先核对本地哈希、远端新目标空闲、上传及远端哈希/Bash 语法；SSH 和 sudo 密码仅在终端输入。v2 在创建新资源前必须输出 `STAGING_2C_GUARD_V2_PREVIOUS_DB_STOPPED`，随后应见 `STAGING_2C_GUARD_V2_PG_TESTS_OK`、`STAGING_2C_GUARD_V2_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_GUARD_V2_DB_STOPPED_VOLUME_PRESERVED`、`STAGING_2C_GUARD_V2_PG_ISOLATED_VERIFIED` 与包装器完成标记。任何一步失败都不重跑或清理，先反馈末尾非敏感输出。该脚本不触碰在线数据库、密钥或应用部署，也不请求模型。

**2026-10-22 v2 实际执行（用户终端成功）：**旧 DB 停止确认、清单和隔离预检、40 项 PostgreSQL 测试全过、新旧登录页 HTTP 200、v2 测试 DB 停止且卷保留，以及最终隔离验证/包装器完成标记均出现。目录 `/home/huahua/teacher-workbench-stage2c-guard-v2-ee34113e8aa9`。没有将新源码复制到在线应用目录，也没有切换镜像或运行模型。旧失败卷与本次成功测试卷均保留；本轮不清理。后续在线部署若涉及代码/迁移，仍须另备份及回退计划，不能以这次隔离测试替代。

**本人作业页调用记录（2026-10-22 本机代码）：**`workbench/views.py` 只在本人作业查询中预取调用记录，`templates/workbench/_task_call_usage.html` 展示状态与可靠 token 用量；不展示 Key、原始请求、费用估算或厂商账单。自动测试已在本机通过，尚无部署脚本或 Ubuntu 页面验收；当前在线 2C 镜像仍使用原页面，不能把本机截图或测试写成现场功能已上线。

**调用记录页面隔离 PostgreSQL v3（2026-10-22 本机准备完成，Ubuntu 未执行）：**新增独立归档 `data/deploy/teacher-workbench-stage2c-guard-v3-source.tar.gz`，77 个白名单源码文件，SHA-256 `14537acaacc62f0584cd3d567028b158fe3d3cfab501128fdba6a5ba7b1105ca`；验证脚本 `scripts/verify_ubuntu_staging_phase2c_guard_pg_v3.sh` SHA-256 `d2cd1085f0dcdd0bbc35931bb17a0928ca836a57558744f8dc5fd104d5241366`；Windows 包装器 `scripts/upload_and_run_ubuntu_staging_phase2c_guard_pg_v3.ps1` SHA-256 `69506ee8892742b076371492e71e9ff8c48f3bc7397ccd66d064f89383f07091`。本机哈希、归档内容、Bash 语法、嵌入 Python、错误主机拒绝和包装器 `-LocalCheckOnly` 通过。保留 v2 已通过结果，不覆盖任何旧包。v3 先确认 v2 DB 已停，再创建新内部 Docker 网络及 PostgreSQL 卷；仅用虚构测试与空 Key 路径，运行后停止测试 DB 并核对原双登录页，不部署在线站点、不发模型请求。

下一现场操作只在 **Windows PowerShell** 执行这一条：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_phase2c_guard_pg_v3.ps1"
```

SSH 和 sudo 密码仅输入终端。预期看见 `STAGING_2C_GUARD_V3_PG_TESTS_OK`、`STAGING_2C_GUARD_V3_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_2C_GUARD_V3_DB_STOPPED_VOLUME_PRESERVED`、`STAGING_2C_GUARD_V3_PG_ISOLATED_VERIFIED` 及包装器完成标记。若失败，不重跑或清理新卷，先反馈末尾非敏感输出。通过后再计划独立的在线备份、恢复和切换验收；隔离测试本身不表示页面已上线。

**2026-10-22 v3 隔离 PostgreSQL 实际结果（用户终端）：**42 项全部通过，旧 v2 DB 已确认停止，原双登录页 HTTP 200，v3 测试 DB 停止并保留卷；`STAGING_2C_GUARD_V3_PG_ISOLATED_VERIFIED` 与包装器完成标记均出现。隔离目录 `/home/huahua/teacher-workbench-stage2c-guard-v3-14537acaacc6`。测试没有切换在线镜像；页面发布前还需新配对备份、独立恢复、镜像构建与上线核验。此项由用户在 Ubuntu 现场运行，助手未直连。

**调用记录页面候选镜像离线构建（2026-10-22 本机脚本已写，Ubuntu 未执行）：**固定构建脚本 `scripts/build_ubuntu_staging_call_usage_offline.sh` SHA-256 `29b33d3747b698a313fc5bc8d60c9b181a9ef234d46aeec86e6f50e828436f51`；Windows 包装器 `scripts/upload_and_run_ubuntu_staging_call_usage_offline.ps1` SHA-256 `b9016a5c493b5db66fa1de01ec454b5822780eb8dc30788322dd2ee29994eda2`。包装器先核对本地 v3 包与脚本摘要，再确认 Ubuntu 上 v3 包摘要及新脚本目标未占用，上传脚本并执行。构建脚本先检查在线 2C 镜像和已有配对备份，确保新包没有遗漏旧源码、依赖列表未改变；随后禁网构建新 Docker 标签并核对镜像内容和 Django 配置。它不停止或重建在线容器、不访问在线数据库或密钥，也不更改 Compose。镜像失败时保留现场目录供检查。

下一现场操作只在 **Windows PowerShell** 执行一条：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_call_usage_offline.ps1"
```

SSH 与 sudo 密码只在终端输入。成功须见 `STAGING_CALL_USAGE_IMAGE_SOURCE_MATCH_OK`、`STAGING_CALL_USAGE_IMAGE_DJANGO_CHECK_OK`、`STAGING_CALL_USAGE_ONLINE_LOGINS_STILL_HTTP_200`、`STAGING_CALL_USAGE_OFFLINE_IMAGE_BUILT_NO_SWITCH` 和包装器完成标记。若失败，不重跑或清理镜像/目录，反馈末尾非敏感输出。成功后仍要做新的在线配对备份、独立恢复和切换计划；本步不让新页面上线。

**2026-10-22 候选镜像现场构建结果（用户终端）：**源码和原镜像匹配，禁网构建完成；新镜像源码摘要及 Django 检查通过，原 18002/18000 登录页 HTTP 200。新镜像 ID `sha256:7085c5f4041b8ee8a199e53c575c3e01ffcc17a21a86ae5525c4da9731f85c26`，目录 `/home/huahua/teacher-workbench-staging-call-usage-14537acaacc6`，最终未切换与包装器完成标记均出现。此为用户终端反馈，助手未直连；不能视作页面已上线。

**调用记录页面上线前新配对备份与独立恢复（2026-10-22 本机准备完成，现场待执行）：**编排脚本 `scripts/backup_restore_ubuntu_staging_call_usage_pre_switch.sh` SHA-256 `777d89726c19f169d11a2c96802bea998ee6437539715b285e0e1fdaef1d0eac`；Windows 包装器 `scripts/upload_and_run_ubuntu_staging_call_usage_pre_switch_backup.ps1` SHA-256 `85b2cfb447d3ce98fbb476a758f03c46c54a2031a2631f13f89a6ed41ddc62ba`。编排脚本只调用已在服务器使用过且摘要固定的旧 2C 配对备份和独立恢复脚本，先核对在线仍运行旧镜像、新候选镜像只在本地 Docker；从本次新备份自动取得目录，恢复到新的隔离卷，保留私有日志。备份会短暂停止预发布 Web/网关以截取一致数据，脚本随后重启并核对登录页；如果备份失败，旧备份脚本尝试恢复服务，但仍须以现场输出确认。不会把候选镜像切到在线站。

下一现场操作只在 **Windows PowerShell** 执行一条：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_call_usage_pre_switch_backup.ps1"
```

SSH 和 sudo 密码仅在终端输入；过程可能持续数分钟，等待最终标记。成功须见 `STAGING_CALL_USAGE_FRESH_BACKUP_VERIFIED`、`STAGING_CALL_USAGE_FRESH_RESTORE_VERIFIED`、`STAGING_CALL_USAGE_ONLINE_LOGINS_AFTER_RESTORE_HTTP_200`、`STAGING_CALL_USAGE_PRE_SWITCH_BACKUP_RESTORE_OK` 和包装器完成标记。若失败，不重跑或删除备份、隔离卷，先反馈末尾非敏感输出；如原登录页不可用也一并说明。成功后再对候选镜像与新恢复数据做隔离烟测，随后才考虑在线切换。

**2026-10-22 新备份和独立恢复现场结果（用户终端）：**新配对备份 `/home/huahua/teacher-workbench-staging-backups/backup-phase2c-allowance-szRPlLy0`，同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-szRPlLy0`，恢复副本 `/home/huahua/teacher-workbench-staging-phase2c-allowance-restore-szRPlLy0`。`STAGING_CALL_USAGE_FRESH_BACKUP_VERIFIED`、`STAGING_2C_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_CALL_USAGE_FRESH_RESTORE_VERIFIED`、原双登录页 HTTP 200、最终编排及包装器完成标记均出现。恢复容器已停止、卷保留。403/404 为权限拒绝断言的预期日志。此结果由用户终端提供，助手未连接服务器；候选镜像尚未在这份恢复数据上运行。

**候选镜像对新恢复副本的隔离烟测（2026-10-22 本机准备完成，Ubuntu 未执行）：**固定脚本 `scripts/verify_ubuntu_staging_call_usage_restored_smoke.sh` SHA-256 `001a794a84df0a35e387d1fd1b47ab635514eccb9a6ed54f6f07e6425a378568`；Windows 包装器 `scripts/upload_and_run_ubuntu_staging_call_usage_restored_smoke.ps1` SHA-256 `5add14eefc6b9191b1a3cc3b123571c3ef2e1dfa2f1f121fd413c8df7b2f242b`。脚本核对本次新备份、独立恢复记录、候选镜像及密钥指纹，然后短暂启动已停止的隔离 DB/Redis。候选镜像以 AI 和成员调用关闭、私有卷与虚构密钥只读挂载运行 Django 检查、迁移核对及虚构旧内容/新增模板/跨账号拒绝断言；测试客户端只可能改动隔离恢复副本的会话表。随后停止恢复容器，确认在线仍是旧镜像及双登录页 HTTP 200。失败时保留新卷与日志，不自动重跑。

下一现场操作只在 **Windows PowerShell** 执行一条：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_call_usage_restored_smoke.ps1"
```

成功须见 `STAGING_CALL_USAGE_CANDIDATE_RESTORED_CONTENT_AND_PAGE_OK`、`STAGING_CALL_USAGE_RESTORED_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_CALL_USAGE_CANDIDATE_RESTORED_SMOKE_VERIFIED_NO_SWITCH` 和包装器完成标记。若失败，不重复执行或清理恢复副本，反馈末尾非敏感输出。此项不会让新页面上线；通过后再核对独立的在线切换与回退方案。

**2026-10-22 隔离烟测现场结果（用户终端）：**上述四个最终标记均已出现；候选镜像对旧内容、零额度、虚构配置与调用记录模板通过验证，恢复容器已停止且卷保留；在线原双登录页仍 HTTP 200。助手未直连 Ubuntu，在线调用记录页面仍未切换。

**下一现场操作：预发布调用记录代码切换（2026-10-22 本机准备；Ubuntu 待执行）。**Windows 包装器 `scripts/upload_and_run_ubuntu_staging_call_usage_switch.ps1` 上传固定哈希脚本到 Ubuntu 257 并运行。Ubuntu 脚本 `scripts/apply_ubuntu_staging_call_usage.sh` SHA-256 为 `95311c3a18c9fabadab1517f0a55579bc351b31a84f48ed8bf0a11b20de65a88`。先核对已有烟测成功记录和原 Web 镜像，复制旧私有配置并只改变 Web 镜像行；按已验证的 2C 备份脚本在切换前再做一次配对备份（Web/网关会短暂停止），核对备份与同机密钥指纹。然后只重建预发布 Web/网关，检查镜像、零额度、旧内容、新模板、Django 及两个登录页。脚本不运行数据库迁移，不启用成员 AI；切换后任一检查失败，会尝试用原 Compose 重建旧 Web/网关并打印回退结果。备份、旧镜像和旧配置保留；正式环境不变。

在 **Windows PowerShell** 执行一条命令，SSH/sudo 密码只在终端输入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_call_usage_switch.ps1"
```

成功标准：出现 `STAGING_CALL_USAGE_SWITCH_FRESH_BACKUP_VERIFIED`、`STAGING_CALL_USAGE_ONLINE_CONTENT_AI_OFF_AND_PAGE_OK`、`STAGING_CALL_USAGE_NEW_AND_OLD_TEST_LOGIN_HTTP_200`、`STAGING_CALL_USAGE_DEPLOYED_AI_OFF` 及 `STAGING_CALL_USAGE_SWITCH_WRAPPER_DONE`。预发布 `18002` 在备份和镜像切换期间可能短暂中断。若出现失败、SSH 断开或自动回退标记，先反馈非敏感末尾输出并检查原预发布登录页；不要直接重跑，也不要删除新备份或隔离卷。成功后仍须由用户在浏览器核对新增调用记录文案、权限及原资料/作业页面；真实模型调用与厂商账单仍未验收。

**2026-10-22 预发布切换现场结果（用户终端）：**即时备份与同机密钥副本核对通过，Web/网关换为新镜像，Django 检查、旧内容/零额度/新模板断言及双登录页 HTTP 200，最终部署和包装器完成标记均出现。新配置目录及 `DgfGf130` 备份路径见 status；助手未直连 Ubuntu。该备份尚未单独恢复；此前 `szRPlLy0` 已完成独立恢复。旧配置和镜像保留作为代码回退来源。**当前下一步是浏览器回归验收，不要重复运行一次性切换脚本。**

浏览器回归：确认本机 SSH 隧道仍连接到预发布 `127.0.0.1:18002`。用虚构预发布账号打开首页，再从“我的作业”打开此前的九年级数学作业，核对任务进度、已有第 1/2 版草稿及两份 Word 下载；用另一虚构账号打开同一作业地址应拒绝访问。在线没有成员模式的调用记录，故此时不要求出现“已计入次数”或 token 用量文案，也不创建付费调用。检查后把实际页面结果记录在 acceptance。若页面异常，保留现场，不自行重跑切换脚本。

**2026-10-22 浏览器作业回归现场结果（用户）：**第 1、2 版草稿可查看，学生卷和教师答案版 Word 均能下载打开。下一项只做跨账号只读检查：在已登录 `staging_teacher_a_20261018` 的独立浏览器会话打开 `http://127.0.0.1:18002/worksheets/1/`，预期 404 且无该作业内容。不得用作业所有者 `staging_preview_20261017` 的同一会话判断越权，也无需发送任何密码。

**2026-10-22 跨账号浏览器结果（用户截图）：**上述普通教师访问作业 1 返回 404、未显示作业内容，权限拒绝通过。截图还显示 Django `DEBUG=True` 的技术 404 路由列表，故增加仅预发布错误页修复，先完成技术修复再重复浏览器检查。

**预发布普通错误页修复（2026-10-22 本机准备；Ubuntu 待执行）：**`scripts/upload_and_run_ubuntu_staging_generic_errors.ps1` 一次上传并校验 Bash 脚本、预发布设置模块和虚构手动任务命令。Ubuntu 脚本 `scripts/apply_ubuntu_staging_generic_errors.sh` SHA-256 `015075ae205da98671764dc1807acdf76e6f2ae24aa526685666ec20b8f14db2`；设置模块 SHA-256 `ea646093d5c44b8c8f9065e245ab920deaffacefddeec61616d77302c8906b5b`；手动命令 SHA-256 `2359750301f4343fc30948c64f599d9c04903b42976b5d7c4e1ff8cf4887d02b`。脚本先验证当前在线镜像、双登录页和此前配对备份 `DgfGf130` 的数据/密钥摘要，再禁网构建仅覆盖上述两个 Python 文件的新镜像。离线检查最终 `DEBUG=False`、普通 404、原手动队列保护和 AI 关闭；然后复制原 Compose/环境配置只替换镜像行，重建预发布 Web/网关，验证旧内容、零额度、CSS、双登录页和普通 404。任何切换后的检查失败会尝试用原 Compose/镜像自动回退。未计划数据库结构变更或付费模型请求；原配对备份、原镜像和配置保留。切换期间预发布页面可能短暂中断。

在 **Windows PowerShell** 执行一条，SSH/sudo 密码只在终端输入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_generic_errors.ps1"
```

成功须见 `STAGING_ERRORS_OFFLINE_GENERIC_404_AI_OFF_OK`、`STAGING_ERRORS_ONLINE_CONTENT_AI_OFF_OK`、`STAGING_ERRORS_GENERIC_404_STATIC_AND_LOGINS_HTTP_OK`、`STAGING_ERRORS_DEPLOYED_AI_OFF` 和 `STAGING_ERRORS_WRAPPER_DONE`。如 SSH 断开或失败，先反馈末尾非敏感输出及 `STAGING_ERRORS_OLD_WEB_RESTORED`/`STAGING_ERRORS_ROLLBACK_NEEDS_REVIEW` 是否出现，不直接重跑或删除备份。成功后用普通教师会话重新打开 `/worksheets/1/`：应仍为 404，但不显示路由列表、技术说明或敏感设置。
**2026-10-22 普通错误页修复现场结果（用户终端）：**`STAGING_ERRORS_ONLINE_CONTENT_AI_OFF_OK`、`STAGING_ERRORS_GENERIC_404_STATIC_AND_LOGINS_HTTP_OK`、`STAGING_ERRORS_DEPLOYED_AI_OFF` 与 `STAGING_ERRORS_WRAPPER_DONE` 均出现。在线预发布配置目录 `/home/huahua/teacher-workbench-staging-errors-20261022`；原 `DgfGf130` 配对备份与旧镜像/配置为回退依据。助手未直连 Ubuntu；不要重复执行一次性切换脚本。浏览器权限和错误页复验仍待用户完成。

**2026-10-22 浏览器复验结果（用户）：**普通教师对作业 1 的跨账号普通 404 页面反馈“正常”，本次错误页修复验收完成。切换脚本为一次性脚本，无需重跑；预发布保留 AI 关闭状态。后续阶段仍需独立备份、恢复和验收计划，不能以本次页面结果替代。

**下一现场操作：错误页修复后的配对备份与独立恢复（2026-10-22 本机准备；Ubuntu 待执行）。**Windows 包装器 `scripts/upload_and_run_ubuntu_staging_errors_recovery.ps1` 在本机核对三份 Bash 文件摘要，经 SSH 固定核对主机和用户、远端文件不存在，上传后再校验摘要与 Bash 语法。Ubuntu 编排脚本先验证当前预发布镜像、双登录页与原有 AI 关闭配置；备份时短暂停止预发布 Web/网关，将数据库、私有文件、当前镜像、源码及独立密钥副本归档并恢复站点；接着在新内部网络和新卷独立恢复并核对虚构内容、零额度、跨账号拒绝、手动任务保护和普通 404。恢复测试结束停止其 DB/Redis，保留隔离卷；原测试站、正式环境及付费模型均不在操作目标内。失败时保留私有日志与现有目录，不直接重跑或清理。相关脚本本机静态检查通过，现场尚未运行。

在 **Windows PowerShell** 执行一条命令，SSH/sudo 密码只在终端输入：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_errors_recovery.ps1"
```

成功标准：看到 `STAGING_ERRORS_RECOVERY_FRESH_BACKUP_VERIFIED`、`STAGING_ERRORS_RECOVERY_FRESH_RESTORE_VERIFIED`、`STAGING_ERRORS_RECOVERY_ONLINE_LOGINS_AND_404_OK`、`STAGING_ERRORS_RECOVERY_BACKUP_AND_RESTORE_OK` 和 `STAGING_ERRORS_RECOVERY_WRAPPER_DONE`，并记录输出的备份/恢复目录。脚本未运行成功前，不把本次新快照写作已验证。若失败，反馈末尾非敏感输出与是否出现 Web 重启标记；不要发送密码或 Key。

**2026-10-24 首次执行结果（用户终端）：**备份已完整结束，Web 重启 HTTP 200，目录 `/home/huahua/teacher-workbench-staging-backups/backup-staging-errors-CLQ37z6Q` 与同机密钥副本 `/home/huahua/teacher-workbench-staging-key-escrow/keyring-CLQ37z6Q`。隔离数据库和私有文件导入后，恢复内容校验第 19 行断言失败；旧恢复脚本不得重跑。经本地逐行定位，脚本把仅允许在线预发布执行的付费手动命令误判为应允许在隔离恢复库运行。此前成功的备份和原隔离卷均保留，尚未收到旧测试容器停止状态标记。

**下一现场操作：只重验同一备份的隔离恢复 v2（本机已准备，Ubuntu 待执行）。**新脚本首先要求首次恢复的两个测试容器均已退出，否则停止；然后创建另一套短名称内部网络和新卷，从上述备份和独立密钥副本恢复。内容检查要求付费手动命令在隔离环境**拒绝**，同时检验虚构资料/作业、Key、0 额度、跨账号权限和普通 404。脚本结束停止本次测试 DB/Redis 并保留卷；不重新备份、不修改在线站点、不发送模型请求。

在 **Windows PowerShell** 执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_run_ubuntu_staging_errors_restore_v2.ps1"
```

成功须见 `STAGING_ERRORS_V2_PREVIOUS_CONTAINERS_STOPPED`、`STAGING_ERRORS_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_ERRORS_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_ERRORS_V2_INDEPENDENT_RESTORE_VERIFIED` 与 `STAGING_ERRORS_V2_WRAPPER_DONE`。若失败，保留现场，不重跑；只反馈末尾非敏感输出，不发送密码或 Key。

**2026-10-24 v2 现场结果（用户终端）：**上述成功标记均出现，新隔离恢复目录 `/home/huahua/tw-errors-v2-CLQ37z6Q`，恢复容器已停、卷保留；源站登录页 HTTP 200。此前失败的隔离容器也被 v2 前置检查确认为 `exited`。当前错误页版本的同机配对备份和独立恢复技术验收完成；不得重复执行旧脚本或 v2 一次性脚本。NAS 异机副本仍需另行转存和恢复验证。

### 2026-10-24 当前错误页快照的 NAS 来源复验（待执行）

目标：只把 `backup-staging-errors-CLQ37z6Q` 的数据包转存到专用 NAS NFS；主密钥不进 NAS。脚本先校验原备份及哈希，临时挂载 `10.0.30.6:/teacher-workbench-backup`，将文件复制到全新随机目录，逐一核对摘要，完成后卸载。不会修改在线预发布、其他 NAS 目录或 PVE。脚本仅限 Ubuntu 257 的 `huahua` 账户通过 sudo 运行。输入 sudo 密码只在终端，不发送到聊天。

**已完成的 NAS 转存操作：**在 Windows PowerShell 运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_staging_errors_nas.ps1" -Mode Copy
```

预期看到 `STAGING_ERRORS_NAS_DATA_SOURCE_VERIFIED`、逐文件验证、`NAS_MOUNT_CLEANED`、`NAS_BACKUP_NAME=staging-errors-data-CLQ37z6Q-...`、`STAGING_ERRORS_NAS_DATA_COPY_DONE` 和 `STAGING_ERRORS_NAS_COPY_WRAPPER_DONE`。反馈末尾非敏感输出，尤其 NAS 名称；若失败，**不要重跑**，先反馈失败标记。只读导回和 NAS/USB 密钥来源的新卷恢复包装器已在本项目准备好，待取得本次随机 NAS 名称后再给出对应单条命令；未执行前不写为验证成功。

**2026-10-24 用户终端结果：**八个数据与元信息文件、NAS 文件集合、临时挂载卸载、复制完成与包装器完成标记均通过。固定 NAS 名称为 `staging-errors-data-CLQ37z6Q-d9bd461df68a`。这是转存成功，尚未从 NAS 导回或恢复；不要再次执行 Copy。

**已完成的只读导回操作：**在 Windows PowerShell 执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_staging_errors_nas.ps1" -Mode Import -NasBackupName "staging-errors-data-CLQ37z6Q-d9bd461df68a"
```

脚本会以只读模式挂载同一 NAS 目录，校验所有文件后复制到 Ubuntu 257 的全新私有导入目录，再卸载；不会更改在线预发布或 NAS 内容。成功须见 `STAGING_ERRORS_NAS_LOCAL_IMPORT_VERIFIED`、`NAS_MOUNT_CLEANED`、`NAS_LOCAL_IMPORT_DIR=...`、`STAGING_ERRORS_NAS_DATA_IMPORT_DONE` 和 `STAGING_ERRORS_NAS_IMPORT_WRAPPER_DONE`。若失败先反馈末尾非敏感输出，不重跑；不要发送密码或密钥。

**2026-10-24 用户终端结果：**十个文件逐项通过校验，私有导入目录 `/home/huahua/teacher-workbench-nas-import-staging-errors-data-CLQ37z6Q-d9bd461df68a` 就绪，NAS 临时挂载已卸载，导回和包装器完成标记齐全。不要再次运行 Import；下一步验证导回数据在新隔离卷可用。

**已完成的 NAS 数据配对离线返回密钥隔离恢复：**在 Windows PowerShell 执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_staging_errors_nas_usb_restore.ps1" -NasBackupName "staging-errors-data-CLQ37z6Q-d9bd461df68a"
```

脚本仅接受这次固定 NAS 导入目录和既有的 USB 返回密钥目录，先校验数据摘要及密钥指纹；若不匹配则在创建恢复卷前停止。匹配后在 Ubuntu 257 创建全新短名称内部 Docker 网络和卷，导入数据库与私有文件，检查虚构资料、Key、零额度、权限拒绝及普通 404。测试容器完成后停止、卷保留，不修改在线预发布，不发模型请求。成功须见 `STAGING_ERRORS_RESTORE_BACKUP_AND_KEY_VERIFIED`、`STAGING_ERRORS_RESTORE_CONTENT_KEYS_ALLOWANCE_AND_ACCESS_OK`、`STAGING_ERRORS_RESTORE_CONTAINERS_STOPPED_VOLUMES_PRESERVED`、`STAGING_ERRORS_NAS_USB_INDEPENDENT_RESTORE_VERIFIED` 和 `STAGING_ERRORS_NAS_USB_RESTORE_WRAPPER_DONE`；同时核对源站登录页 HTTP 200。若失败不要重跑，只反馈非敏感末尾输出，不发送密码或密钥。

**2026-10-24 用户终端结果：**隔离预检、数据库与私有文件导入、内容/Key/额度/权限联合检查、原站登录页 HTTP 200、测试容器停止并保留卷、最终 `STAGING_ERRORS_NAS_USB_INDEPENDENT_RESTORE_VERIFIED` 和包装器完成标记均出现。新目录 `/home/huahua/twerr-nas-d9bd461df68a`。用户提供的是末尾输出，未单独显示前段 `STAGING_ERRORS_RESTORE_BACKUP_AND_KEY_VERIFIED`；按本机核对的脚本控制流，若摘要或 USB 返回密钥指纹未匹配，程序会在创建卷前退出，不能到达最终标记。不要再次运行这一组一次性 Copy、Import 或 Restore 脚本。本次原 Ubuntu 新卷演练完成；空白主机重建、周期性自动备份、真实资料和正式发布均另行安排。

### 2026-10-24 助手直接执行的 EasyTier IP HTTPS 试点

用户授权直接 SSH 到 Ubuntu 257 后，助手运行 `upload_and_prepare_ubuntu_pilot.ps1`：拉取并固定 Caddy 镜像、生成独立私有环境和模型密钥目录、验证 Caddy/Compose，不启动业务。接着运行 `upload_and_start_ubuntu_pilot.ps1`：新库迁移 `0001`～`0008`，四容器启动。首次严格 HTTPS 探针失败，状态保留为 `PILOT_STARTING`。直接查看 Caddy 日志和 OpenSSL 后定位为 IP URL 的 curl 不发送 SNI；助手运行经摘要核对的 `upload_and_fix_ubuntu_pilot_no_sni.ps1`，只替换试点 Caddyfile 并重建网关，保留原 CA 和数据卷，最终 `PILOT_NO_SNI_REPAIR_COMPLETE_AI_OFF`。**上述一次性准备、启动和修复脚本不得重跑。**

试点地址为 `https://10.0.30.5:18443/`，只绑定 Ubuntu 的 `10.0.30.5`。服务器 `curl --cacert` 核验登录页与 CSS 200，Windows TCP 18443 成功；Windows `curl --cacert` 遇内部 CA 无撤销状态而拒绝，加入 `--ssl-no-revoke` 后保留证书链及 IP 校验，登录页 200。CA 公有证书在服务器 `/home/huahua/teacher-workbench-pilot/pilot-root-ca.crt`；本机临时公有副本在 `%TEMP%\teacher-workbench-pilot-root-ca-20261024.crt`，SHA256 证书指纹为 `1B:D4:D9:B8:39:3B:FC:BC:B3:E9:FF:03:C3:23:6E:47:81:0F:91:D8:52:E9:07:ED:91:CE:38:C0:F6:94:47:89`。这不是 CA 私钥。Windows 当前用户根证书库尚未安装该 CA；不要用浏览器“忽略证书错误”登录。

助手运行 `upload_and_run_ubuntu_pilot_backup.ps1`，在仅暂停试点 Web/网关期间生成数据包 `/home/huahua/teacher-workbench-pilot-backups/backup-pilot-Wz0wCERi` 和私有托管 `/home/huahua/teacher-workbench-pilot-key-escrow/escrow-Wz0wCERi`。数据包含数据库、私有文件、Redis、四个镜像、非秘密配置与摘要；托管目录单独存 Django/数据库配置、模型主密钥和 Caddy CA 数据。备份后试点 HTTPS 与原预发布登录页 200。原 `restore_ubuntu_pilot_initial.sh` 因 Docker 默认网段池耗尽，在创建测试网络前退出；**不要重跑**。助手运行 `upload_and_run_ubuntu_pilot_initial_restore_v2.ps1`，指定 `10.251.24.0/28` 独立内部网络，恢复数据库/Redis/私有文件及 CA 到新卷，核对空库迁移、Django 登录页和 CA 摘要；测试容器已停止、卷保留，目录 `/home/huahua/teacher-workbench-pilot-restore-Wz0wCERi`，最终 `PILOT_INITIAL_INDEPENDENT_RESTORE_VERIFIED`。这不是 NAS 或替换主机的恢复验收。

试点 NAS 数据脚本 `transfer_pilot_nas.py` 与上传包装器在 2026-10-24 准备时，自动审批曾因授权不具体而拒绝执行。用户 2026-10-26 明确授权固定数据包和目标后，NAS 复制、只读导回及同机新卷恢复已按下方记录执行；同机密钥/CA 托管没有写入 NAS。当前没有定时备份或异机密钥恢复。正式接入真实账号前还需单独完成这些闸门及浏览器验收。

助手另写只读默认的 `scripts/trust_pilot_ca_current_user.ps1`，在 Windows 本机检查公有 CA 的 SHA256 指纹及 CA 类型，返回 `PILOT_CA_NOT_TRUSTED_FOR_CURRENT_USER_NO_CHANGE`。`-Install` 会把该 CA 加入当前用户的受信任根证书库；因这会扩大此用户的证书信任范围，尚未获明确授权，未执行。Windows Python 探针用指定 CA 严格验证 `/login/`，取得 CSRF 令牌后以虚构错误账号和正确 HTTPS Origin POST，返回正常错误页而非 403；不依赖系统根证书库，也不代表浏览器已验收。

### 2026-10-24 EasyTier 独立 IP HTTPS 试运行（仅本机准备，Ubuntu 未执行）

目标、三个 Windows 入口命令、成功标记、失败停机办法及真实账号接入闸门集中在 [私网试运行方案](private-pilot-launch.md)。本轮新增文件的 PowerShell 包装器均在本机完成 `-LocalCheckOnly` 哈希核对；Bash 语法与错误主机拒绝通过。**下面的只读预检命令已由用户执行成功；保留为操作记录，下一步是本节末尾的准备命令。**勿把密码、展开后的 Compose、证书私钥或 `.env.pilot` 发到聊天：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\run_ubuntu_pilot_readonly.ps1"
```

成功须有 `PILOT_READONLY_PREFLIGHT_OK` 和 `PILOT_PREFLIGHT_WRAPPER_DONE`。该操作会在 Ubuntu `/home/huahua` 上传脚本，但不写业务数据、不改容器或端口；若任一步失败，先分析结果，不重跑后续一次性脚本。

**2026-10-24 用户终端只读预检结果：**最终两项标记均出现，预发布镜像匹配、18443 空闲、试运行目标无冲突、原站登录页 HTTP 200；`PILOT_PREFLIGHT_CADDY_IMAGE_MISSING` 表明本机尚无 Caddy 镜像。无需重跑预检。下一步只在 Windows PowerShell 执行下列准备命令。脚本会向 Ubuntu `/home/huahua` 上传经摘要核对的配置文件，尝试拉取缺失的 `caddy:2-alpine`，在新的私有目录生成随机凭据并验证 Caddy 与 Compose；**不启动数据库或网页容器**：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Projects\teacher-workbench\scripts\upload_and_prepare_ubuntu_pilot.ps1"
```

成功须见 `PILOT_CADDY_IMAGE_PULL_OK`、`PILOT_PREPARE_PREFLIGHT_OK`、`PILOT_CONFIG_AND_CADDY_VALIDATED`、`PILOT_CONFIG_PREPARED_NO_START`、`PILOT_CONFIG_PREPARE_WRAPPER_DONE`。若镜像拉取失败见 `PILOT_CADDY_IMAGE_PULL_FAILED`，停止并仅反馈非敏感末尾输出；不要再次运行不完整的准备脚本或贴出 `.env.pilot` 内容。

- **2026-10-26 试点 NAS 复制自动审批阻止：**脚本本地 SHA-256 与固定值一致，目的为复制空白试点备份，不包含分离的主密钥/CA escrow；但自动审批仍以“可见授权未明确覆盖敏感 payload 与 NAS 目的地”为由拒绝。没有通过其他命令或路径执行。下一次需在执行前取得针对固定源目录、指定 NAS share、新建目录和只读导回的明确授权，再按现有脚本检查清单执行。

- **2026-10-26 试点 NAS 数据往返（助手执行）：**用户明确授权后运行 `upload_and_copy_ubuntu_pilot_nas.ps1`，远端脚本摘要、初始空库备份、NFS 挂载及 10 个文件通过，写入 NAS 新目录 `pilot-data-Wz0wCERi-93f655b6bfe6`，临时挂载清理成功。随后运行 `import_ubuntu_pilot_nas.ps1`，只读挂载同一目录，12 个文件和两层清单通过，导回 `/home/huahua/teacher-workbench-nas-import-pilot-data-Wz0wCERi-93f655b6bfe6`，临时挂载清理成功。这两个一次性脚本已执行，不应原样重跑。
- **2026-10-26 NAS 来源独立恢复（助手执行）：**运行 `upload_and_run_ubuntu_pilot_nas_restore.ps1`，以导回数据包及 Ubuntu 本机单独托管的密钥/CA 在 `10.251.25.0/28` 新内部网络和新卷恢复；通过 `PILOT_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。测试 DB/Redis 已停止，卷保留，恢复目录 `/home/huahua/teacher-workbench-pilot-nas-restore-93f655b6bfe6`。在线试点 HTTPS 和原预发布 HTTP 登录页仍为 200。此一次性恢复脚本已执行；无定期备份、异机密钥托管或空白主机恢复证据。

- **2026-10-26 当前用户试点根 CA 安装未完成：**用户授权固定指纹证书安装。助手在普通及 PTY 终端分别运行 `trust_pilot_ca_current_user.ps1 -Install`，两次指纹与 CA 类型检查通过，但 `Import-Certificate` 未返回完成标记。只读检查显示证书仍不在 `Cert:\CurrentUser\Root`；两次挂起进程已停止。待用户在其可见 Windows PowerShell 执行相同脚本，并本人处理系统安全确认；之后再核验 `PILOT_CA_TRUSTED_FOR_CURRENT_USER`、系统信任 HTTPS 和浏览器登录。未完成前不把浏览器证书页视为验收。
