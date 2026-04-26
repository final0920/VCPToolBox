#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
TMP_REQUIREMENTS="$ROOT_DIR/.requirements.linux.tmp"
REMOTE_NAME="${REMOTE_NAME:-origin}"
FORCE_INSTALL="${FORCE_INSTALL:-0}"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common/config_crypto.sh"

log() {
  printf '[update] %s\n' "$*"
}

fail() {
  printf '[update] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

prepare_venv() {
  [[ -d "$VENV_DIR" ]] || fail "Python virtual environment not found. Run scripts/linux/install.sh first."
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
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
  log "Building AdminPanel-Vue..."
  (
    cd "$ROOT_DIR/AdminPanel-Vue"
    npm install --no-fund
    npm run build:no-type-check
  )
}

has_changed_file() {
  local pattern="$1"
  grep -Eq "$pattern" <<<"$CHANGED_FILES"
}

reload_pm2() {
  local pm2_bin="$ROOT_DIR/node_modules/.bin/pm2"
  [[ -x "$pm2_bin" ]] || fail "PM2 binary not found. Root npm install may have failed."

  log "Reloading PM2 processes..."
  "$pm2_bin" startOrReload "$ROOT_DIR/ecosystem.config.cjs" --update-env
  "$pm2_bin" save
}

cleanup() {
  rm -f "$TMP_REQUIREMENTS"
}

trap cleanup EXIT

cd "$ROOT_DIR"

require_cmd git
require_cmd node
require_cmd npm
require_cmd python3
require_cmd openssl

decrypt_config_env

if [[ "$ALLOW_DIRTY" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  fail "Working tree is not clean. Commit/stash local changes first, or re-run with ALLOW_DIRTY=1."
fi

CURRENT_BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
BEFORE_REV="$(git rev-parse HEAD)"

log "Fetching latest code from $REMOTE_NAME/$CURRENT_BRANCH..."
git fetch "$REMOTE_NAME" "$CURRENT_BRANCH"
git pull --ff-only "$REMOTE_NAME" "$CURRENT_BRANCH"

AFTER_REV="$(git rev-parse HEAD)"
CHANGED_FILES="$(git diff --name-only "$BEFORE_REV" "$AFTER_REV" || true)"

prepare_venv

if [[ "$BEFORE_REV" == "$AFTER_REV" && "$FORCE_INSTALL" != "1" && -d "$ROOT_DIR/node_modules" && -d "$ROOT_DIR/AdminPanel-Vue/node_modules" ]]; then
  log "No new commits. Reloading services only."
  reload_pm2
  exit 0
fi

if [[ "$FORCE_INSTALL" == "1" || ! -d "$ROOT_DIR/node_modules" ]] || has_changed_file '^(package\.json|package-lock\.json)$'; then
  log "Installing root Node dependencies..."
  npm install --no-fund
fi

if [[ "$FORCE_INSTALL" == "1" ]] || has_changed_file '^(requirements\.txt|pyproject\.toml|poetry\.lock)$'; then
  install_python_requirements "$ROOT_DIR/requirements.txt"
fi

if [[ "$FORCE_INSTALL" == "1" ]] || has_changed_file '^Plugin/.+/(requirements\.txt)$'; then
  install_plugin_python_requirements
fi

if [[ "$FORCE_INSTALL" == "1" || ! -d "$ROOT_DIR/AdminPanel-Vue/node_modules" ]] || has_changed_file '^AdminPanel-Vue/'; then
  build_admin_panel
fi

if [[ "$FORCE_INSTALL" == "1" ]] || has_changed_file '^Plugin/.+/(package\.json|package-lock\.json)$'; then
  install_plugin_node_dependencies
fi

reload_pm2

log "Update completed: $BEFORE_REV -> $AFTER_REV"
