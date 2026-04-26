#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

DISTRO_NAME="${DISTRO_NAME:-ubuntu}"
REPO_URL="${REPO_URL:-https://github.com/lioensky/VCPToolBox.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
APP_DIR="${APP_DIR:-$HOME/VCPToolBox}"
UBUNTU_APP_DIR="${UBUNTU_APP_DIR:-/root/VCPToolBox}"

log() {
  printf '[termux-bootstrap] %s\n' "$*"
}

fail() {
  printf '[termux-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

install_termux_packages() {
  log "更新 Termux 基础包..."
  pkg update -y
  pkg install -y git curl proot-distro
}

ensure_repo() {
  if [[ -d "$APP_DIR/.git" ]]; then
    log "检测到 Termux 本地仓库：$APP_DIR"
    return
  fi

  if [[ -d "$APP_DIR" && ! -d "$APP_DIR/.git" ]]; then
    fail "$APP_DIR 已存在但不是 Git 仓库，请先处理该目录。"
  fi

  log "克隆仓库到 Termux：$APP_DIR"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
}

install_ubuntu() {
  if proot-distro login "$DISTRO_NAME" -- true >/dev/null 2>&1; then
    log "Ubuntu 已安装，跳过 rootfs 安装。"
    return
  fi

  log "安装 Ubuntu rootfs..."
  proot-distro install "$DISTRO_NAME"
}

run_in_ubuntu() {
  proot-distro login "$DISTRO_NAME" --shared-tmp -- \
    env \
    UBUNTU_APP_DIR="$UBUNTU_APP_DIR" \
    REPO_URL="$REPO_URL" \
    REPO_BRANCH="$REPO_BRANCH" \
    bash -s
}

prepare_ubuntu() {
  log "在 Ubuntu 中安装基础依赖并部署项目..."
  run_in_ubuntu <<'EOF'
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
APP_DIR="${UBUNTU_APP_DIR:-/root/VCPToolBox}"
REPO_URL="${REPO_URL:-https://github.com/lioensky/VCPToolBox.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

apt-get update
apt-get install -y \
  ca-certificates curl git bash build-essential pkg-config \
  python3 python3-venv python3-pip ffmpeg

if ! command -v node >/dev/null 2>&1 || ! node -v | grep -Eq '^v2[0-9]\.'; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

if [[ -d "$APP_DIR/.git" ]]; then
  cd "$APP_DIR"
  git fetch origin "$REPO_BRANCH"
  git checkout "$REPO_BRANCH"
  git pull --ff-only origin "$REPO_BRANCH"
else
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

if [[ ! -f config.env ]]; then
  cp config.env.example config.env
fi

bash scripts/linux/install.sh
EOF
}

show_next_steps() {
  cat <<EOF

部署完成后请继续执行以下操作：

1. 进入 Ubuntu 修改配置
   proot-distro login "$DISTRO_NAME" -- bash -lc 'cd "$UBUNTU_APP_DIR" && nano config.env'

2. 修改完成后重启服务
   proot-distro login "$DISTRO_NAME" -- bash -lc 'cd "$UBUNTU_APP_DIR" && ./node_modules/.bin/pm2 restart all'

3. 查看状态
   proot-distro login "$DISTRO_NAME" -- bash -lc 'cd "$UBUNTU_APP_DIR" && ./node_modules/.bin/pm2 status'

默认访问地址：
- 主服务: http://127.0.0.1:6005
- 管理面板: http://127.0.0.1:6006/AdminPanel/

EOF
}

main() {
  require_cmd pkg
  install_termux_packages
  ensure_repo
  install_ubuntu
  export REPO_URL REPO_BRANCH UBUNTU_APP_DIR
  prepare_ubuntu
  show_next_steps
}

main "$@"
