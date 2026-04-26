# 安卓手机部署说明：Termux / Termux:X11 + Ubuntu

这份文档讲的是：在安卓手机上安装 `Termux`，再通过 `proot-distro` 安装 Ubuntu，然后部署当前项目。

先说结论：

- 这套方案适合个人测试、轻量自用、临时演示
- 不适合高可用公网生产环境
- 你如果只是想“手机上能跑、能更新、能打开后台”，这套方案是可行的

## 适用前提

建议设备满足：

- Android 8 及以上
- 64 位 CPU
- 至少 6GB RAM，推荐 8GB+
- 至少 8GB 可用存储，推荐 15GB+

## 重要说明

### 1. `Termux:X11` 不是必须

这个项目本质是服务端应用，不依赖图形桌面才能启动。

也就是说：

- 只装 `Termux` 就能部署
- `Termux:X11` 主要用于你想在手机里跑 Linux 图形桌面

如果你只是想访问后台：

- 直接用手机浏览器打开 `http://127.0.0.1:6006/AdminPanel/`
- 或者用局域网 IP 从别的设备访问

### 2. 手机后台保活有限

安卓系统会杀后台、限制常驻进程、限制省电模式。

所以你需要尽量：

- 给 Termux 关闭电池优化
- 允许后台运行
- 不要让系统自动清理它

### 3. 公网暴露前请先加反向代理或隧道

如果你要从外网访问，不建议手机直接裸露端口。更建议：

- Tailscale
- 内网穿透
- FRP
- Cloudflare Tunnel

## 推荐安装顺序

### 第 1 步：安装 Termux

建议从官方 GitHub Releases 或 F-Droid 安装，不建议使用过旧来源。

### 第 2 步：可选安装 Termux:X11

如果你需要图形桌面，再安装 `Termux:X11`。它需要：

- Android App
- Termux 里的 companion package

如果你不需要图形桌面，这一步可以跳过。

### 第 3 步：Termux 中安装基础包

打开 Termux，执行：

```bash
pkg update
pkg install -y git curl proot-distro
termux-setup-storage
```

### 第 4 步：安装 Ubuntu

```bash
proot-distro install ubuntu
```

进入 Ubuntu：

```bash
proot-distro login ubuntu
```

## 一键引导脚本

我已经在仓库里加了手机端引导脚本：

- [scripts/termux/bootstrap_ubuntu_vcp.sh](/D:/project/vcp/VCPToolBox/scripts/termux/bootstrap_ubuntu_vcp.sh:1)

这个脚本需要在 Termux 里执行，它会自动：

- 检查并安装 `proot-distro`
- 安装 Ubuntu
- 在 Ubuntu 里安装 Git / Python / ffmpeg / Node.js 20
- 克隆当前仓库
- 自动复制 `config.env.example`
- 调用项目自己的 Linux 安装脚本完成部署

## 最简部署步骤

### 方案 A：你已经把仓库放到手机上

在 Termux 里：

```bash
cd ~/VCPToolBox
bash scripts/termux/bootstrap_ubuntu_vcp.sh
```

### 方案 B：手机上还没有仓库

在 Termux 里直接执行：

```bash
git clone https://github.com/lioensky/VCPToolBox.git
cd VCPToolBox
bash scripts/termux/bootstrap_ubuntu_vcp.sh
```

## 脚本执行完以后你要做的事

脚本第一次跑完后，请进入 Ubuntu 检查并修改配置：

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && nano config.env'
```

重点至少改这些：

- `API_Key`
- `API_URL`
- `PORT`
- `Key`
- `Image_Key`
- `File_Key`
- `VCP_Key`
- `AdminUsername`
- `AdminPassword`

改完后重启服务：

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && ./node_modules/.bin/pm2 restart all'
```

## 手机上的启动、更新、日志命令

### 启动 Ubuntu

```bash
proot-distro login ubuntu
```

### 查看 PM2 状态

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && ./node_modules/.bin/pm2 status'
```

### 查看日志

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && ./node_modules/.bin/pm2 logs'
```

### 更新代码

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && bash scripts/linux/update.sh'
```

### 指定分支更新

```bash
proot-distro login ubuntu -- bash -lc 'cd ~/VCPToolBox && bash scripts/linux/update.sh main'
```

## 访问地址

如果 `PORT=6005`：

- 主服务：`http://127.0.0.1:6005`
- 管理面板：`http://127.0.0.1:6006/AdminPanel/`

如果只在本机访问，直接用手机浏览器打开就可以。

如果你想让同一局域网其他设备访问，需要确认手机 IP，然后访问：

- `http://手机IP:6005`
- `http://手机IP:6006/AdminPanel/`

注意：部分安卓网络环境、热点模式和厂商限制会影响局域网访问。

## Termux:X11 图形桌面是否值得开

如果你的目标只是运行 VCPToolBox：

- 不建议专门为了它开 Ubuntu 图形桌面

如果你的目标是：

- 手机里顺便跑一个 Linux 图形环境
- 再在图形环境里开浏览器访问后台

那可以装 `Termux:X11`，但资源占用会更高，手机更容易发热和掉后台。

## 已知限制

- `proot` 环境下性能不如真 Linux
- 长时间运行会更耗电
- Puppeteer / Chromium 相关功能在手机上不一定稳定
- 大型插件、重向量化、重构建时容易占满内存
- 安卓系统可能会在锁屏后中断长任务

## 更稳的使用建议

如果你真要长期用手机跑，建议这样配：

- 平时只在需要时启动 Ubuntu
- 用 `pm2` 维持两个 Node 进程
- 尽量关闭大批量索引/重建任务
- 把 `PORT`、后台密码和 API 密钥配置完整
- 配合 Tailscale 或 FRP，而不是直接开公网端口
