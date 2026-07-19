# `integration/` — low-code integration artifacts

Portable definitions for the **portal / low-code** side of the demo (Demo Track
Part A). These are reference copies of the workflow and eventing wiring; the
live resources are provisioned by [`infra/`](../infra/) and can also be authored
directly in the Azure Portal.

| File | Purpose |
| --- | --- |
| [`logicapp/permit-intake-workflow.json`](logicapp/permit-intake-workflow.json) | The **Logic App** workflow: an HTTP trigger that enqueues a permit onto the Service Bus `permits-in` queue using managed identity, then returns `202 Accepted`. This is the "APIM → Logic App → Service Bus" path (Demo Track **A6/A7**), surfaced in APIM at `/permits-orchestrated`. |
| [`eventgrid/subscriptions.json`](eventgrid/subscriptions.json) | Two **Event Grid** subscriptions to the `PermitCreated` event (Demo Track **A12**): a resident-notification webhook and an analytics/audit Service Bus sink — decoupled subscribers that react without the permit flow knowing who is listening. |

## How this maps to the deployed demo

```
POST /permits-orchestrated ─▶ APIM ─▶ Logic App (this workflow) ─▶ Service Bus ─▶ Function
PermitCreated ─▶ Event Grid ─▶ [ resident-notification | analytics-audit ]   (these subscriptions)
```

- The Logic App is deployed by [infra/modules/logicapp.bicep](../infra/modules/logicapp.bicep).
- The Event Grid topic is deployed by [infra/modules/eventgrid.bicep](../infra/modules/eventgrid.bicep); the subscriptions here are a portable reference.
- The alternative **direct** path (APIM enqueues to Service Bus with no Logic App) is `/permits` — see [apim/policies/permits-api.direct.xml](../apim/policies/permits-api.direct.xml).

Replace the `<...>` placeholders (endpoints, subscription/namespace IDs) before
importing into a live environment. See the
[deployment guide](../docs/deployment-guide.md) and the [root README](../README.md).
