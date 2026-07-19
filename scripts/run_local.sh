#!/usr/bin/env bash
# Start the API (FastAPI) and the portal (Vite) for local development.
set -euo pipefail
cd "$(dirname "$0")/.."

cleanup() { kill 0 2>/dev/null || true; }
trap cleanup EXIT

echo "==> Starting FastAPI on http://localhost:8000"
uv run uvicorn ais_demo.api.main:app --reload --app-dir src --port 8000 &

echo "==> Starting portal on http://localhost:5173"
(cd frontend && npm run dev) &

wait
