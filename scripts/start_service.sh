#!/bin/sh
set -eu

APP_DIR="${OPENCLAW_APP_DIR:-/app}"
export PYTHONPATH="${APP_DIR}${PYTHONPATH:+:$PYTHONPATH}"

if [ "${APP_MODULE:-main:app}" = "openclaw_ops:app" ]; then
  STATE_DIR="${OPENCLAW_STATE_DIR:-/data/openclaw-ops}"
  mkdir -p "$STATE_DIR"
  export HOME="${OPENCLAW_HOME:-$STATE_DIR/home}"
  mkdir -p "$HOME"
  export OPENCLAW_OPS_LOG_PATH="${OPENCLAW_OPS_LOG_PATH:-$STATE_DIR/openclaw-ops.log}"
  touch "$OPENCLAW_OPS_LOG_PATH"
fi

install_openclaw_runtime() {
  if [ "${OPENCLAW_INSTALL_RUNTIME:-0}" != "1" ]; then
    return 0
  fi

  if [ "${APP_MODULE:-}" != "openclaw_ops:app" ]; then
    return 0
  fi

  if command -v openclaw >/dev/null 2>&1; then
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl
  rm -rf /var/lib/apt/lists/*

  curl -fsSL https://openclaw.ai/install.sh | bash

  if command -v npm >/dev/null 2>&1; then
    export PATH="$(npm prefix -g)/bin:$PATH"
  fi
}

install_openclaw_runtime
exec uvicorn "$APP_MODULE" --host 0.0.0.0 --port "$PORT"
