#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-$ROOT_DIR/config.env}"
CONFIG_ENV_ENC_FILE="${CONFIG_ENV_ENC_FILE:-$ROOT_DIR/config.env.enc}"
CONFIG_ENV_EXAMPLE_FILE="${CONFIG_ENV_EXAMPLE_FILE:-$ROOT_DIR/config.env.example}"
CONFIG_ENV_ALGO="${CONFIG_ENV_ALGO:-aes-256-cbc}"

crypto_log() {
  printf '[config-crypto] %s\n' "$*"
}

crypto_fail() {
  printf '[config-crypto] ERROR: %s\n' "$*" >&2
  exit 1
}

require_crypto_cmd() {
  command -v "$1" >/dev/null 2>&1 || crypto_fail "Missing command: $1"
}

config_key_args() {
  if [[ -n "${CONFIG_ENV_KEY_FILE:-}" ]]; then
    [[ -f "$CONFIG_ENV_KEY_FILE" ]] || crypto_fail "CONFIG_ENV_KEY_FILE does not exist: $CONFIG_ENV_KEY_FILE"
    printf '%s\n' "-pass"
    printf '%s\n' "file:$CONFIG_ENV_KEY_FILE"
    return
  fi

  if [[ -n "${CONFIG_ENV_PASSPHRASE:-}" ]]; then
    printf '%s\n' "-pass"
    printf '%s\n' "pass:$CONFIG_ENV_PASSPHRASE"
    return
  fi

  crypto_fail "Missing decryption secret. Set CONFIG_ENV_PASSPHRASE or CONFIG_ENV_KEY_FILE."
}

decrypt_config_env() {
  require_crypto_cmd openssl

  if [[ -f "$CONFIG_ENV_FILE" && ! -f "$CONFIG_ENV_ENC_FILE" ]]; then
    crypto_log "Plain config.env exists. Skipping decrypt."
    return
  fi

  if [[ -f "$CONFIG_ENV_ENC_FILE" ]]; then
    mapfile -t key_args < <(config_key_args)
    openssl enc -"${CONFIG_ENV_ALGO}" -d -pbkdf2 -salt \
      -in "$CONFIG_ENV_ENC_FILE" \
      -out "$CONFIG_ENV_FILE" \
      "${key_args[@]}"
    chmod 600 "$CONFIG_ENV_FILE" 2>/dev/null || true
    crypto_log "Decrypted config.env from config.env.enc."
    return
  fi

  if [[ -f "$CONFIG_ENV_EXAMPLE_FILE" && ! -f "$CONFIG_ENV_FILE" ]]; then
    cp "$CONFIG_ENV_EXAMPLE_FILE" "$CONFIG_ENV_FILE"
    crypto_log "config.env.enc not found. Created config.env from config.env.example."
    return
  fi

  crypto_fail "No config source found. Expected config.env.enc or config.env.example."
}

encrypt_config_env() {
  require_crypto_cmd openssl
  [[ -f "$CONFIG_ENV_FILE" ]] || crypto_fail "config.env not found: $CONFIG_ENV_FILE"

  mapfile -t key_args < <(config_key_args)
  openssl enc -"${CONFIG_ENV_ALGO}" -e -pbkdf2 -salt \
    -in "$CONFIG_ENV_FILE" \
    -out "$CONFIG_ENV_ENC_FILE" \
    "${key_args[@]}"
  chmod 600 "$CONFIG_ENV_ENC_FILE" 2>/dev/null || true
  crypto_log "Encrypted config.env to config.env.enc."
}
