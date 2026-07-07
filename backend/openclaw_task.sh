#!/bin/sh
set -eu

cd /app
export PYTHONPATH=/app${PYTHONPATH:+:$PYTHONPATH}

exec python3 /app/backend/openclaw_ops_tasks.py "$@"
