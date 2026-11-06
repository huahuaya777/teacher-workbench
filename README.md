# 教师AI工作平台搭建

面向教师逐步建设的个人教学工作台。**当前已上线 [EasyTier 私网限定使用版](docs/release-2026-10-29.md)**：连接 EasyTier 并信任项目 CA 的设备可打开 [教师工作台](https://10.0.30.5:18443/)。此版沿用独立试点栈中的真实教师账号和数据，不使用域名或 Cloudflare；完整第一版仍在开发。

## 状态说明

- **已确认需求**：首个验收场景为人教版九年级数学，任教 19、20 班，常用 WPS 和希沃白板；个人首页名称为“华华的教学工作台”。电脑横版优先，手机支持聊天、拍照上传、查看资料和课表、下载文件。
- **现场已验证**：Ubuntu 257 的五服务、EasyTier HTTPS、真实教师账号、一次成功作业及教师卷内容/WPS 显示/公式编辑；新配对快照、NAS 数据往返和同机独立新卷恢复。具体证据见[发布记录](docs/release-2026-10-29.md)和[当前状态](docs/status.md)。
- **当前功能**：成员登录与管理、个人资料、成员自己的加密模型配置、额度、主动生成作业、草稿预览及双 Word 导出。AI 请求由教师主动触发，厂商费用以账单为准。
- **待完成**：实际纸张打印、其他教师设备/学校网络、PWA、共享资料、完整题库与课表、通用聊天、教案/PPTX/希沃及空白异机恢复等。早期[域名正式配置草案](docs/production-readiness.md)未运行。
- 已认可的首页参考已导入 [设计参考目录](design-reference/README.md)。本地页面已采用相应浅绿三栏布局；电脑端导航获用户认可，手机宽度由本机浏览器检查，真实手机仍待验收。

## 已验收的最小流程与当前目标

上线流程：教师登录 → 上传含可提取文字的 DOCX/PDF → 自行选择模型配置和主动生成 → 查看草稿 → 下载学生卷与教师答案版 Word → 在 WPS 审核。用户已确认当前教师答案内容、显示和公式编辑正常；复杂数学题继续由教师审核，打印效果尚待现场检查。

## Docker 部署

新安装推荐用 Compose。下载 [compose.deploy.yaml](compose.deploy.yaml)，在该文件所在目录执行：

```sh
docker compose -f compose.deploy.yaml up -d --wait
docker compose -f compose.deploy.yaml exec workbench python manage.py createsuperuser
```

创建自己的管理员后，打开 [http://localhost:8000/](http://localhost:8000/)。当前镜像 `huahua777/teacher-workbench:2026.11.06` 支持 `linux/amd64`，可从 [Docker Hub](https://hub.docker.com/r/huahua777/teacher-workbench) 免登录拉取。新实例从空库开始，AI 默认关闭。

| 部署方式 | 适用场景 |
| --- | --- |
| [Compose 拉取镜像](docs/docker-deployment.md#docker-compose) | 首次安装，或用一份配置管理容器和数据卷 |
| [docker run](docs/docker-deployment.md#docker-run) | 直接从终端启动，无需 Compose 文件 |
| [从源码构建](docs/docker-deployment.md#从源码构建) | 开发者运行自己的修改 |
| [远程访问与 HTTPS](docs/docker-deployment.md#远程访问与-https) | 让其他设备通过受信任的 HTTPS 入口访问 |
| [EasyTier 私网与预发布](docs/docker-deployment.md#已有私网服务与测试环境) | 查找家中现有服务、预发布和测试栈的运维入口 |

两套命名卷分别保存业务数据和模型主密钥。迁移、备份与升级按[通用 Docker 部署说明](docs/docker-deployment.md)操作。

## 使用已有的私网工作台

1. 使用者先连接 EasyTier，在自己的设备上信任项目 CA，再打开 [私网入口](https://10.0.30.5:18443/)；不要忽略浏览器证书警告。
2. 查看 [当前状态](docs/status.md)、[发布范围](docs/release-2026-10-29.md)和 [完整需求](docs/requirements.md)，区分已上线功能与后续目标。
3. 运维和回退依据见 [运行手册](docs/runbook.md)，后续功能见 [阶段路线图](docs/roadmap.md)。本项目已获授权使用 [GitHub 私有仓库](https://github.com/huahuaya777/teacher-workbench) 保存代码与文档；业务数据和密钥独立保存。当前推送状态见[当前状态](docs/status.md)。

跨设备接续开发请先读 [Ubuntu 开发机迁移说明](docs/migration-ubuntu-dev-2026-10-30.md)。

项目工作规则见 [AGENTS.md](AGENTS.md)。持续记录包括 [决定](docs/decisions.md)、[后续需求](docs/backlog.md)、[操作手册](docs/runbook.md) 和 [验收记录](docs/acceptance.md)。业务数据和密钥不进入 Git；详见该文件及 [.gitignore](.gitignore)。

交接包中的教学样本位于 `teacher-workbench-handoff/samples/`，仅供获准的本地开发验证，不能提交 Git、加入 Docker 镜像或默认共享给其他教师。
