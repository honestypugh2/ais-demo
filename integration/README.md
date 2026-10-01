# `integration/` — low-code integration artifacts

Definitions for the **portal / low-code** side of the demo (Demo Track Part A).
The Logic App workflow here is the **single source of truth**: Bicep loads it
verbatim, so the artifact and the deployed workflow can't drift.

| File | Purpose |
| --- | --- |
| [`logicapp/permit-intake-workflow.json`](logicapp/permit-intake-workflow.json) | The **Logic App (Consumption)** workflow: HTTP trigger → validate (`400` when `name`/`type` is missing) → enrich (correlation ID, received time) → enqueue onto `permits-in` with the Logic App's managed identity (`MessageId` = parcel for duplicate detection, `CorrelationId` = `X-Correlation-Id`) → `202 Accepted`. This is the "APIM → Logic App → Service Bus" path (Demo Track **A6/A7**), surfaced in APIM at `/permits-orchestrated`. |
| [`eventgrid/subscriptions.json`](eventgrid/subscriptions.json) | Portable reference for the two **Event Grid** subscriptions to `PermitCreated` (Demo Track **A12**): a resident-notification webhook and an analytics/audit Service Bus sink delivered with the topic's managed identity. Both are deployed by [infra/modules/eventgrid.bicep](../infra/modules/eventgrid.bicep) (the webhook only when `notificationWebhookUrl` is set). |

## How this maps to the deployed demo

```
POST /permits-orchestrated ─▶ APIM ─▶ Logic App (this workflow) ─▶ Service Bus ─▶ Function
PermitCreated ─▶ Event Grid ─▶ [ resident-notification | analytics-audit ]   (these subscriptions)
```

- The Logic App is deployed by [infra/modules/logicapp.bicep](../infra/modules/logicapp.bicep), which loads this workflow JSON and passes the `serviceBusNamespace` and `permitsQueue` parameters.
- The Event Grid topic and subscriptions are deployed by [infra/modules/eventgrid.bicep](../infra/modules/eventgrid.bicep).
- The alternative **direct** path (APIM enqueues to Service Bus with no Logic App) is `/permits` — see [apim/policies/permits-api.direct.xml](../apim/policies/permits-api.direct.xml).

The Consumption tier keeps the workflow fully declarative in Bicep and costs
nothing when idle. To move to Logic Apps Standard, reuse the same actions with
the built-in Service Bus connector. See the
[deployment guide](../docs/deployment-guide.md) and the [root README](../README.md).
