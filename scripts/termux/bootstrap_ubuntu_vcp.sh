#!/usr/bin/env bash
set -Eeuo pipefail

DISTRO_NAME="${DISTRO_NAME:-ubuntu}"
REPO_URL="${REPO_URL:-https://github.com/lioensky/VCPToolBox.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
APP_DIR="${APP_DIR:-$HOME/VCPToolBox}"
UBUNTU_APP_DIR="${UBUNTU_APP_DIR:-$HOME/VCPToolBox}"

log() {
  printf '[termux-bootstrap] %s\n' "$*"
}

fail() {
  printf '[termux-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

is_termux_host() {
  [[ -n "${TERMUX_VERSION:-}" ]] && command -v pkg >/dev/null 2>&1
}

is_ubuntu_like() {
  [[ -f /etc/os-release ]] && grep -Eqi '^(ID|ID_LIKE)=(.*ubuntu|.*debian)' /etc/os-release
}

install_termux_packages() {
  log "Updating Termux packages..."
  pkg update -y
  pkg install -y git curl proot-distro
}

ensure_termux_repo() {
  if [[ -d "$APP_DIR/.git" ]]; then
    log "Found local Termux repo: $APP_DIR"
    return
  fi

  if [[ -e "$APP_DIR" ]]; then
    fail "$APP_DIR already exists but is not a Git repo."
  fi

  log "Cloning repo into Termux: $APP_DIR"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
}

install_ubuntu_rootfs() {
  if proot-distro login "$DISTRO_NAME" -- true >/dev/null 2>&1; then
    log "Ubuntu rootfs already installed."
    return
  fi

  log "Installing Ubuntu rootfs..."
  proot-distro install "$DISTRO_NAME"
}

run_in_ubuntu() {
  proot-distro login "$DISTRO_NAME" --shared-tmp -- \
    env \
    REPO_URL="$REPO_URL" \
    REPO_BRANCH="$REPO_BRANCH" \
    UBUNTU_APP_DIR="$UBUNTU_APP_DIR" \
    bash -s
}

ubuntu_install_block() {
  cat <<'EOF'
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
APP_DIR="${UBUNTU_APP_DIR:-$HOME/VCPToolBox}"
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

prepare_from_termux() {
  require_cmd pkg
  install_termux_packages
  ensure_termux_repo
  install_ubuntu_rootfs
  log "Deploying inside Ubuntu..."
  ubuntu_install_block | run_in_ubuntu
}

prepare_from_ubuntu() {
  require_cmd apt-get
  if [[ ! -d .git && ! -f package.json ]]; then
    fail "Please run this script inside the VCPToolBox repository directory in Ubuntu."
  fi

  export UBUNTU_APP_DIR
  UBUNTU_APP_DIR="$(pwd)"
  log "Detected Ubuntu environment. Using apt-based deployment directly..."
  ubuntu_install_block | bash
}

show_next_steps() {
  cat <<EOF

Deployment completed. Recommended next steps:

1. Edit config:
   cd "$UBUNTU_APP_DIR" && nano config.env

2. Restart services:
   cd "$UBUNTU_APP_DIR" && ./node_modules/.bin/pm2 restart all

3. Check status:
   cd "$UBUNTU_APP_DIR" && ./node_modules/.bin/pm2 status

Default URLs:
- Main service:  http://127.0.0.1:6005
- Admin panel:   http://127.0.0.1:6006/AdminPanel/

EOF
}

main() {
  if is_termux_host && [[ "$(id -u)" != "0" ]]; then
    prepare_from_termux
  elif is_ubuntu_like; then
    prepare_from_ubuntu
  else
    fail "Unsupported environment. Run this in Termux host or inside Ubuntu/Debian."
  fi

  show_next_steps
}

main "$@"
