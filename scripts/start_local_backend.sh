#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR/backend"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

export APP_MODE="${APP_MODE:-local}"
export LOCAL_TEST_MODE="${LOCAL_TEST_MODE:-true}"
export LOCAL_OUTBOUND_CALLS="${LOCAL_OUTBOUND_CALLS:-false}"
export ENVIRONMENT="${ENVIRONMENT:-development}"
export ALLOW_UNAUTHENTICATED_REQUESTS="${ALLOW_UNAUTHENTICATED_REQUESTS:-true}"
export VERIFY_TWILIO_SIGNATURES="${VERIFY_TWILIO_SIGNATURES:-false}"
export SERVER_DOMAIN="${SERVER_DOMAIN:-localhost:8000}"
export ALLOWED_HOSTS="${ALLOWED_HOSTS:-localhost,127.0.0.1}"
export MAX_REQUEST_BODY_BYTES="${MAX_REQUEST_BODY_BYTES:-65536}"

PORT="${PORT:-8000}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
if [ ! -x "$PYTHON_BIN" ] && [ -x "$ROOT_DIR/$PYTHON_BIN" ]; then
  PYTHON_BIN="$ROOT_DIR/$PYTHON_BIN"
fi

exec "$PYTHON_BIN" -m uvicorn main:app --reload --host 127.0.0.1 --port "$PORT"
