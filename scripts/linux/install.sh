#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
TMP_REQUIREMENTS="$ROOT_DIR/.requirements.linux.tmp"

log() {
  printf '[install] %s\n' "$*"
}

fail() {
  printf '[install] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

node_major_version() {
  local raw_version
  raw_version="$(node -v)"
  raw_version="${raw_version#v}"
  printf '%s' "${raw_version%%.*}"
}

prepare_config() {
  if [[ -f "$ROOT_DIR/config.env" ]]; then
    return
  fi

  cp "$ROOT_DIR/config.env.example" "$ROOT_DIR/config.env"
  log "Created config.env from config.env.example. Edit it before exposing the service to the public network."
}

prepare_venv() {
  if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  python -m pip install --upgrade pip setuptools wheel
}

read_port() {
  local port
  port="$(awk -F= '/^PORT=/{print $2; exit}' "$ROOT_DIR/config.env" 2>/dev/null || true)"
  printf '%s' "${port//[$'\r\t ']}"
}

install_python_requirements() {
  local requirements_file="$1"

  if [[ ! -f "$requirements_file" ]]; then
    return
  fi

  grep -Ev '^\s*(#|$)|^\s*win10toast(\s|=|>|<|!|$)' "$requirements_file" >"$TMP_REQUIREMENTS" || true
  if [[ -s "$TMP_REQUIREMENTS" ]]; then
    log "Installing Python dependencies from ${requirements_file#$ROOT_DIR/}..."
    python -m pip install -r "$TMP_REQUIREMENTS"
  fi
}

install_plugin_python_requirements() {
  while IFS= read -r -d '' requirements_file; do
    install_python_requirements "$requirements_file"
  done < <(find "$ROOT_DIR/Plugin" -type f -name 'requirements.txt' -print0)
}

install_plugin_node_dependencies() {
  while IFS= read -r -d '' package_json; do
    local plugin_dir
    plugin_dir="$(dirname "$package_json")"
    log "Installing Node dependencies in ${plugin_dir#$ROOT_DIR/}..."
    (
      cd "$plugin_dir"
      npm install --legacy-peer-deps --no-fund
    )
  done < <(find "$ROOT_DIR/Plugin" -type f -name 'package.json' -print0)
}

build_admin_panel() {
  log "Installing AdminPanel-Vue dependencies..."
  (
    cd "$ROOT_DIR/AdminPanel-Vue"
    npm install --no-fund
    npm run build:no-type-check
  )
}

start_pm2() {
  local pm2_bin="$ROOT_DIR/node_modules/.bin/pm2"
  [[ -x "$pm2_bin" ]] || fail "PM2 binary not found. Root npm install may have failed."

  log "Starting services with PM2..."
  "$pm2_bin" startOrReload "$ROOT_DIR/ecosystem.config.cjs" --update-env
  "$pm2_bin" save
}

cleanup() {
  rm -f "$TMP_REQUIREMENTS"
}

trap cleanup EXIT

require_cmd git
require_cmd node
require_cmd npm
require_cmd python3

if (( "$(node_major_version)" < 20 )); then
  fail "Node.js 20+ is required. Current version: $(node -v)"
fi

prepare_config
prepare_venv

log "Installing root Node dependencies..."
(
  cd "$ROOT_DIR"
  npm install --no-fund
)

install_python_requirements "$ROOT_DIR/requirements.txt"
install_plugin_python_requirements
build_admin_panel
install_plugin_node_dependencies
start_pm2

PORT_VALUE="$(read_port)"
if [[ "$PORT_VALUE" =~ ^[0-9]+$ ]]; then
  ADMIN_PORT="$((PORT_VALUE + 1))"
else
  PORT_VALUE="6005"
  ADMIN_PORT="6006"
fi

log "Install completed."
log "Main service:  http://127.0.0.1:${PORT_VALUE}"
log "Admin panel:   http://127.0.0.1:${ADMIN_PORT}/AdminPanel/"
