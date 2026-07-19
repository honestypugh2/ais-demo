# Demo Track — Permit Intake (Azure Portal & Python SDK)

A generic, reusable Demo Track for the Azure Integration Services demo. It shows
the **same governed flow two ways**: a Portal click-through (Part A) and the
Azure SDK for Python (Part B). ~28 minutes end to end. All data is synthetic.

> Replace bracketed placeholders (e.g. `<your-apim>`, `rg-ais-demo`) with your
> own resource names. No customer-specific content is included.

## Scenario

A resident submits a permit packet; it is validated, routed, extracted, scored,
recorded in CRM, and confirmed — reliably, securely, and observably.

```
Portal → API Management → Logic App → Service Bus → Function/AI agent → CRM → Event Grid → Notification
```

## Timing

| Time | Segment | Content |
| --- | --- | --- |
| 0:00–0:02 | Set the scene | The flow and what it proves |
| 0:02–0:12 | Part A — Azure Portal | Steps A1–A15 |
| 0:12–0:24 | Part B — Python SDK | Steps B1–B8 (`uv run ais-demo`) |
| 0:24–0:28 | Observability & wrap | Walk the single correlated transaction |

## Part A — Azure Portal walkthrough

| Step | Screen | Point to make |
| --- | --- | --- |
| A1 | Resource group | One group, one correlation ID, one governance model |
| A2 | APIM → Permits API | Single governed front door; consumers never touch the backend |
| A3 | APIM → Products/Subscriptions | Per-consumer keys + quota → usage attribution |
| A4 | APIM → Inbound policy | `validate-jwt`, `rate-limit-by-key`, correlation ID — policy, not process |
| A5 | APIM → Azure OpenAI policy | `azure-openai-token-limit` + `azure-openai-emit-token-metric` (AI chargeback) |
| A6 | APIM → Test console | Submit a valid packet → `202` + `X-Correlation-Id` |
| A7 | Logic App → run history | validate → enrich → send-to-Service-Bus |
| A8 | Service Bus Explorer | Durable message on `permits-in`; dead-letter sub-queue |
| A9 | Function → log stream | Extraction, field validation, compliance score |
| A10 | Document Intelligence | Analyzed document, key-value pairs |
| A11 | CRM | New permit record with extracted fields + score |
| A12 | Event Grid → subscriptions | `PermitCreated` fans out to notification + analytics |
| A13 | App Insights → transaction | One trace: APIM → Logic App → SB → Function → CRM → Event Grid |
| A14 | APIM → invalid token | `401` at the door (and `429` when rate limit trips) |
| A15 | Service Bus → dead-letter | Poison message dead-lettered after retries — nothing lost |

## Part B — Azure SDK for Python walkthrough

Run the whole thing offline: `uv run ais-demo`. Each step maps to a Demo Track
cell and a module in `src/ais_demo`:

| Step | Says | Code |
| --- | --- | --- |
| B1 | Submit through APIM (Entra auth) | `integrations/apim_client.py` |
| B2 | Publish to Service Bus (durable) | `integrations/service_bus.py` |
| B3 | Extract fields (Document Intelligence) | `integrations/document_intelligence.py` |
| B4 | Validate & score (AI gateway) | `integrations/ai_gateway.py` |
| B5 | Write to CRM | `integrations/crm.py` |
| B6 | Publish `PermitCreated` (Event Grid) | `integrations/event_grid.py` |
| B7 | Resilience — dead-letter poison msg | `integrations/service_bus.py` |
| B8 | Query end-to-end trace (Monitor) | `integrations/monitor.py` |

## Facilitation tip

Part A tells the story visually; Part B proves the contract for engineers. If
time is short, run Part A in full and show B1, B3, B4, and B8 only — submit,
extract, validate, and the end-to-end trace.

## Reset, teardown & fallback

- **Reset:** purge `permits-in` + its dead-letter sub-queue; delete test CRM
  records. In simulated mode the in-memory queues reset on each `ais-demo` run.
- **Teardown:** delete the resource group (`rg-ais-demo`) to remove everything.
- **Fallback:** if a service fails on stage, switch to saved screenshots for
  that step and keep narrating — the narrative (governed → reliable → validated
  → observable) is the point.

## Reference accelerators

This demo augments open-source accelerators (synthetic data; not production):
an AI validation core (Document Intelligence + AI Search + Agent Framework) and
an APIM AI-gateway pattern (token limits, token metrics, managed-identity
backend auth, correlation ID). Before any production use, apply each project's
hardening guidance and an Azure Well-Architected review.
