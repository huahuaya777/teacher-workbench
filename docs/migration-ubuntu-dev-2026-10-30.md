# 开发项目迁移至 Ubuntu 10.0.30.7

更新：2026-10-30（Asia/Shanghai）。本文件是迁移执行与后续 Codex 接续入口，不代表迁移已完成。

## 已确认需求与范围

- 用户要停止使用当前 Windows 开发电脑，把教师工作台的**后续开发环境**移到 Ubuntu `10.0.30.7`，用户为 `huahua`；该机已安装并登录 Codex（来自用户陈述，尚未在目标机复核）。
- 当前运行中的 EasyTier 私网正式站在 `10.0.30.5:18443`。本次只迁移开发项目，不移动或停用线上容器、数据库、模型密钥、CA 或 NAS 定时备份；线上业务数据仍走现有独立备份与恢复流程。
- 目标开发目录暂定 `/home/huahua/projects/teacher-workbench`，必须先检查目录不存在或已明确辨认其状态，不覆盖原有文件。

## 当前源目录与可迁移内容

- Windows 源目录：`D:\Projects\teacher-workbench`。
- GitHub 私有仓库：`https://github.com/huahuaya777/teacher-workbench.git`，`main`。Git 保存源码、设计参考、项目规则、需求、状态、决定、操作手册、验收和提交历史。迁移前要把本轮文档变更审查、提交并推送，再制作可离线克隆的 Git bundle；目标机不能把 Codex 登录等同于 GitHub 授权。
- Git 忽略的个人本地资产要经 SSH 另行复制并校验，不进入 GitHub：`data/`（42 个文件，约 94 MB，包括本机开发数据库、私有测试文件、离线 wheelhouse 和发布检查产物）、`teacher-workbench-handoff/`（9 个文件，约 2 MB，包括私人教学样本）、忽略的部署压缩包。目标机目录权限只给 `huahua`。这些资产的复制只服务个人开发，不表示可公开测试、进入 Docker 镜像或送到真实 AI。
- `.venv/`、`__pycache__/` 和 `staticfiles/` 属于可重建的本机产物，不作为跨 Windows/Linux 的环境复制。目标机需按 `requirements.txt` 创建 Linux 虚拟环境并运行检查。
- **已准备、本机待传：**在 Git 忽略的 `tmp/migration-ubuntu-20261030/` 内制作 55 文件的私有归档（94,822,976 字节）及逐文件 SHA-256 清单；包含 `data/`、`teacher-workbench-handoff/` 和忽略的部署源码压缩包，未包含 `.venv/` 或 Codex 账号目录。已创建不等于目标机收到或通过校验。
- 本机 `.codex` 账号凭据、Cookie 和聊天数据库不复制。Codex 的逐字聊天历史能否在目标机显示尚未验证；项目的长期上下文以 `AGENTS.md`、`docs/status.md`、`docs/requirements.md`、`docs/roadmap.md`、`docs/decisions.md`、`docs/runbook.md`、`docs/acceptance.md` 为准。官方 OpenAI 文档说明 Codex 会读取仓库中的 `AGENTS.md`，阶段上下文文件可帮助延续工作：[项目协作说明](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex)。

## 2026-10-30 现场预检

- Windows 通过 EasyTier 接口 `et_6_kfsc` 能 ping `10.0.30.7`，TCP 22 失败；直接 SSH 连接超时。
- 从已授权的 Ubuntu `10.0.30.5` 到 `10.0.30.7` ping 成功，但 TCP 22 返回 `Connection refused`。因此不能把密码错误或 Codex 未登录当作原因；目标机 SSH 服务/端口状态待用户在目标机核对。
- 尚未登录 `10.0.30.7`，未检查目标目录、磁盘、Git、Python、Codex 版本，也未复制任何文件。
- **迁移准备已验证：**私有归档 55 个成员逐文件 SHA-256 核对通过，归档及清单由 `.gitignore` 排除；迁移文档已提交并推送到私有 GitHub。离线 Git bundle 已制作并通过 `git bundle verify`，包含完整提交历史。目标机尚未收到两份包。

## SSH 可用后的执行顺序与验收

1. 只读检查目标主机身份、操作系统、磁盘、`git`、`python3`、Codex 命令及目标目录，确认不会覆盖已有项目。
2. 本机审查暂存差异与禁入文件，提交/推送代码文档；创建并验证 Git bundle。另将 Git 忽略的个人资产制成私有归档，记录 SHA-256；不另行加入 `.env`、Codex 登录凭据或聊天数据库，现有 `data/dev.sqlite3` 仍按敏感资料处理。
3. 经 SSH/SCP 复制 bundle 与私有归档到 `huahua` 的新私有目录，逐个核对 SHA-256；从 bundle 克隆到 `/home/huahua/projects/teacher-workbench`，将 `origin` 设为上述私有 GitHub 地址，私有资产解包到对应路径。不要让私有归档进入 Git 暂存区。
4. 目标机核对 Git `HEAD`、分支、工作树和文件数；核对私有归档文件集合与摘要；确认 `AGENTS.md`、状态和路线图在目标机可读。
5. 目标机创建 Linux 虚拟环境并在隔离开发配置下运行 Django `check` 与适用的测试。若目标 Python 版本或离线 wheel 不匹配，先报告，不用线上数据库或线上 Key 顶替。
6. 在 Ubuntu 上打开该目录的 Codex 项目，用新聊天明确要求先读 `AGENTS.md`、`docs/status.md`、本迁移记录与当前 Git 状态，再继续路线图。核对它能说出当前上线范围和未完成事项。Codex 登录与私有 GitHub 推送权限需分别验证。

## 后续开发接续提示

> 这是教师工作台项目的 Ubuntu 开发副本。先读仓库根目录 `AGENTS.md`、`docs/status.md`、`docs/requirements.md`、`docs/roadmap.md`、`docs/decisions.md` 和 `docs/migration-ubuntu-dev-2026-10-30.md`，再看 Git 状态。以 2026-10-29 私网限定上线记录为已验证基线；不要把路线图中的历史“未上线”当成当前状态。后续开发分阶段在隔离环境测试，保留 `10.0.30.5` 线上数据与服务，不主动发起付费模型请求。报告已确认需求、现场已验证和待验证假设。

## 待验证假设

- 目标 Ubuntu 的 SSH 启用方式、端口、可用空间、Python 版本及 Codex 项目接入方式尚未核实。
- 目标 Codex 是否能显示这台 Windows 上的原聊天记录尚未核实；项目文档与 Git 历史是已准备的跨设备上下文，不承诺逐字聊天历史自动同步。
- 空白异机恢复线上业务系统是独立运维任务，本次开发项目迁移不替代它。
