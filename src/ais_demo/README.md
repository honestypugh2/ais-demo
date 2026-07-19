# `ais_demo` — shared application package

The reusable Python package behind the AIS permit-intake demo. It contains the
**orchestrator** and the **integration adapters** for each Azure Integration
Service, plus the FastAPI app and the Python SDK walkthrough. Every integration
has a **simulated fallback**, so the whole package runs offline
(`SIMULATED_MODE=true`) and switches to live Azure when configured — no code
change.

## Layout

```
ais_demo/
├── __init__.py              # package version + exports
├── orchestrator.py          # the permit pipeline: extract → score → CRM → event
├── api/
│   └── main.py              # FastAPI app: /api/health, /api/permits, /api/process, /api/trace
├── config/
│   └── settings.py          # pydantic-settings loaded from environment / .env
├── core/
│   ├── correlation.py       # correlation-id helpers (X-Correlation-Id end to end)
│   ├── logging.py           # structured logging configuration
│   └── errors.py            # application errors + FastAPI handlers
├── integrations/           # one adapter per Azure service (live + simulated)
│   ├── apim_client.py       # calls the governed API surface (APIM front door)
│   ├── service_bus.py       # enqueue permits onto the Service Bus queue
│   ├── document_intelligence.py  # extract fields from the permit document
│   ├── ai_gateway.py        # compliance scoring via Azure OpenAI behind APIM
│   ├── crm.py               # create the downstream CRM/records entry
│   ├── event_grid.py        # publish PermitCreated to Event Grid
│   └── monitor.py           # query the end-to-end trace (Log Analytics / KQL)
├── schemas/
│   └── permit.py            # Pydantic models (PermitRequest, ExtractedPermit, …)
└── demo/
    └── run_demo.py          # Part B: the Python SDK walkthrough (B1–B8)
```

## The pipeline (`orchestrator.py`)

A submitted permit flows through these steps — each delegated to an adapter in
`integrations/`, each carrying the same correlation ID:

1. **Enqueue** → `service_bus` (durable, decoupled intake)
2. **Extract** → `document_intelligence` (fields from the application)
3. **Score** → `ai_gateway` (0–100 compliance score via Azure OpenAI behind APIM)
4. **Record** → `crm` (create the downstream case)
5. **Publish** → `event_grid` (`PermitCreated` fan-out to subscribers)
6. **Trace** → `monitor` (the correlated journey across every hop)

## Modes

| Setting | Behaviour |
| --- | --- |
| `SIMULATED_MODE=true` (default) | All adapters use in-memory fakes. No Azure, no credentials. |
| `SIMULATED_MODE=false` | Adapters call live Azure using `DefaultAzureCredential` / the APIM subscription key. |

Configuration is environment-driven — see `config/settings.py` for the full list
of settings and their aliases, and `.env.example` at the repo root for a template.

## Run

```bash
# FastAPI backend (simulated)
SIMULATED_MODE=true uv run uvicorn ais_demo.api.main:app --app-dir src --port 8000

# Part B — Python SDK walkthrough (B1–B8)
uv run python -m ais_demo.demo.run_demo

# Quality gates
uv run ruff check .
uv run mypy
uv run pytest
```

Or use the control script from the repo root:

```bash
scripts/app.sh start     # backend + portal
scripts/app.sh status
scripts/app.sh stop
```

## Adapting to another use case

The package is intentionally generic. To retarget it (e.g. claims intake, invoice
approval), keep `orchestrator.py`'s shape and swap the field schema in
`schemas/permit.py`, the scoring rubric in `integrations/ai_gateway.py`, and the
`USE_CASE_PROFILE` setting. The integration adapters and the governance model stay
the same.

> Synthetic data only. Development/proof-of-concept use — apply the
> [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
> before production.

