# Architecture

A governed, event-driven **intake** flow built on Azure Integration Services.
The reference use case is a citizen **permit request**, but the pattern is
generic — swap the schemas and `USE_CASE_PROFILE` to fit any intake scenario.

## Flow

![End-to-end permit-intake flow: Portal → API Management → Logic App → Service Bus → Function → Document Intelligence / Foundry model (via the AI gateway) / case system → Event Grid, with Application Insights tracing](images/architecture-overview.svg)

<sub>Rendered from a draw.io source kept locally (the editable `.drawio` files are not committed).</sub>

## Two governed API surfaces

API Management governs **both** the public API and the model API:

![Two governed surfaces: the Permits API (/permits) and the Azure OpenAI v1 API (/openai/v1) with content-safety, token-limit, token-metric, and managed-identity policies; the Function's compliance call routes back through the gateway](images/apim-ai-gateway.svg)

<sub>Rendered from a draw.io source kept locally (not committed).</sub>

The Function's compliance-scoring call (step B4) routes **back through** the
APIM Azure OpenAI v1 surface (`/openai/v1/responses`), so `llm-content-safety`,
`llm-token-limit`, and `llm-emit-token-metric` apply to every model call — that is the
per-team AI chargeback signal.

## What the demo proves

| Capability | Where | Demo Track step |
| --- | --- | --- |
| API discovery, reuse, and catalog governance | API Center | A2 |
| Governed, secured APIs (rate limiting, `202` only after a confirmed enqueue; Entra token validation variant) | API Management | A4, A6, A14 / B1 |
| AI-gateway cost and safety control (content safety, token limits + quotas, metrics) | API Management | A5 / B4 |
| Reliable async messaging + dead-letter | Service Bus | A8, A15 / B2, B7 |
| AI extraction + validation + advisory compliance score | Document Intelligence + Foundry model (`gpt-5.4-mini`) | A9, A10 / B3, B4 |
| Event-driven fan-out (decoupled subscribers) | Event Grid | A12 / B6 |
| One correlation ID across intake and processing | Application Insights + Log Analytics | A13 / B8 |

## Correlation

A single correlation ID is created at API Management and propagated through the
Logic App, Service Bus message properties, the Function, the CRM write, and the
Event Grid event. In Application Insights the journey is two linked operations:

| Operation | What it contains | How it carries the correlation ID |
| --- | --- | --- |
| Intake | APIM `POST /permits` → Service Bus enqueue (`201`) → `202` | APIM logs the `X-Correlation-Id` request/response header |
| Processing | Function → Document Intelligence → AI gateway (content safety, model) → Event Grid publish | The Function's log records name it; W3C trace context links the Function to the AI-gateway call back through APIM |

The Service Bus hop doesn't carry W3C trace context, so the correlation ID is
the join key. [monitor.py](../src/ais_demo/integrations/monitor.py) finds every
operation that mentions it and returns both in one ordered list —
`GET /api/trace/{correlationId}`, step B8, or the portal's trace card.

## Path to production (APIM landing zone)

The demo uses **public endpoints** for speed. For production, isolate the same
services behind a network-hardened **APIM landing zone** — VNet-integrated APIM,
WAF at the edge, and Private Endpoints for the data + integration tier — aligned
with the [Azure APIM landing zone reference](https://learn.microsoft.com/azure/architecture/example-scenario/integration/app-gateway-internal-api-management-function#architecture).

![APIM landing zone: numbered bands for channels, edge/identity, APIM hub VNet, application spoke VNet, data/integration with private endpoints, and observability/governance](images/apim-landing-zone.svg)

<sub>Rendered from a draw.io source kept locally (not committed). Apply the [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/) before production.</sub>

For the full production checklist — security, reliability, observability,
evaluation, and CI/CD, mapped to WAF pillars and Microsoft reference
architectures — see [production-path.md](production-path.md).

## Repository layout

```
.
├── src/ais_demo/            # Shared application package (orchestrator + integrations)
│   ├── api/                 #   FastAPI host (governed backend)
│   ├── integrations/        #   APIM, Service Bus, Document Intelligence, AI gateway, Event Grid, CRM, Monitor
│   ├── orchestrator.py      #   Function core: extract → score → CRM record → event
│   ├── schemas/             #   Pydantic models
│   ├── core/                #   correlation, logging, telemetry (OpenTelemetry), errors
│   ├── config/              #   pydantic-settings
│   └── demo/                #   Part B (B1-B8) runnable driver
├── functionapp/             # Azure Functions host (Service Bus trigger) — reuses src/ais_demo
├── apim/policies/           # APIM AI-gateway + front-door policy samples
├── infra/                   # Bicep IaC: every resource, APIM API/policy, subscription, and role assignment
├── integration/             # Low-code artifacts: Logic App workflow + Event Grid subscriptions
├── frontend/                # React + TypeScript portal
├── data/                    # Synthetic samples + demo prompts
├── scripts/                 # Setup / run / seed helpers
├── tests/                   # pytest suite
└── docs/                    # This document + Demo Track + deployment guide
```
