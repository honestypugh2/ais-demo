# Deployment guide

Two ways to run this demo: **simulated** (no Azure, great for rehearsal) and
**live** (real Azure Integration Services via Bicep IaC).

## 1. Run locally in simulated mode (no Azure)

```bash
# Prereqs: Python 3.11+, uv (https://docs.astral.sh/uv/), Node 20+
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
az group create -n rg-ais-demo -l eastus

# Deploy the AIS stack (monitoring, identity, Service Bus, Event Grid,
# Document Intelligence, Azure OpenAI, Function App, API Management).
az deployment group create \
  -g rg-ais-demo \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

For a fast loop without APIM (saves several minutes):

```bash
az deployment group create -g rg-ais-demo \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam deployApim=false
```

### Or use azd

```bash
azd auth login
azd up
```

## 3. Configure & deploy the components

1. **Function App** — publish the Service Bus-triggered processor:
   ```bash
   cd functionapp
   func azure functionapp publish <your-func-name>
   ```
2. **Logic App** — import `integration/logicapp/permit-intake-workflow.json`
   and wire the Service Bus connection to the `permits-in` queue.
3. **API Management** — import the Permits API and the Azure OpenAI API, then
   apply the policies in `apim/policies/` (create the named values + backends
   listed in `apim/policies/README.md`).
4. **Event Grid** — create the subscriptions in
   `integration/eventgrid/subscriptions.json`.
5. **RBAC** — grant the Function's managed identity:
   - `Azure Service Bus Data Receiver` on the namespace
   - `Cognitive Services User` on Document Intelligence
   - `EventGrid Data Sender` on the topic
   Grant APIM's identity `Cognitive Services OpenAI User` on Azure OpenAI.

## 4. Switch from simulated to live

Set in `.env` (or Function App settings):

```
SIMULATED_MODE=false
```

Provide the endpoints/keys for APIM, Service Bus, Document Intelligence, Azure
OpenAI (via APIM), Event Grid, CRM, and Log Analytics. The app uses
`DefaultAzureCredential` (managed identity) for Service Bus, Document
Intelligence, Event Grid, and Monitor.

## 5. Production hardening (before any real use)

This is a **demonstration** template. Before production, apply the Azure
Well-Architected Framework:

- Private Endpoints / VNet integration; disable public network access
- Managed identity everywhere (no keys in settings)
- Key Vault for any remaining secrets
- Zone redundancy + multi-region failover
- Content safety + input validation hardening
- Production monitoring, alerting, and incident response

> Full details — security, reliability, observability, evaluation, and CI/CD,
> mapped to WAF pillars and Microsoft reference architectures — are in
> [production-path.md](production-path.md).
