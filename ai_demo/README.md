# AI Gateway feature demos (`ai_demo/`)

Optional, self-contained add-ons that extend the Demo Track's AI-gateway story
(steps **A5 / B4** — token limits + token metrics) with FinOps and routing
patterns. Every model call flows through **APIM as the AI Gateway**, which is the
single hop that sees both *who* called and *how many tokens* it cost.

All scripts are generic (no customer specifics) and read the same environment
variables as the main demo (see `.env.example`):

| Variable | Purpose |
| --- | --- |
| `AOAI_VIA_APIM_BASE` | APIM gateway base for the model API (e.g. `https://<apim>.azure-api.net/openai`) |
| `APIM_SUBSCRIPTION_KEY` | APIM subscription key (per-consumer) |
| `AOAI_DEPLOYMENT` | Chat model deployment name (`gpt-4o-mini`) |
| `AOAI_API_VERSION` | Azure OpenAI API version |

## Scripts

| File | What it demonstrates |
| --- | --- |
| `ai_gateway_call.py` | Baseline governed model call through APIM; prints token usage returned by the gateway. |
| `per_user_cost_attribution.py` | FinOps: passes user identity (`x-user-id`), reads per-request token usage, builds a per-user cost/chargeback record. |
| `model_router_decisions.py` | Cost/latency-aware model routing: pick a cheap vs. capable deployment per request and log the decision. |
| `mcp_tools_gateway.py` | Calls an MCP tool surface governed by the same APIM gateway (rate-limit + auth). |
| `apim/per-user-cost-attribution.policy.xml` | Illustrative gateway policy: resolve identity (Entra `oid` › `x-user-id` › subscription), per-user token limit, emit per-user token metric. |

## Run

```bash
uv run python ai_demo/ai_gateway_call.py
uv run python ai_demo/per_user_cost_attribution.py
uv run python ai_demo/model_router_decisions.py
```

> **Security:** never trust `x-user-id` straight from a browser — it is only safe
> when stamped by a trusted server-side proxy after session validation. For
> tamper-proof attribution use the Entra JWT (`oid`) path in the policy.

