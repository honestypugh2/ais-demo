# `frontend/` — Permit Intake Portal (React + TypeScript)

The demo **portal UI** — a stand-in for a public-facing permit portal. Built with
React + TypeScript on Vite. It calls the governed backend (via APIM in the
deployed flow, via the Vite dev proxy locally) and visualizes the whole journey:
**submit → processing result → end-to-end trace**.

![Permit Intake Portal — result and end-to-end trace](../docs/images/ais_demo_permitsubmit_07172026.png)

## What it shows

| Card | Content |
| --- | --- |
| **Submit a permit** | Applicant / type / parcel form; returns the correlation ID. |
| **Processing result** | Permit ID, status, compliance score (0–100), flags, event-published. |
| **End-to-end trace** | The correlated hops (APIM → Logic App → Function → Event Grid) with durations. |

A status bar shows the live **mode** (simulated/live), version, and use-case profile.

## Structure

```
frontend/
├── index.html            # app shell
├── vite.config.ts        # dev server + proxy (/api → http://localhost:8000)
├── package.json
└── src/
    ├── main.tsx          # React entry point
    ├── App.tsx           # the three-card portal + submit flow
    ├── api.ts            # API client (/api/health, /api/permits, /api/process, /api/trace)
    ├── types.ts          # shared TypeScript interfaces
    └── styles.css        # portal styling
```

## Run

The backend must be running on :8000 (the dev proxy forwards `/api` to it).

```bash
# Easiest — start backend + this portal together:
../scripts/app.sh start        # → http://localhost:5173

# Or run just the frontend (backend already up):
npm install
npm run dev
```

- Portal: <http://localhost:5173>
- Point at the **live** APIM flow instead of the local backend by setting
  `VITE_API_BASE` to the APIM gateway URL (and running the backend with
  `SIMULATED_MODE=false`).

## Scripts

| Command | Purpose |
| --- | --- |
| `npm run dev` | Vite dev server (hot reload). |
| `npm run build` | Type-check + production build. |
| `npm run lint` | TypeScript no-emit check. |

See the [root README](../README.md) for the full demo and
[src/ais_demo/README.md](../src/ais_demo/README.md) for the backend it calls.
