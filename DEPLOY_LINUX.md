# Linux 部署说明

当前项目可以部署到 Linux。结合这个仓库的结构来看，最适合“经常 `git pull` 更新”的方式是：

- 服务器上直接保留 Git 工作区
- 用 `pm2` 托管 `server.js` 和 `adminServer.js`
- 用项目本地 `.venv` 承载 Python 插件依赖
- 用一个更新脚本统一处理 `git pull`、依赖刷新、前端构建和进程重载

## 为什么推荐这套方案

这个项目不是单进程结构：

- 主服务是 `server.js`
- 管理面板是 `adminServer.js`
- 管理面板端口固定是主端口 `PORT + 1`

仓库当前自带的 Docker 配置可以作为参考，但它现在更偏“能起主服务”，不太适合你这种高频更新场景。对比下来，`pm2 + git pull` 更直接，也更容易排查问题。

## 推荐系统环境

建议优先使用：

- Ubuntu 22.04 / 24.04
- Debian 12

建议先安装这些基础包：

```bash
sudo apt-get update
sudo apt-get install -y \
  git curl build-essential pkg-config \
  python3 python3-venv python3-pip \
  ffmpeg
```

要求：

- Node.js 20 及以上
- Python 3

如果你会用到依赖浏览器内核的功能，再额外安装 Chromium，并按需配置 `PUPPETEER_EXECUTABLE_PATH`。

## 首次部署

### 1. 克隆项目

```bash
git clone https://github.com/lioensky/VCPToolBox.git
cd VCPToolBox
```

### 2. 准备配置文件

```bash
cp config.env.example config.env
```

至少需要填写这些配置：

- `API_Key`
- `API_URL`
- `PORT`
- `Key`
- `Image_Key`
- `File_Key`
- `VCP_Key`
- `AdminUsername`
- `AdminPassword`

### 3. 执行安装脚本

```bash
bash scripts/linux/install.sh
```

这个脚本会自动完成：

- 创建 `.venv`
- 安装根目录 Node 依赖
- 安装根目录 Python 依赖
- 安装插件目录下的 Python 依赖
- 安装插件目录下的 Node 依赖
- 构建 `AdminPanel-Vue`
- 用 `pm2` 启动 `vcp-main` 和 `vcp-admin`

## 日常更新

平时更新代码时，直接执行：

```bash
bash scripts/linux/update.sh
```

如果你要明确指定分支：

```bash
bash scripts/linux/update.sh main
```

这个脚本会自动做这些事：

- `git fetch`
- `git pull --ff-only`
- 仅在根目录依赖清单变化时重装根依赖
- 仅在插件依赖清单变化时重装插件依赖
- 仅在 `AdminPanel-Vue` 变化时重建前端
- 最后 reload `pm2`

### 常用可选参数

如果你在服务器工作区里故意保留了本地改动：

```bash
ALLOW_DIRTY=1 bash scripts/linux/update.sh
```

如果你想强制完整刷新依赖：

```bash
FORCE_INSTALL=1 bash scripts/linux/update.sh
```

## PM2 管理

常用命令：

```bash
./node_modules/.bin/pm2 status
./node_modules/.bin/pm2 logs vcp-main
./node_modules/.bin/pm2 logs vcp-admin
./node_modules/.bin/pm2 restart vcp-main
./node_modules/.bin/pm2 restart vcp-admin
```

设置开机自启：

```bash
sudo env PATH="$PATH" ./node_modules/.bin/pm2 startup systemd -u "$USER" --hp "$HOME"
./node_modules/.bin/pm2 save
```

## 端口说明

- 主服务端口：`PORT`
- 管理面板端口：`PORT + 1`

如果 `PORT=6005`，那么：

- 主服务地址：`http://服务器IP:6005`
- 管理面板地址：`http://服务器IP:6006/AdminPanel/`

## 关键文件

- PM2 配置：[ecosystem.config.cjs](/D:/project/vcp/VCPToolBox/ecosystem.config.cjs:1)
- Linux 首次部署脚本：[scripts/linux/install.sh](/D:/project/vcp/VCPToolBox/scripts/linux/install.sh:1)
- Linux 更新脚本：[scripts/linux/update.sh](/D:/project/vcp/VCPToolBox/scripts/linux/update.sh:1)

## 目前 Docker 方案的注意点

仓库里已经有 `Dockerfile` 和 `docker-compose.yml`，但当前实现里：

- 容器默认启动命令主要是主服务
- `docker-compose.yml` 只显式映射了主端口
- 管理面板对应的独立进程没有被完整纳入现成的双进程编排

所以如果你的目标是：

- 方便更新
- 出问题容易修
- 后台和主服务都稳定可控

那目前更推荐直接用这套原生 Linux + PM2 方案。
