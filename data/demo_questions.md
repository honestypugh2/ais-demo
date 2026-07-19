# Demo prompts & sample submissions

Synthetic inputs for rehearsing the permit-intake flow. All data is fictional.

## Valid submissions (happy path → 202 → IntakeReview)

| Applicant | Type | Parcel | Expected |
| --- | --- | --- | --- |
| Jordan Lee | Building | AIS-2026-00417 | High compliance score, event published |
| Sam Rivera | Electrical | AIS-2026-00521 | High compliance score, event published |
| Priya Chandra | Plumbing | AIS-2026-00622 | High compliance score, event published |

## Edge cases

| Scenario | Input | Expected |
| --- | --- | --- |
| Missing type (poison) | `{ "name": "No Type", "parcel": "AIS-2026-BAD" }` | Dead-lettered, not lost |
| Missing signature | valid packet, no signature | Lower compliance score, `NeedsAttention` |
| Invalid token (APIM) | expired bearer token | `401` at the gateway (Part A / A14) |
| Rate limit (APIM) | rapid repeated calls | `429` + `Retry-After` |

## Demo Track mapping

- Part A (Azure Portal): steps A1–A15
- Part B (Python SDK): steps B1–B8 — run `uv run ais-demo`
