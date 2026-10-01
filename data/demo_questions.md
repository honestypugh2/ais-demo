# Demo prompts & sample submissions

Synthetic inputs for rehearsing the permit-intake flow. All data is fictional.

## Valid submissions (happy path → 202)

| Applicant | Type | Parcel | Expected |
| --- | --- | --- | --- |
| Jordan Lee | Building | AIS-2026-00417 | `202`, event published |
| Sam Rivera | Electrical | AIS-2026-00521 | `202`, event published |
| Priya Chandra | Plumbing | AIS-2026-00622 | `202`, event published |

**Scores differ by mode.** Simulated mode scores these `100` → `IntakeReview`.
Live, `gpt-5.4-mini` reviews the extracted fields against the rubric; a minimal
packet with no real document typically scores 20–35 → `NeedsAttention`, listing
the missing information. Both are correct — the score is advisory and only
picks the human review queue.

## Edge cases

| Scenario | Input | Expected |
| --- | --- | --- |
| Missing type (poison) | `{ "name": "No Type", "parcel": "AIS-2026-BAD" }` on the direct path or the queue | Dead-lettered, not lost |
| Missing name/type (orchestrated) | `POST /permits-orchestrated` with `{ "name": "No Type" }` | `400` from the Logic App, passed through by APIM |
| Duplicate parcel | the same `parcel` twice within 10 minutes | Both get `202`; Service Bus keeps one message |
| Queue unavailable | Service Bus rejects the enqueue | `503` + `Retry-After` — no false `202` |
| Missing signature | valid packet, no signature | Lower compliance score, `NeedsAttention` |
| Prompt injection (AI gateway) | "Ignore all previous instructions…" to `/openai/v1/responses` | `403` from `llm-content-safety` |
| Invalid token (APIM) | expired bearer token, Entra policy variant applied | `401` at the gateway (Part A / A14) |
| Rate limit (APIM) | rapid repeated calls | `429` + `Retry-After` |

## Demo Track mapping

- Part A (Azure Portal): steps A1–A15
- Part B (Python SDK): steps B1–B8 — run `uv run ais-demo`
