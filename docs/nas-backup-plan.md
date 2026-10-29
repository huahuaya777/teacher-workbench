# OMV 业务备份接入方案（用户已授权，空文件夹已创建）

本页规划工作台数据的 NAS 备份与恢复。用户于 2026-10-16 明确授权：在 OMV `/dev/sda` 新建工作台专用文件夹和受限访问入口，仅用虚构数据验证备份及独立恢复。专用共享文件夹与 NFS 列表项已由用户截图核对；Ubuntu 虚构单文件读写、整组配对备份转存及 NAS 来源独立恢复已由用户现场输出验证。定时任务、真实资料与密钥恢复未配置或验证。实际操作与结果记入 [运行手册](runbook.md) 和 [验收记录](acceptance.md)。

## 已知情况

- **现场已验证（用户 2026-10-16 输出）：**Ubuntu 257 到 OMV `10.0.30.6` 的 NFS TCP 2049、SMB TCP 445 可连接；Ubuntu 当时没有 NFS/CIFS 挂载。端口可达不代表共享权限可用。
- **现场已验证（用户 2026-10-16 输出）：**Ubuntu 隔离测试栈的一份虚构数据，已完成 PostgreSQL 导出与私有文件配对备份，并在另一套独立 Docker 卷恢复、核对资料/两版草稿/双 Word/跨账号拒绝。此条记录的是最初的 Ubuntu 本机恢复；后续 NAS 副本转存及来源恢复见本节末尾。
- **交接记录（非本轮复核）：**PVE 宿主机有 `/mnt/pve/backup` 的 NFS 挂载，对应 OMV 导出 `/export/backup`。这是 PVE 备份用途，不应直接当成 Ubuntu 工作台的业务备份授权或目的地。
- **现场已验证（用户 2026-10-16 的 OMV 截图）：**「服务 → NFS → 共享」只列出 `backup` 与 `share`，均对 `10.0.30.0/24` 显示 `rw`、`no_root_squash` 等选项；没有工作台专用 NFS 导出。截图未显示「存储 → 共享文件夹」的底层设备、路径或权限。
- **现场已验证（用户随后提供的 OMV 截图）：**「存储器 → 共享文件夹」中 `backup`、`share` 均位于 `/dev/sda`，相对路径分别是 `backup/`、`share/`，状态 Available；`Photos`、`family` 位于 `/dev/sdb1`。列表中没有名称明确的工作台专用文件夹。截图仍未显示文件所有者和访问控制设置。
- **现场已验证（用户创建后截图）：**新增的 `teacher-workbench-backup` 行位于 `/dev/sda`，相对路径 `teacher-workbench-backup/`，状态 Available。该截图没有证明新建时实际选用了 `700` 权限，也没有网络共享或备份结果。
- **现场已验证（用户随后提供的 ACL 截图）：**新文件夹顶层所有者 `root [0]`、组 `users [100]`，所有者读/写/执行，组和其他人无权限，即 `700`。截图没有完整展示命名 ACL，也没有服务级权限或 SMB 共享配置。
- **现场已验证（用户 2026-10-16 的 SMB 列表截图）：**OMV 已有四个启用、非公开的 SMB 共享 `Photos`、`backup`、`family`、`share`，新文件夹尚未建立 SMB 入口。列表不展示用户/组授权；OMV 新账号默认加入 `users` 组，创建前需核对这四个现有共享的服务级权限，避免专用账号意外获得其他入口。
- **现场已验证（用户四张权限页截图）：**页面均只出现 `huahua` 用户行，没有 `users` 组行；两张 `huahua` 为读写，两张没有选中权限。文件夹名称不在画面中，无法一一对应。空白权限不等于对未来新用户的明确拒绝；不据此新增 SMB 账号。
- **现场已验证（用户 NFS 新建表单截图）：**可选共享文件夹、单个客户端、只读/读写及扩展选项；初始值是只读与 `subtree_check,insecure`。该截图只是表单，不代表导出已建立。
- **现场已验证（用户随后提供的 NFS 列表截图）：**新增 `teacher-workbench-backup` 条目，客户端 `10.0.30.5`，选项含 `rw,secure,sync,root_squash,all_squash,anonuid=65534,anongid=65534,no_subtree_check`。截图不证明 OMV 已应用配置、Ubuntu 可挂载或数据已备份。
- **现场已验证（用户随后提供的 ACL 页面截图）：**专用目录顶层 `/` 显示所有者 `nobody [65534]`、组 `users [100]`、仅所有者读/写/执行，未勾选递归；保存/应用状态和命名 ACL 全表未入镜。接下来用 Ubuntu 只读挂载测试实际访问。
- **现场已验证（用户 Ubuntu 输出）：**专用导出临时只读挂载成功，脚本已清理挂载；顶层 UID `65534`、模式 `2700`。初版探测把 `2700` 误判为不等于 `700`，因此未输出整体通过标记。setgid 会使新建子项继承顶层组 `users [100]`；测试和未来备份写入均须采用 `umask 077`、文件 `600`、目录仅所有者可访问，并现场核对模式。NAS 尚无虚构备份写入或来源恢复结果。
- **现场已验证（用户 Ubuntu 输出）：**专用导出虚构单文件读写探测全部通过：新文件 UID `65534`、模式 `600`，读回一致，文件及临时挂载均已清理。这个结果不包含配对备份或来源恢复。
- **现场已验证（用户 Ubuntu 输出）：**已验证的 Ubuntu 本机虚构配对备份及匹配测试代码包已转存至专用 NAS，六个文件逐项校验，完成名为 `fictional-backup-NX5wqA1m-dab1c5b855e1`，临时挂载已清理。随后从该副本只读导入新私有目录，八个文件校验和挂载清理完成；从导入目录在新卷恢复，输出 `NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。这些均为虚构数据技术演练。

## 拟采用的隔离方式

1. **文件夹及导出已在 OMV 页面核对：**OMV `/dev/sda` 上已有与现有 `backup/`、`share/` 平级的 `teacher-workbench-backup/`，用户 ACL 截图显示顶层所有者现为 `nobody [65534]`、组 `users [100]`、仅所有者读/写/执行（`700`）；没有改动现有条目的证据。原拟新建专用 SMB 账号，但现有共享的空白服务权限可能让新账号进入旧共享，因此暂停该路径。专用 NFS 列表项仅允许 Ubuntu `10.0.30.5`；配置是否已应用、实际访问与其他客户端拒绝效果均须现场验证。NFS 没有内建用户认证，不能仅凭这次演练将它用于正式资料。保留现有两个 `/24` 导出原状。
2. Ubuntu 使用固定、与 Docker 卷和本机备份目录分开的挂载点。任何转存脚本都必须确认它实际是来自 `10.0.30.6` 的网络挂载，且目标目录不是符号链接；挂载失效时必须停下，不能误写 Ubuntu 本地磁盘。由于顶层目录实际有 setgid，写入须设置 `umask 077` 并核对文件 `600`、目录仅所有者可访问，不能仅凭继承组无当前权限就推定未来备份私密。
3. 首次只复制**虚构测试数据**的完整备份组：`db.dump`、`private.tar.gz`、`SHA256SUMS`、`SOURCE_SHA256SUMS`、`STATE`，并另存与之匹配的测试代码包。现有 `SOURCE_SHA256SUMS` 仅记录代码包哈希，并未把代码包放进备份目录；脱离原 Ubuntu 后不能只靠它恢复。写入时先用临时目录，复制和校验通过后再标记为完整；不得覆盖已有版本。
4. 从 NAS 上的这一份副本恢复到**另一套新 Docker 卷**，核对数据库、资料原件、历史版本、两份 Word 和跨账号拒绝，再核对源测试栈仍可用。仅能从 Ubuntu 本机备份恢复的既有结论不能代替 NAS 来源恢复。
5. 上述虚构数据步骤现已通过用户现场技术测试；接下来须单独设计每日自动备份、多版本保留、失败通知和定期恢复演练。保留数量、时间、容量阈值和清理规则尚未确定，不运行自动清理。

## 密钥和正式环境边界

- 测试栈当前关闭 AI，虚构账号密码不可用；这次技术恢复没有验证真实账号密码、旧会话或 Django 密钥恢复。正式环境必须为配置和密钥准备独立、安全的恢复途径，不能把明文 `.env` 与数据备份一起随意放入 NAS 共享。
- 正式环境如有正在运行或已发送的 AI 任务，备份与恢复还要核对 Redis 队列和已计费请求，避免恢复后重复调用。代码版本回退不能代替数据库与文件回退。
- 业务备份不进入 Git，不装入 Docker 镜像；NAS 访问凭据、教学资料与数据库内容不写入项目文档或聊天。
- **转存与来源恢复现场已验证：**`scripts/copy_fictional_backup_to_nas.py` 已将 Ubuntu 本机虚构配对备份及测试代码包转存到专用 NAS；`scripts/import_fictional_nas_backup.py` 从指定 NAS 副本只读导入 Ubuntu 新私有目录；`scripts/restore_ubuntu_nas_test_backup.sh` 从导入目录恢复到另一套新卷。用户提供各阶段校验、挂载清理与最终完成标记。仅验证虚构数据测试流程，不覆盖正式资料、密钥或自动周期。
- **独立预发布栈（2026-10-17 Ubuntu 本机技术演练通过）：**新站虚构账号和资料已由用户在浏览器检查。用户现场输出 `STAGING_BACKUP_FILES_VERIFIED` 和 `STAGING_INDEPENDENT_RESTORE_VERIFIED`，表明预发布数据库与私有文件已配对备份到 Ubuntu 私有目录，并在全新卷恢复、核对虚构资料所有者访问和跨账号 404；新旧站登录页仍可用。这次未转存 NAS。旧测试栈的 NAS 来源恢复结果不能直接算作新栈的 NAS 来源恢复结果。
- **生成后的当前状态（2026-10-17）：**预发布任务 1 已由用户确认完成，页面与双 Word/WPS 检查正常。旧预发布备份发生在任务 1 创建之前，**不含新草稿**；它仍是有效的生成前恢复点。用户随后在 Ubuntu 执行生成后配对备份，返回 `STAGING_GENERATED_BACKUP_FILES_VERIFIED` 与 `STAGING_WEB_RESTARTED_HTTP_200`，新备份位于 `/home/huahua/teacher-workbench-staging-backups/backup-generated-wmPvKqmx`。又从这份本机备份在全新卷恢复，返回 `STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK` 与 `STAGING_GENERATED_INDEPENDENT_RESTORE_VERIFIED`；原站仍 HTTP 200。用户在 WPS 本地另存的下载文件不随服务器数据库/私有卷备份。
- **生成后 NAS 接续已现场技术验证（用户 2026-10-17 输出）：**专用脚本固定核对上述虚构备份及匹配代码包，仅使用工作台专用 NFS 导出，不覆盖旧 NAS 版本。七个文件转存校验、`NAS_GENERATED_STAGING_COPY_DONE`、副本 `staging-generated-wmPvKqmx-0d63b4ce3f0e` 已出现；随后从该副本只读导入，九个文件逐项校验并卸载，再恢复到另一套新卷，返回 `STAGING_GENERATED_RESTORE_CONTENT_AND_ACCESS_OK` 与 `STAGING_GENERATED_NAS_SOURCE_RESTORE_VERIFIED`。恢复检查包括虚构原件、草稿预览、双 Word 和跨账号拒绝；源站登录页仍 HTTP 200。此演练仍依赖 Ubuntu 现有应用镜像、代码目录和辅助检查器，不能证明整机损毁后可独立重建，也不证明真实资料或密钥恢复。

## 下一道现场信息闸门

**2026-10-17 第 2 版续接（本地脚本准备，现场待验证）：**用户已在预发布页面和 WPS 实际验收第 2 版，Ubuntu 本机 `backup-revised-X7Bv9cfE` 配对备份及独立卷恢复已取得成功标记。新 `copy_staging_revised_backup_to_nas.py` 只读该备份，固定核对虚构资料的匹配旧镜像/代码包和已部署的换行补丁包、更新脚本，向工作台专用 NFS 新目录复制并逐文件校验，不覆盖旧 NAS 版本；配套只读导入和新卷恢复脚本已写。本轮仅本机语法、哈希、错误主机拒绝和无清卷/付费调用检查通过，**Ubuntu/NAS 尚未运行**。从 NAS 恢复时使用旧镜像验证数据与账号隔离，换行补丁作为独立文件随副本保存，恢复副本不会自动应用它；正式恢复流程仍需验证当前渲染代码重建。每日自动备份、保留/清理和真实资料恢复仍待后续阶段。

**2026-10-17 用户现场转存结果：**上段是准备时状态。用户随后提供九项文件逐个校验、`NAS_REVISED_STAGING_FILES_VERIFIED`、`NAS_MOUNT_CLEANED` 和 `NAS_REVISED_STAGING_COPY_DONE`；专用 NAS 新目录名为 `staging-revised-X7Bv9cfE-8fb7b9d72c41`。本结论基于终端输出，助手未直接访问 NAS。此副本的只读导入及新隔离卷恢复仍待执行，不能把第 1 版 NAS 来源恢复结论套用到第 2 版。

**2026-10-17 用户现场来源恢复结果：**上段“仍待执行”是转存当时状态。用户随后从该副本只读导入新目录，11 项文件校验且临时挂载清理通过；在全新 Docker 卷恢复虚构数据库与私有文件，检查器核对两版草稿、四份 Word、原件哈希和另一账号四处 404，最终返回 `STAGING_REVISED_NAS_SOURCE_RESTORE_VERIFIED`。源预发布与旧测试站登录页仍 HTTP 200，新恢复容器已停、卷保留。该流程使用备份配对的旧镜像验证数据；NAS 内虽保存了换行补丁包，**尚未从该副本重建已验收的新渲染镜像**。真实资料、密钥及整机重建仍未验证。

**2026-10-17 渲染代码恢复演练准备：**已写入只针对上述隔离恢复目录的离线重建脚本，固定核对 NAS 导入的代码包与补丁哈希，以新的测试镜像名构建并用恢复的虚构第 2 版数据检查网页分行和两份 Word；本机语法、安全闸门及补丁文件一致性通过。**Ubuntu 运行待验证**，且该脚本仍依赖现有 Ubuntu Docker、基础镜像和已恢复的数据库卷，不能等同于整机灾难恢复。

**2026-10-17 现场预检失败及续接：**用户运行上述旧脚本时，Docker 报本地没有 `python:3.12-slim`，未进入构建或恢复数据库核对。保留旧脚本和已有 NAS 副本，新增配对镜像续接脚本：先核对 NAS 备份的 `APP_IMAGE_ID` 与现有旧应用镜像，再在其依赖环境之上叠加 NAS 代码和补丁构建独立测试镜像。本机检查通过，**Ubuntu 执行及恢复版渲染结果仍待验证**；仍依赖本机配对镜像，不能充当完整异机恢复。

**2026-10-17 用户现场续接结果：**新脚本返回 `NAS_RENDERER_PAIRED_OFFLINE_IMAGE_BUILT`、`NAS_RENDERER_REVISED_PREVIEW_AND_WORD_VERIFIED`、恢复数据库停止及最终 `NAS_RENDERER_FROM_NAS_PAIRED_REBUILD_VERIFIED`。按脚本控制流，NAS 导入代码/补丁与本机配对旧镜像已组合成独立测试镜像，并使用恢复副本中的虚构第 2 版数据验证预览与双 Word 渲染；源站登录页也返回 HTTP 200。**该补充演练依赖 Ubuntu 仍保有配对旧镜像**，不证明仅凭 NAS 副本可在空白主机恢复全部服务、密码/密钥或真实资料。

**2026-10-21 阶段 2B 密文数据续接：**用户终端已验证两条虚构模型配置的同机配对备份与新卷恢复。现已编写仅转存这份虚构数据备份 `backup-phase2b-keys-X6F4w9bJ` 的专用 NAS 脚本及只读导入/新卷恢复续接；**尚未上传或执行**。NAS 转存不包含 `v1.key`，恢复仍依赖 Ubuntu 同机 `keyring-X6F4w9bJ`。因此新流程通过后也只证明数据副本可从 NAS 回读；主密钥异机/离线保管与空白主机恢复须另行验收，真实 Key 暂不录入。

**2026-10-21 后续用户 NAS 转存结果：**上述准备时的“尚未执行”已由现场终端输出更新。八项虚构数据文件逐个校验、最终 `STAGING_2B_NAS_DATA_COPY_DONE` 与卸载清理通过；NAS 新目录为 `staging-phase2b-data-X6F4w9bJ-c9e68dfefb4b`。只读导入与 NAS 来源新卷恢复尚未执行，不能据此宣称数据可从 NAS 回读；主密钥仍只在原 Ubuntu 上。

**2026-10-21 后续用户只读导入结果：**上述 NAS 新目录的十项文件已校验并导入本机新私有目录，返回 `STAGING_2B_NAS_DATA_IMPORT_DONE` 和 `NAS_MOUNT_CLEANED`。这验证虚构数据可从 NAS 回读；使用该副本进行新卷恢复及主密钥异机保管仍待验证。密钥文件没有随 NAS 副本导入。

**2026-10-21 后续用户来源恢复结果：**NAS 导入的虚构数据在全新隔离卷恢复，返回 `STAGING_2B_RESTORE_CONTENT_KEYS_AND_ACCESS_OK`、四条预期跨账号 404、恢复容器停止及最终 `STAGING_2B_NAS_SOURCE_INDEPENDENT_RESTORE_VERIFIED`。恢复时使用**原 Ubuntu 主机上的**独立主密钥副本；因而仅验证 NAS 数据往返及配对恢复，不能宣称空白主机或异机密钥恢复。下一项需确定主密钥独立保管位置、访问人和恢复演练；真实 Key 继续暂停。

**用户现场已验证（2026-10-16）：**Ubuntu 没有 `mount.nfs` 和 `showmount`，因而本轮没有获取 NFS 导出列表。`NFS_EXPORT_LIST=tool_absent` 不说明 OMV 是否已有或开放共享。无需仅为列清单就立即安装软件。

用户已提供四张权限截图，但没有 `users` 组行，且文件夹名不可见。OMV 的 [Samba 文档](https://docs.openmediavault.org/en/8.x/administration/services/samba.html)提示权限空白时不能把未来新用户视为被拒绝；在不改现有共享的授权边界内，暂停专用 SMB 账号方案。专用 NFS 的虚构单文件读写、整组配对备份转存和 NAS 来源独立恢复均已由 Ubuntu 现场输出验证；[Debian exports 手册](https://manpages.debian.org/trixie/nfs-kernel-server/exports.5.en.html)说明 `all_squash` 将所有远端 UID/GID 映射到匿名身份，`secure` 要求保留端口。OMV 的 [NFS 文档](https://docs.openmediavault.org/en/8.x/administration/services/nfs.html)说明 NFS 不提供用户认证，因此正式数据使用前需另行评估。现有四个 SMB 共享及两个 NFS 导出保留原状；自动备份、保留和清理策略需单独设计与验证。
