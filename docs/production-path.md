# Production path

This demo is a **proof of concept**: it favors clarity and speed (public
endpoints, simple SKUs, simulated fallbacks). This document is the reference for
taking the same architecture to **production** — what to add, why, and where it
maps in this repo — organized by the
[Azure Well-Architected Framework (WAF)](https://learn.microsoft.com/azure/well-architected/)
pillars and aligned to Microsoft reference architectures.

> [!IMPORTANT]
> Nothing here is a compliance claim. Treat this as a checklist to plan a
> production rollout with your security, platform, and data teams.

## Reference architectures (Microsoft guidance)

| Topic | Reference |
| --- | --- |
| API gateway + internal APIM + Functions | [Protect APIs with Application Gateway + API Management](https://learn.microsoft.com/azure/architecture/example-scenario/integration/app-gateway-internal-api-management-function#architecture) |
| APIM landing zone accelerator | [API Management landing zone accelerator](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/api-management/landing-zone-accelerator) |
| Generative AI gateway (token limits, metrics, safety) | [Use API Management with Azure OpenAI](https://learn.microsoft.com/azure/api-management/azure-openai-emit-token-metric-policy) · [GenAI gateway guidance](https://learn.microsoft.com/ai/playbook/technology-guidance/generative-ai/dev-starters/genai-gateway/) |
| Event-driven / messaging | [Event-driven architecture style](https://learn.microsoft.com/azure/architecture/guide/architecture-styles/event-driven) · [Asynchronous messaging options](https://learn.microsoft.com/azure/architecture/guide/technology-choices/messaging) |
| Serverless event processing | [Serverless event processing](https://learn.microsoft.com/azure/architecture/reference-architectures/serverless/event-processing) |
| AI evaluation (Microsoft Foundry) | [Azure OpenAI graders](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/azure-openai-graders) · [Custom evaluators](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/custom-evaluators) · [Evaluate hosted agent (quickstart)](https://learn.microsoft.com/azure/foundry/observability/quickstarts/quickstart-evaluate-hosted-agent) |
| Well-Architected for AI workloads | [WAF — AI workloads](https://learn.microsoft.com/azure/well-architected/ai/) |

## Demo vs. production — per-component deltas

| Component | Demo (this repo) | Production target |
| --- | --- | --- |
| **API Management** | Developer SKU, public | Premium/StandardV2, **internal VNet**, WAF (App Gateway/Front Door) in front, multi-region units |
| **Networking** | Public endpoints | **Private Endpoints** for all PaaS, VNet integration, Private DNS, `publicNetworkAccess=Disabled` |
| **Identity/secrets** | Managed identity + APIM subscription key in app settings | Managed identity **everywhere**; secrets as **Key Vault references**; no keys in settings |
| **Auth (Permits API)** | Subscription key (JWT policy provided) | **Entra ID JWT** (`validate-jwt`) with an app registration + audience |
| **Azure OpenAI** | GlobalStandard, public | Provisioned/Data Zone as needed, private, **content safety** + jailbreak shields |
| **Functions** | Flex Consumption, public storage | VNet-integrated, private storage, zone-redundant plan |
| **Service Bus / Event Grid** | Standard, public | Premium (Service Bus) for VNet + higher throughput; private endpoints; geo-DR |
| **State** | In-memory / simulated CRM | Real system of record with idempotency + outbox |

## Security

- **Network isolation** — Private Endpoints for APIM backend, Service Bus, Event
  Grid, Document Intelligence, Azure OpenAI, Storage, Key Vault; VNet integration
  for Functions and Logic Apps; WAF at the edge. See
  [docs/architecture.md#path-to-production-apim-landing-zone](architecture.md).
- **Identity** — user-assigned managed identity for the workload; least-privilege
  RBAC ([apim/policies/README.md](../apim/policies/README.md) and the deployment
  guide list the exact roles). No shared keys; disable local auth on Service Bus
  and Cognitive Services.
- **Secrets** — Key Vault with RBAC + Private Endpoint; reference secrets from
  Function/APIM settings; rotate on a schedule.
- **AI safety** — Azure AI Content Safety (prompt shields, harmful-content
  filters) on the model path; input validation and output guarding in the
  orchestrator.
- **Threat protection** — Defender for Cloud on all resource types; APIM
  rate-limit + quota; Front Door WAF managed rulesets.

## Reliability

- **Zone redundancy** — zone-redundant APIM units, Service Bus Premium, storage
  (ZRS), and a zone-redundant Functions plan.
- **Multi-region** — active/passive with Front Door and paired-region
  replication; Service Bus geo-DR; APIM multi-region gateways.
- **Resilience patterns** — already demonstrated: **dead-letter** on
  `permits-in`, retries via delivery count, correlation IDs. Add: idempotency
  keys on the CRM write, an **outbox** for the event publish, and circuit
  breakers on downstream calls.
- **Backup/DR** — documented RPO/RTO, restore runbooks, and periodic DR drills.

## Observability

Already wired in the demo: one **correlation ID** flows Portal → APIM → Logic App
→ Service Bus → Function → Event Grid into **Application Insights**, queryable as
a single end-to-end transaction (`GET /api/trace/{id}` / Demo Track B8).

For production, add:

- **Dashboards** — Azure Monitor workbooks for latency, error rate, dead-letter
  depth, and AI **token/cost per team** (from `azure-openai-emit-token-metric`).
- **Alerts** — action groups on: 5xx rate, APIM 429 spikes, dead-letter count > 0,
  Function failures, token-budget breaches, and availability tests.
- **SLO/SLI** — define availability + latency SLOs; track error budgets.
- **Tracing** — OpenTelemetry from the Function/orchestrator into Application
  Insights; end-to-end sampling policy.
- **Cost telemetry** — per-user/per-team FinOps via the AI gateway (see
  [ai_demo/per_user_cost_attribution.py](../ai_demo/per_user_cost_attribution.py)).

## Evaluation (AI quality)

The compliance scorer is a **direct Azure OpenAI call through APIM — not a Foundry
agent** — so evaluate it with **dataset-based** tooling that scores your own
`query` / `response` / `ground_truth` rows (no deployed agent required). See the
[observability & evaluation overview](https://learn.microsoft.com/azure/foundry/concepts/observability).

- **Offline evaluation (non-agent, dataset-based)** — export a labeled set of
  permit packets with expected scores/flags to JSONL, then score with:
  - [Azure OpenAI graders](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/azure-openai-graders):
    `score_model` (LLM judge with your rubric), plus deterministic `string_check`
    / `text_similarity` against the expected score/flags.
  - [Custom evaluators](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/custom-evaluators):
    code-based `grade()` for rule checks (score within tolerance, required flags
    present, output-format compliance) and prompt-based judges for subjective
    quality.
  Both run over inline/JSONL data via the Foundry SDK (`azure-ai-projects`) — no
  agent target.
- **Continuous evaluation** — sample production traffic, score with evaluators
  (relevance, groundedness, safety), and alert on drift. See
  [Monitor agents dashboard (continuous evaluation)](https://learn.microsoft.com/azure/foundry/observability/how-to/how-to-monitor-agents-dashboard).
- **Content safety & red-teaming** — run adversarial prompts before go-live with
  the [AI red teaming agent](https://learn.microsoft.com/azure/foundry/how-to/develop/run-ai-red-teaming-cloud) (Microsoft PyRIT).
- **Regression gates** — wire evals into CI so prompt/model changes are gated on
  a quality threshold. See
  [Run evaluations with GitHub Actions](https://learn.microsoft.com/azure/foundry/how-to/evaluation-github-action).

> If you later wrap the scorer as a Foundry **agent**, the
> [Evaluate your hosted agent](https://learn.microsoft.com/azure/foundry/observability/quickstarts/quickstart-evaluate-hosted-agent)
> quickstart and [Evaluate your AI agents](https://learn.microsoft.com/azure/foundry/observability/how-to/evaluate-agent)
> apply. With the Microsoft Agent Framework you can also score **pre-existing
> responses** through its `LocalEvaluator` without re-running an agent.

> Recommended addition to this repo: an `evals/` folder with a labeled JSONL
> dataset and a Foundry graders / custom-evaluator run (`azure-ai-projects`),
> wired into CI as a quality gate. Not included in the demo scope.

## CI/CD

A starter pipeline is provided at
[.github/workflows/ci.yml](../.github/workflows/ci.yml): it runs **ruff**,
**mypy**, **pytest**, a **Bicep build**, and the **frontend build** on every PR.

For continuous delivery, add:

- **Infra + app deploy** — `azd` in GitHub Actions using **OIDC federated
  credentials** (no stored secrets); `azd provision` + `azd deploy` per
  environment. See
  [Configure azd pipelines](https://learn.microsoft.com/azure/developer/azure-developer-cli/configure-devops-pipeline).
- **Environments & gates** — `dev` → `test` → `prod` with manual approval and
  `what-if`/preflight validation before apply.
- **Quality gates** — fail the pipeline on lint/type/test/eval regressions.
- **Supply chain** — dependency scanning (Dependabot), CodeQL, and signed
  artifacts.

## Cost optimization

- Right-size SKUs (APIM units, Functions plan, Service Bus tier) to load.
- Use the AI gateway **token limits + metrics** for per-team budgets and
  chargeback/showback.
- Consumption/Flex tiers for spiky workloads; reserved capacity for steady state.
- Alerts on cost anomalies; tag every resource for cost allocation.

## Operational excellence

- Everything as code: Bicep in [infra/](../infra/), pipelines in
  [.github/workflows/](../.github/workflows/).
- Runbooks for incident response, DR, and key rotation.
- Structured logging + correlation already in [src/ais_demo/core](../src/ais_demo/core/).
- Blameless postmortems and a change-management process.

## Production readiness checklist

- [ ] Private Endpoints + VNet integration for all PaaS; public access disabled
- [ ] WAF (Front Door/App Gateway) in front of internal APIM
- [ ] Entra ID JWT on the Permits API (app registration + audience)
- [ ] Managed identity everywhere; secrets in Key Vault; local auth disabled
- [ ] Azure AI Content Safety on the model path
- [ ] Zone redundancy + multi-region + geo-DR; RPO/RTO documented
- [ ] Idempotency + outbox on CRM write and event publish
- [ ] Dashboards, alerts, SLOs, OpenTelemetry tracing
- [ ] AI evaluation suite (offline + continuous) gated in CI
- [ ] CD pipeline (azd + OIDC) with dev/test/prod approvals
- [ ] Defender for Cloud, CodeQL, dependency scanning
- [ ] Cost alerts + resource tagging

See also: [architecture.md](architecture.md) · [deployment-guide.md](deployment-guide.md) · [demo-track.md](demo-track.md).
