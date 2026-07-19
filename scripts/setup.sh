#!/usr/bin/env bash
# Local dev setup: sync Python deps (uv) and install frontend deps (npm).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Syncing Python dependencies with uv"
uv sync --extra dev

echo "==> Installing frontend dependencies"
if [ -d frontend ]; then
  (cd frontend && npm install)
fi

if [ ! -f .env ]; then
  echo "==> Creating .env from .env.example (edit values as needed)"
  cp .env.example .env
fi

echo "==> Done. Run the demo with: uv run ais-demo"
