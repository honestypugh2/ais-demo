# Deployment guide

Two ways to run this demo: **simulated** (no Azure, great for rehearsal) and
**live** (real Azure Integration Services via Bicep IaC).

## 1. Run locally in simulated mode (no Azure)

```bash
# Prereqs: Python 3.14+, uv (https://docs.astral.sh/uv/), Node.js 24 LTS
uv sync --extra dev
cp .env.example .env            # SIMULATED_MODE=true by default

# Part B walkthrough end to end (B1-B8)
uv run ais-demo

# Or run the API + portal
./scripts/run_local.sh          # API :8000, portal :5173
```

Quality gates:

```bash
uv run ruff check .
uv run mypy
uv run pytest
```

## 2. Provision Azure infrastructure (Bicep)

```bash
az login
az group create -n rg-ais-demo -l eastus2

# Preview, then deploy the whole stack.
az deployment group what-if -g rg-ais-demo \
  --template-file infra/main.bicep --parameters infra/main.bicepparam
az deployment group create -g rg-ais-demo \
  --template-file infra/main.bicep --parameters infra/main.bicepparam
```

[infra/main.bicep](../infra/main.bicep) deploys and wires everything — no
portal steps:

| Module | What it deploys |
| --- | --- |
| `monitoring` | Log Analytics + workspace-based Application Insights |
| `identity` | User-assigned managed identity for the Function App |
| `servicebus` | Namespace (local/SAS auth **disabled**) + `permits-in` and `permit-analytics` queues (dead-lettering, duplicate detection) |
| `eventgrid` | CloudEvents topic (local auth disabled) + `analytics-audit` subscription delivered with the topic's managed identity; optional `resident-notification` webhook (`notificationWebhookUrl`) |
| `documentintelligence` | Document Intelligence (v4.0 API, local auth disabled) |
| `foundry` | Microsoft Foundry resource (`AIServices`, local auth disabled) + `permit-intake` project + `gpt-5.4-mini` deployment; also the Content Safety backend |
| `logicapp` | Consumption workflow loaded from [integration/logicapp/permit-intake-workflow.json](../integration/logicapp/permit-intake-workflow.json) |
| `apim` | API Management: `aoai` (Azure OpenAI v1), `permits`, and `permits-orchestrated` APIs with the policies in [apim/policies](../apim/policies/); named values, backends (circuit breaker), the Function's `permit-processor` subscription, Application Insights logger (connection string + managed identity), custom metrics (`azure.ai_gateway.client.token.usage`), and gateway logs to Log Analytics |
| `apicenter` | API Center linked to API Management (API sources — preview API version) |
| `functionapp` | Flex Consumption, **Python 3.14**, all connections via managed identity, OpenTelemetry to Application Insights |
| `rbac` | Least-privilege data-plane roles for the Function identity |

Parameters worth knowing:

| Parameter | Default | Notes |
| --- | --- | --- |
| `apimSku` | `BasicV2` | `main.bicepparam` sets `Developer` for the existing demo environment. Classic and v2 tiers can't be switched in place. |
| `deployApim` | `true` | `false` skips API Management + API Center for a fast loop; compliance scoring then runs simulated. |
| `modelName` / `modelVersion` | `gpt-5.4-mini` / `2026-03-17` | GA; see the [model retirement schedule](https://learn.microsoft.com/azure/foundry/openai/concepts/model-retirement-schedule). |
| `notificationWebhookUrl` | *(empty)* | Endpoint must answer the Event Grid validation handshake. |

### Upgrading an environment deployed from an earlier version of this repo

- The Azure OpenAI account keeps its name and is **upgraded in place** to a
  Foundry resource (`kind: AIServices`, `allowProjectManagement: true`) —
  endpoint and deployments are preserved. See
  [Upgrade from Azure OpenAI to Foundry](https://learn.microsoft.com/azure/foundry/how-to/upgrade-azure-openai).
- Role assignments are now declared in Bicep with deterministic names. Role
  assignments created by hand for the same identity, role, and scope make the
  deployment fail with `RoleAssignmentExists`. In the original demo environment
  these are: APIM's identity (`Cognitive Services OpenAI User` on the model
  account, `Azure Service Bus Data Sender`), the Logic App's identity
  (`Azure Service Bus Data Sender`), the Function's identity
  (`Azure Service Bus Data Receiver`, `Cognitive Services User` on Document
  Intelligence, `EventGrid Data Sender`), and API Center's identity
  (`API Management Service Reader Role`). Remove them once before the first
  Bicep deployment, for example:

  ```bash
  az role assignment list -g rg-ais-demo --query "[].{id:id,role:roleDefinitionName,principal:principalId}" -o table
  az role assignment delete --ids <id> [<id> ...]
  ```

- Local auth is disabled on Service Bus, Event Grid, Document Intelligence, and
  the Foundry resource. Anything still using keys or SAS connection strings
  must switch to Microsoft Entra ID.

### Or use azd

```bash
azd auth login
azd env new ais-demo
azd env set AZURE_LOCATION eastus2
azd env set AZURE_RESOURCE_GROUP rg-ais-demo
azd provision --preview   # what-if
azd provision
```

The [deploy workflow](../.github/workflows/deploy.yml) runs the same two steps
from GitHub Actions with OpenID Connect (no stored secrets) and an environment
approval gate.

## 3. Publish the application code

1. **Function App** — publish the Service Bus-triggered processor (Python 3.14):
   ```bash
   cd functionapp
   ./scripts/publish_function.sh <your-func-name>
   ```
   The script stages `functionapp/` with a copy of `src/ais_demo` and pinned
   requirements from `uv.lock`, then runs `func azure functionapp publish
   --build remote`. Use Azure Functions Core Tools 4.15 or later — earlier
   versions reject remote builds for Python 3.14 on Flex Consumption.
2. **API Center portal** — optional; configure and present the developer
   catalog with the [API Center portal guide](api-center-portal.md).

Everything else (Logic App workflow, APIM APIs and policies, Event Grid
subscriptions, role assignments) is deployed by Bicep.

## 4. Switch from simulated to live

Set in `.env` (or Function App settings, which Bicep already populates):

```
SIMULATED_MODE=false
AOAI_VIA_APIM_BASE=https://<your-apim>.azure-api.net/openai   # the client appends /v1/
AOAI_DEPLOYMENT=gpt-5.4-mini
APIM_SUBSCRIPTION_KEY=<key from an APIM subscription scoped to the aoai API>
```

Also provide the endpoints for Service Bus, Document Intelligence, Event Grid,
CRM, and Log Analytics. The app uses `DefaultAzureCredential` for Service Bus,
Document Intelligence, Event Grid, and Azure Monitor — local runs need your own
account to hold the matching data-plane roles (for example `Azure Service Bus
Data Sender`/`Receiver`, `Cognitive Services User`, `EventGrid Data Sender`,
`Log Analytics Reader`). Set `APPLICATIONINSIGHTS_CONNECTION_STRING` to export
the FastAPI host's traces and logs with OpenTelemetry.

## 5. Production hardening (before any real use)

This is a **demonstration** template. Before production, apply the Azure
Well-Architected Framework:

- Private Endpoints / VNet integration; disable public network access
- Managed identity everywhere (the APIM subscription key in the Function's app
  settings is the remaining secret — move it to Key Vault or switch the Function
  to Entra auth against the gateway)
- Key Vault for any remaining secrets
- Zone redundancy + multi-region failover
- Content safety + input validation hardening
- Production monitoring, alerting, and incident response

> Full details — security, reliability, observability, evaluation, and CI/CD,
> mapped to WAF pillars and Microsoft reference architectures — are in
> [production-path.md](production-path.md).

## 6. Clean up

Delete the resource group when you're done:

```bash
az group delete -n rg-ais-demo --yes --no-wait
```

API Management and the Foundry / Document Intelligence accounts are
soft-deleted for 48 hours. To redeploy with the same names sooner, purge them:

```bash
az apim deletedservice purge --service-name <apim-name> --location eastus2
az cognitiveservices account purge -n <account-name> -g rg-ais-demo -l eastus2
```
