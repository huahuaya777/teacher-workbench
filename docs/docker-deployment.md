# 通用 Docker 部署

更新时间：2026-11-06（Asia/Shanghai）。本文件面向新安装，不是家中现有试点的升级命令。镜像发布与验收结果以 [当前状态](status.md) 和 [验收记录](acceptance.md) 为准。

## 安装方式

镜像名：`huahua777/teacher-workbench:2026.11.06`。当前构建目标是 Linux AMD64；Windows Docker Desktop 需使用 Linux 容器。首次运行是空系统，不含任何已有账号、教学资料、模型 Key 或默认密码。

在安装了 Docker 的电脑终端执行：

```sh
docker run -d --name teacher-workbench --restart unless-stopped --stop-timeout 240 \
  -p 127.0.0.1:8000:8000 \
  -v workbench_data:/var/lib/teacher-workbench \
  -v workbench_keyring:/var/lib/teacher-workbench-keyring \
  huahua777/teacher-workbench:2026.11.06
```

PowerShell 中把上述命令合成一行即可。等待 `docker ps` 显示 `healthy`，然后创建自己的管理员：

```sh
docker exec -it teacher-workbench python manage.py createsuperuser
```

按终端提示设置用户名和密码；密码输入不回显。打开 `http://localhost:8000/` 登录，管理员可在成员账号管理中建号、重置密码及设置额度。没有固定的默认账号或密码。

镜像内已包含 PostgreSQL 17、Redis、Gunicorn、静态资源服务及一个任务 worker，无需另外安装 Python、数据库或队列。业务进程使用 UID/GID `10001:10001`；命名卷会自动获得正确权限。仅发布网页端口，数据库和 Redis 只监听容器回环地址。不使用 `--privileged` 或 Docker socket 挂载。

## Docker Compose

只需取得项目根目录的 `compose.deploy.yaml`，在其所在目录执行：

```sh
docker compose -f compose.deploy.yaml up -d --wait
docker compose -f compose.deploy.yaml exec workbench python manage.py createsuperuser
```

同样打开 `http://localhost:8000/`。配置文件只引用已发布镜像，没有本机源码路径或必填密钥。Compose 创建的卷名默认是 `teacher-workbench_workbench_data` 和 `teacher-workbench_workbench_keyring`，与上面的 `docker run` 示例是两套独立数据。不要混用两种安装方式来管理同一实例。

源码持有者可本机构建：

```sh
docker build -f docker/Dockerfile -t teacher-workbench:local .
WORKBENCH_IMAGE=teacher-workbench:local docker compose -f compose.deploy.yaml up -d --wait
```

也可通过 `-f compose.deploy.yaml -f docker/compose.build.yaml build` 构建。原根目录 `Dockerfile` 和已有试点/测试 Compose 仍服务于原有运维流程，不是这里的新安装入口。

## 启用成员 AI

AI 默认关闭；上传、保存配置和下载 Word 不自动调用模型。准备使用付费模型时，在创建容器时加 `-e TW_ENABLE_MEMBER_AI=1`，或在 Compose 同目录 `.env` 中设置：

```dotenv
TW_ENABLE_MEMBER_AI=1
```

执行 `docker compose -f compose.deploy.yaml up -d` 使配置生效。每位教师登录后保存自己的百炼北京 `qwen-flash` 配置，管理员为普通成员设置调用次数和有效期，教师主动点击生成或修改才会请求厂商。先在厂商侧设置预算；工作台的次数上限不等于金额上限。当前不支持任意厂商、通用聊天或自动联网搜索。

主密钥首次启动时随机生成，只保存在密钥卷；数据库中只保存成员 API Key 的密文。进程级 `AI_API_KEY` 不会被当作成员 Key 使用。不要把真实 Key 写进 Dockerfile、构建参数或公开 Compose。

## 远程访问与 HTTPS

默认网页仅供安装电脑本机访问。需要局域网访问时，应明确配置地址，例如在 Compose `.env` 中设置：

```dotenv
TW_BIND=0.0.0.0
TW_PORT=8000
TW_ALLOWED_HOSTS=192.168.1.10
TW_TRUSTED_ORIGINS=http://192.168.1.10:8000
```

把示例地址换成部署电脑的实际地址。HTTP 适用于本机初步检查；真实账号和资料的远程使用应通过可信 HTTPS。该镜像不会修改路由器、EasyTier、PVE 或自动申请证书。

使用独立 HTTPS 反向代理时，容器网页端口保持受限，代理保留原始 Host 并设置 `X-Forwarded-Proto: https`，配置：

```dotenv
TW_ALLOWED_HOSTS=workbench.example.com
TW_TRUSTED_ORIGINS=https://workbench.example.com
TW_HTTPS=1
TW_TRUST_PROXY=1
```

仅当所有入口都经过受信任代理时启用 `TW_TRUST_PROXY`。使用 Docker 网络内代理时，由部署者配置网络，不把容器直接开放到公网。HTTPS 模式启用 Secure Cookie、跳转及 HSTS；PWA、真实手机、WPS 和纸张打印仍按项目各自验收范围处理。

## 数据、备份和升级

| 持久卷路径 | 内容 |
| --- | --- |
| `/var/lib/teacher-workbench` | PostgreSQL、私人上传、Redis 和升级前数据库转储 |
| `/var/lib/teacher-workbench-keyring` | Django 签名密钥、数据库随机密码、版本化模型加密主密钥 |

两卷必须配对保存；只有数据库无法解密成员 Key。密钥卷不要公开或默认上传 NAS。容器删除后命名卷保留；不要使用 `docker compose down -v` 或清理这些卷。

做完整备份时，先正常停止实例，再分别归档两个卷到权限受限的位置，记录镜像版本和配对关系，最后启动原实例。以下是 `docker run` 示例所用卷名，在 Linux 终端执行；Compose 安装要替换为上表前述实际卷名：

```sh
mkdir -m 700 backup-20261106
docker stop -t 240 teacher-workbench
docker run --rm --user 0 --entrypoint tar \
  -v workbench_data:/source:ro -v "$PWD/backup-20261106:/backup" \
  huahua777/teacher-workbench:2026.11.06 -C /source -czf /backup/data.tar.gz .
docker run --rm --user 0 --entrypoint tar \
  -v workbench_keyring:/source:ro -v "$PWD/backup-20261106:/backup" \
  huahua777/teacher-workbench:2026.11.06 -C /source -czf /backup/keyring.tar.gz .
docker start teacher-workbench
```

先核验两个归档可读，再将密钥包与数据包分开保管。恢复时只向两个**全新命名卷**解包，保留 numeric UID/GID 与权限，再用配对镜像挂载新卷启动。不要覆盖正在运行的数据库目录。第一次恢复需检查账号登录、原件下载、历史 Word、模型配置解密和跨账号拒绝。此处命令是操作说明，不表示每位安装者的备份已验证。

升级前先完成停写双卷备份。新版本需要数据库迁移时，默认会拒绝直接更改已有库；在确认备份和回退路径后，显式设置 `TW_APPLY_MIGRATIONS=1` 再启动。程序会先另存一份数据库转储，再执行迁移；这份数据库转储**不包含文件或密钥**，不能替代双卷备份。完成后取消该开关。检测到数据库记录了当前镜像未知的业务迁移时拒绝启动，避免误用旧镜像。PostgreSQL 主版本升级需另做逻辑导出/导入，不能直接替换数据目录。

回退涉及迁移时，使用旧镜像和备份恢复出的新双卷；代码回退不等于数据库回退。已有家中线上服务不由这套新安装配置自动升级或迁移。

## 构建与发布核查

- 新 Dockerfile 只复制应用源码、模板、静态资源和容器程序；Dockerfile 专用忽略文件限制构建上下文。数据库、私人样本、项目文档/历史、证书及已有部署密钥不进入镜像。
- 发布标签固定版本，`latest` 只指向通过验收的发布镜像。升级建议使用固定标签或 digest。
- 健康检查同时检查网页、PostgreSQL、Redis 和四个必要进程；任一子进程退出会使整个容器停止，由 Docker 的重启策略处理。
- 不自动安装 NAS 备份任务或外部告警；每个新实例需要自己的备份与恢复验证。
