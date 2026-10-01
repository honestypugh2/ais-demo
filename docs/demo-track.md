# Demo Track — Permit Intake (Azure Portal & Python SDK)

A generic, reusable Demo Track for the Azure Integration Services demo. It shows
the **same governed flow two ways**: a Portal click-through (Part A) and the
Azure SDK for Python (Part B). ~28 minutes end to end. All data is synthetic.

> Replace bracketed placeholders (e.g. `<your-apim>`, `rg-ais-demo`) with your
> own resource names. No customer-specific content is included.

## Scenario

A resident submits a permit packet; it is validated, routed, extracted, scored,
recorded in the case system, and confirmed — reliably, securely, and observably.

```
Portal → API Management → Logic App → Service Bus → Function/AI agent → case system (CRM) → Event Grid → Notification
```

`202 Accepted` means the permit is **durably on the queue** — not that it was
approved. The model score is advisory: it routes the permit to a human review
state (`IntakeReview` or `NeedsAttention`).

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
| A1 | Resource group | One group, one correlation ID, one governance model (Foundry resource, APIM, API Center, Logic App, Service Bus, Function, Event Grid, Document Intelligence, Application Insights) |
| A2 | API Center → APIs, then APIM → Permits API | Discover and reuse the cataloged contract; APIM remains the governed front door |
| A3 | APIM → Subscriptions | Per-consumer keys → usage attribution (the Function has its own `permit-processor` key scoped to the model API) |
| A4 | APIM → Permits API → Inbound policy | `rate-limit-by-key`, correlation ID, managed-identity enqueue, `202` only after Service Bus confirms (`503` otherwise). Entra variant: `validate-azure-ad-token` |
| A5 | APIM → Azure OpenAI v1 policy | `llm-content-safety` (Prompt Shields) + `llm-token-limit` (TPM + monthly quota) + `llm-emit-token-metric` (chargeback) + managed identity to the Foundry model |
| A6 | APIM → Test console (`permits-orchestrated`) | Submit a valid packet → `202` + `X-Correlation-Id` |
| A7 | Logic App → run history | correlation ID → validate → enrich → broker properties (parcel = `MessageId`) → send to Service Bus → `202` |
| A8 | Service Bus Explorer | Durable message on `permits-in`; dead-letter sub-queue; duplicate detection on the parcel |
| A9 | Function → log stream | `compliance score=… correlationId=…` and `Processed permit … status=…` |
| A10 | Document Intelligence | `prebuilt-layout` with the key-value pairs add-on |
| A11 | Case system (CRM) | Record with extracted fields + score (in-memory stub unless `CRM_BASE` is set) |
| A12 | Event Grid → subscriptions | `PermitCreated` → `analytics-audit` queue (managed-identity delivery); `resident-notification` webhook when configured |
| A13 | App Insights → Logs / Transaction search | Search the correlation ID: the intake request (APIM → Service Bus `201`) and the processing transaction (Function → AI gateway → content safety → model → Event Grid) |
| A14 | APIM failure paths | `400` (Logic App, missing fields) · `401` (Entra variant, bad token) · `429` (rate limit) · `403` (content safety blocks a prompt injection) |
| A15 | Service Bus → dead-letter | Poison message dead-lettered after retries — nothing lost |

> **A14 helper:** the deployed Permits API uses subscription keys
> ([permits-api.direct.xml](../apim/policies/permits-api.direct.xml)). To show
> `401`, apply the Entra variant
> ([permits-api.policy.xml](../apim/policies/permits-api.policy.xml)), mint a
> token with [scripts/get_token.sh](../scripts/get_token.sh), then tamper/drop
> the token. The `401` needs nothing else; for a `202` with a valid token, first
> register the `permit-intake-logicapp` backend (the Logic App trigger URL — see
> [apim/policies/README.md](../apim/policies/README.md)), which Bicep doesn't create. For `403`, send a prompt-injection prompt
> to `/openai/v1/responses`. **A5 follow-up:** the token metrics land in Application Insights —
> render them with
> [ai_gateway_extras/kql/token-monitoring.kql](../ai_gateway_extras/kql/token-monitoring.kql)
> and [chargeback.kql](../ai_gateway_extras/kql/chargeback.kql).

> **A2 presenter path:** in the API Center linked to APIM (Bicep creates the
> link), show the cataloged Permits, orchestrated Permits, and Azure OpenAI APIs. Open a definition or
> deployment to connect discovery and reuse in API Center to runtime governance
> in API Management. See the
> [API Center portal guide](api-center-portal.md) for the complete setup and
> presentation flow.

## Part B — Azure SDK for Python walkthrough

Run the whole thing offline: `uv run ais-demo`. Each step maps to a Demo Track
cell and a module in `src/ais_demo`:

| Step | Says | Code |
| --- | --- | --- |
| B1 | Submit through APIM (subscription key; Entra token when configured) | `integrations/apim_client.py` |
| B2 | Publish to Service Bus (durable) | `integrations/service_bus.py` |
| B3 | Extract fields (Document Intelligence, key-value pairs) | `integrations/document_intelligence.py` |
| B4 | Validate & score (AI gateway, Azure OpenAI v1 Responses API, structured output) | `integrations/ai_gateway.py` |
| B5 | Write to the case system (CRM adapter) | `integrations/crm.py` |
| B6 | Publish `PermitCreated` (Event Grid) | `integrations/event_grid.py` |
| B7 | Resilience — dead-letter poison msg | `integrations/service_bus.py` |
| B8 | Query end-to-end trace (Monitor) | `integrations/monitor.py` |

Against the live environment, [scripts/run_demo.sh](../scripts/run_demo.sh)
drives both front doors and the AI gateway and waits for the processed permit.

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
an APIM AI-gateway pattern (content safety, token limits, token metrics,
managed-identity backend auth, correlation ID). Before any production use, apply each project's
hardening guidance and an Azure Well-Architected review.
