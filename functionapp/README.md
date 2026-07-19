# `functionapp/` — Azure Functions host (permit processor)

The event-driven **processor** that does the work once a permit is submitted. It
is a thin host that reuses the shared orchestrator in
[`src/ais_demo`](../src/ais_demo/) — the Function owns the trigger and wiring, the
package owns the logic.

## What it does

A single function, **`ProcessPermit`**, is triggered by each message on the
Service Bus `permits-in` queue and runs the pipeline (Demo Track **A8–A12 / B2–B6**):

```
Service Bus (permits-in) ─▶ ProcessPermit
   └─ extract (Document Intelligence) ─▶ score (AI gateway / Azure OpenAI)
       ─▶ record (CRM) ─▶ publish (PermitCreated → Event Grid)
```

The correlation ID travels in the message and flows through every hop into
Application Insights. Malformed or repeatedly failing messages are
**dead-lettered** by the runtime after the max delivery count (Demo Track A10).

## Files

| File | Purpose |
| --- | --- |
| [`function_app.py`](function_app.py) | The `ProcessPermit` Service Bus trigger; delegates to `ais_demo.orchestrator.process_permit`. |
| [`host.json`](host.json) | Functions host config (extension bundle for the Service Bus binding). |
| [`requirements.txt`](requirements.txt) | Runtime dependencies for the deployed function (installed by remote build). |
| [`local.settings.json.example`](local.settings.json.example) | Sample local settings — copy to `local.settings.json` for local runs. |

## Configuration (app settings)

| Setting | Purpose |
| --- | --- |
| `ServiceBusConnection` | Service Bus trigger connection (managed identity in the deployed flow). |
| `SERVICEBUS_FQDN` | Namespace FQDN for outbound sends. |
| `DOCINTEL_ENDPOINT` | Document Intelligence endpoint. |
| `EVENTGRID_ENDPOINT` | Event Grid topic endpoint. |
| `AOAI_VIA_APIM_BASE` / `APIM_SUBSCRIPTION_KEY` | Compliance scoring via the APIM AI gateway. |
| `AZURE_CLIENT_ID` | User-assigned managed identity client ID. |
| `SIMULATED_MODE` | `false` in Azure; adapters fall back to simulated when endpoints are unset. |

## Deploy

The Function App (Flex Consumption) is provisioned by
[infra/modules/functionapp.bicep](../infra/modules/functionapp.bicep). Publish the
code with a bundled copy of the `ais_demo` package:

```bash
func azure functionapp publish <function-app-name> --python --build remote
```

See the [deployment guide](../docs/deployment-guide.md) for the full RBAC +
publish steps, and the [root README](../README.md) for the end-to-end story.
