# APIM Policies — AI Gateway & governed front door

These policies implement the governance shown in the demo (Demo Track Part A,
steps A4–A6, A14 and the AI-gateway steps A5 / B4).
[infra/modules/apim.bicep](../../infra/modules/apim.bicep) deploys
`aoai-api.policy.xml`, `permits-api.direct.xml`, and `permits-api.logicapp.xml`
together with the named values and the model and content-safety backends below.
[permits-api.policy.xml](permits-api.policy.xml) is the Entra-protected variant
(Demo Track A14); apply it to the Permits API when you have an app registration
and have registered the `permit-intake-logicapp` backend (Bicep doesn't create it).
Adjust limits and thresholds for your tenant.

| File | Applies to | Demonstrates |
| --- | --- | --- |
| [permits-api.policy.xml](permits-api.policy.xml) | `POST /permits` | Microsoft Entra token validation (`validate-azure-ad-token`), per-subscription rate limiting, correlation-ID stamping, backend routing |
| [permits-api.direct.xml](permits-api.direct.xml) | `POST /permits` (direct) | Managed-identity enqueue straight to Service Bus, parcel-based `MessageId` for duplicate detection; `202` only after Service Bus confirms (`503` otherwise) |
| [permits-api.logicapp.xml](permits-api.logicapp.xml) | `POST /permits-orchestrated` | Forward to the Logic App trigger (validate → enrich → Service Bus) |
| [aoai-api.policy.xml](aoai-api.policy.xml) | Azure OpenAI v1 API (`/openai/v1`) | `llm-content-safety` (Prompt Shields), `llm-token-limit` (TPM + monthly quota), `llm-emit-token-metric` (chargeback), managed-identity backend auth |

## Named values to create in APIM

| Named value | Example | Used by |
| --- | --- | --- |
| `tenant-id` | `<tenant-guid>` | `permits-api` Entra token validation |
| `servicebus-namespace` | `aisdemosb<suffix>` | `permits-api.direct` enqueue |
| `permits-queue` | `permits-in` | `permits-api.direct` enqueue |
| `logicapp-callback-url` | *(secret — the workflow trigger's callback URL)* | `permits-api.logicapp` |

## Backends to register

| Backend id | Target |
| --- | --- |
| `permit-intake-logicapp` | The Logic App workflow trigger URL — only for the Entra variant; not deployed by Bicep |
| `foundry-models-backend` | `https://<foundry>.openai.azure.com/openai` (Azure OpenAI v1 API; managed identity) |
| `content-safety-backend` | `https://<foundry>.cognitiveservices.azure.com` (managed identity, resource `https://cognitiveservices.azure.com`) |

## How the two surfaces compose

```
Consumer ──▶ APIM  ├─ Permits API  (/permits)               ──▶ Service Bus ──▶ Function
                   ├─ Permits API  (/permits-orchestrated)  ──▶ Logic App ──▶ Service Bus
                   └─ Azure OpenAI v1 (/openai/v1)          ──▶ Foundry model (compliance scoring)
```

The Function's compliance-scoring call (step B4) goes **back through** the APIM
Azure OpenAI v1 surface (`/openai/v1/responses`, APIM key in the `api-key`
header), so content safety, token limits, and token metrics apply to every model
call — not just interactive chat. The policy strips the caller's `api-key`
header and calls the model with the gateway's managed identity.

> These are demonstration policies. Before production, review authentication,
> rate limits, content safety, and networking per the Azure Well-Architected
> Framework.
