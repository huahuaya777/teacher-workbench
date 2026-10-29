# 阶段 2B：虚构主密钥的离线 U 盘恢复演练

## 边界与当前状态

- **已确认需求（用户 2026-10-21 选择“1”）：**加密恢复包由用户保存在离线 U 盘；解锁口令与 U 盘分开保管，不发到聊天。
- **现场已验证（用户终端）：**两条虚构模型配置的数据备份已到专用 NAS，NAS 只读导入后用原 Ubuntu 同机密钥恢复成功。
- **离线 U 盘与 NAS 配对恢复现场技术通过（用户终端 2026-10-21 至 22）：**从原 Ubuntu 的虚构 `v1.key` 生成加密 JSON，结构检查与两次 SHA-256 一致，最终 `OFFLINE_KEY_ENCRYPTED_EXPORT_READY`。包位于 `/home/huahua/teacher-workbench-staging-offline-key-packages/package-X0ad1NB4/teacher-workbench-staging-model-key-v1.json`，SHA-256 为 `969d66ad895f6392ca9a96cf8c8c40a2c01691a893d16f86b85ab47daaf716fc`。U 盘往返和安全重试后的独立解密通过；恢复出的虚构主密钥与 NAS 导入数据指纹匹配，并在新卷恢复中解密两条虚构模型配置。助手未读取包、口令或明文密钥；未接触真实成员 Key。

恢复包只含使用口令加密的随机主密钥。使用 [cryptography Scrypt](https://cryptography.io/en/stable/hazmat/primitives/key-derivation-functions/) 从口令派生密钥（随机 16 字节盐，`n=2^17,r=8,p=1`），使用 [AESGCM](https://cryptography.io/en/stable/hazmat/primitives/aead/) 加密（随机 12 字节 nonce，元数据作为认证数据）。错误口令、包损坏或被改动会拒绝恢复。包里保留原密钥的 SHA-256 摘要用于和 NAS 数据配对，**摘要和加密包本身不足以恢复密钥**；口令遗失也无法恢复。请设置独立且随机的至少 20 字符口令，并在 U 盘之外妥善记录。该测试不构成空白服务器重建或生产数据灾备验收。

## 演练顺序

1. **Ubuntu 导出，用户现场技术通过。**用户提供 `OFFLINE_KEY_ENCRYPTED_EXPORT_READY`、完整路径与两次一致的 SHA-256；容器禁网、只读挂载虚构主密钥、输出到新建 0700 目录的行为依据已核对脚本控制流。不要把口令、主密钥文件或加密 JSON 发到聊天。
2. **Windows U 盘复制、重新插入及返回 Ubuntu 已现场技术通过。**单个加密 JSON 已复制到用户确认的 `E:\` 可移动盘；用户报告已安全弹出、拔下并重新插入，助手重新只读检查 349 字节文件的 SHA-256 与导出值一致。用户终端随后返回 `USB_RETURN_FILE_SHA256_OK`，路径 `/home/huahua/teacher-workbench-staging-offline-key-return-ddfae9d5abc1/teacher-workbench-staging-model-key-v1.json`。按命令，Ubuntu 新目录为 0700、文件为 0600，再次比对原 SHA-256；助手未直连 Ubuntu。Windows 本地项目目录、Git 和 NAS 数据共享不保存包或口令。
3. **独立解密安全重试现场技术通过。**原 `restore_ubuntu_staging_offline_key_package.sh` 首次提示口令后返回 `PASSPHRASE_OR_PACKAGE_INVALID`；专用 `retry_ubuntu_staging_offline_key_restore.sh` 在旧目标目录为空、包及数据完整的前提下重新交互解密。用户终端随后返回 `OFFLINE_KEY_RESTORED_TO_NEW_DIRECTORY`、`OFFLINE_KEY_RECOVERED_FINGERPRINT_MATCHES_NAS_DATA` 与 `OFFLINE_KEY_FROM_RETURNED_PACKAGE_VERIFIED`，恢复目录 `/home/huahua/teacher-workbench-staging-offline-key-restore-ddfae9d5abc1`。脚本不挂载在线密钥或同机托管副本；助手未看到口令或密钥内容。
4. **NAS 数据配对隔离恢复现场技术通过。**用户运行 `restore_ubuntu_staging_phase2b_from_usb_key.sh`，使用固定 NAS 导入目录和第 3 步新恢复的密钥目录，新建独立网络、数据库卷及私有文件卷；两条虚构配置可解密、资料权限及跨账号四条 404 均通过，最终得到 `STAGING_2B_USB_KEY_NAS_DATA_RESTORE_VERIFIED`。恢复目录 `/home/huahua/teacher-workbench-staging-phase2b-usb-restore-ddfae9d5abc1`；恢复容器已停，测试卷保留；源预发布登录页恢复后 HTTP 200。没有切换在线站点或覆盖数据。脚本未检查旧测试站登录页，本步骤不扩大结论。

每步失败都停止，不重复运行已创建目标目录的脚本；保留现场输出中的非敏感标记供排查。此流程仍在原 Ubuntu 使用已有 Docker 镜像完成解密与恢复，因此只证明**虚构离线 U 盘加密密钥副本与 NAS 数据可以在该主机配对恢复**；尚须另做空白服务器和正式环境恢复验证。U 盘加密文件和解锁口令应分开离线保管；本次恢复目录中还保留一份虚构明文主密钥，不应误当成长期离线备份。
