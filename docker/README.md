# 教师工作台 / Teacher Workbench

独立部署的教师工作台，支持成员账号、私有 DOCX/PDF 资料、加密的成员模型配置、调用次数控制、作业草稿与历史版本、正式成果标记和学生/教师双 Word 导出。

包含 PostgreSQL 17、Redis、网页和任务 worker。空库首次启动；没有默认账号、教学资料或 API Key。当前镜像架构为 `linux/amd64`。

## Docker run

```sh
docker run -d --name teacher-workbench --restart unless-stopped --stop-timeout 240 \
  -p 127.0.0.1:8000:8000 \
  -v workbench_data:/var/lib/teacher-workbench \
  -v workbench_keyring:/var/lib/teacher-workbench-keyring \
  huahua777/teacher-workbench:2026.11.06
docker exec -it teacher-workbench python manage.py createsuperuser
```

等待容器健康后创建自己的管理员，打开 `http://localhost:8000/`。

## Compose

将以下内容保存为 `compose.yaml`，执行 `docker compose up -d --wait`：

```yaml
services:
  workbench:
    image: huahua777/teacher-workbench:2026.11.06
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - data:/var/lib/teacher-workbench
      - keyring:/var/lib/teacher-workbench-keyring
    stop_grace_period: 4m
volumes:
  data:
  keyring:
```

随后运行 `docker compose exec workbench python manage.py createsuperuser`。

## 配置与数据

AI 默认关闭。显式设置 `TW_ENABLE_MEMBER_AI=1` 才启用成员生成路径；教师仍需保存自己的百炼北京 `qwen-flash` Key、由管理员设置额度并主动点击生成。不会自动充值或发起模型请求。

两个持久卷分别保存业务数据和加密主密钥，须在停写后配对备份。不要删除卷。新版本如需迁移已有数据库，先备份两个卷，再显式设置 `TW_APPLY_MIGRATIONS=1`。PostgreSQL 主版本变化需逻辑导出/导入。

默认只绑定本机 HTTP。远程真实使用请配置可信 HTTPS 代理及 `TW_ALLOWED_HOSTS`、`TW_TRUSTED_ORIGINS`、`TW_HTTPS=1`；只有经过受信任代理时才设置 `TW_TRUST_PROXY=1`。本镜像不自动申请证书、配置网络或安装 NAS 任务。

数学内容需教师审核，Word 公式、复杂版式和打印请在 WPS 中实际核对。通用聊天、题库、课表、PWA 和 PPTX 等完整第一版目标仍在后续开发范围。
