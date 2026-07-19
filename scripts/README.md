# `scripts/` — helper scripts

Convenience scripts for setting up, running, and rehearsing the demo. Run them
from the repo root.

| Script | What it does |
| --- | --- |
| [`setup.sh`](setup.sh) | One-time dev setup: `uv sync --extra dev`, `npm install` in `frontend/`, and create `.env` from `.env.example`. |
| [`app.sh`](app.sh) | **Start/stop the local portal.** Runs the FastAPI backend (:8000) + Vite frontend (:5173) in the background. Commands: `start`, `stop`, `restart`, `status`, `logs`. |
| [`run_local.sh`](run_local.sh) | Run the backend + frontend together in the **foreground** (Ctrl-C stops both). |
| [`run_demo.sh`](run_demo.sh) | **Live rehearsal against Azure.** Drives both governed front doors — Part A (APIM → Logic App) and Part B (APIM direct) — plus an AI-gateway call, and prints the correlated App Insights trace. Usage: `run_demo.sh [a|b|all]`. |
| [`seed_permits.py`](seed_permits.py) | Seed the Service Bus queue with sample permits (live or simulated). Run with `uv run python scripts/seed_permits.py [count]`. |
| [`get_token.sh`](get_token.sh) | Mint an Entra ID access token (OAuth2 client-credentials) for the JWT-protected Permits API — used in Demo Track step A14 to show `202` with a valid token and `401` without. Reads `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `API_SCOPE`. |

## Common flows

```bash
# First time
./scripts/setup.sh

# Local portal (simulated, no Azure)
./scripts/app.sh start        # → http://localhost:5173
./scripts/app.sh status
./scripts/app.sh stop

# Rehearse the deployed demo end to end
./scripts/run_demo.sh         # both paths + AI gateway
```

`app.sh` honors env overrides: `SIMULATED_MODE` (default `true`), `API_PORT`
(8000), `WEB_PORT` (5173). PIDs and logs are written to `.run/` (gitignored).

See the [root README](../README.md) for the full picture and
[src/ais_demo/README.md](../src/ais_demo/README.md) for the package internals.
