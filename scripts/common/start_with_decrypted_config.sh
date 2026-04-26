#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_SCRIPT="${1:-}"

[[ -n "$TARGET_SCRIPT" ]] || {
  printf '[start-with-config] ERROR: Missing target script.\n' >&2
  exit 1
}

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/common/config_crypto.sh"

decrypt_config_env

cd "$ROOT_DIR"
exec node "$TARGET_SCRIPT"
