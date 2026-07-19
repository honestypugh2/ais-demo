# APIM Policies — AI Gateway & governed front door

These policies implement the governance shown in the demo (Demo Track Part A,
steps A4–A6, A14 and the AI-gateway steps A5 / B4). They are **samples** —
adjust named values, audiences, issuers, and limits for your tenant.

| File | Applies to | Demonstrates |
| --- | --- | --- |
| [permits-api.policy.xml](permits-api.policy.xml) | `POST /permits` | JWT validation (Entra), per-subscription rate limiting, correlation-ID stamping, backend routing |
| [aoai-api.policy.xml](aoai-api.policy.xml) | Azure OpenAI API | Token limit, token metrics (chargeback), managed-identity backend auth |

## Named values to create in APIM

| Named value | Example | Used by |
| --- | --- | --- |
| `tenant-id` | `<tenant-guid>` | `permits-api` JWT validation |

## Backends to register

| Backend id | Target |
| --- | --- |
| `permit-intake-logicapp` | The Logic App workflow trigger URL |
| `azure-openai-backend` | Your Azure OpenAI endpoint |

## How the two surfaces compose

```
Consumer ──▶ APIM  ├─ Permits API  (/permits)  ──▶ Logic App ──▶ Service Bus ──▶ Function
                   └─ Azure OpenAI (/openai)   ──▶ Azure OpenAI (compliance model)
```

The Function's compliance-scoring call (step B4) goes **back through** the APIM
Azure OpenAI surface, so token limits and token metrics apply to every model
call — not just interactive chat.

> These are demonstration policies. Before production, review authentication,
> rate limits, content safety, and networking per the Azure Well-Architected
> Framework.
