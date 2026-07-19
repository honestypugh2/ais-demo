"""Per-user cost attribution via the APIM AI Gateway (FinOps).

Extends the Demo Track's AI-gateway governance (A5/B4) with chargeback/showback:
every model call carries a user identity (``x-user-id``); the gateway meters the
token usage per user, and this client builds a per-user cost record. The gateway
is authoritative — the app-side record here is illustrative.

Identity precedence in the companion policy: Entra ``oid`` › ``x-user-id`` ›
subscription id. Never trust ``x-user-id`` from a browser; only a trusted
server-side proxy should stamp it.

Run:
    uv run python ai_demo/per_user_cost_attribution.py
"""

from __future__ import annotations

import os

from dotenv import load_dotenv

# Adjust to your model's pricing for a realistic chargeback figure.
PRICE_PER_1K_TOKENS_USD = 0.0006

SAMPLE_USERS = [
    ("alice@example.com", "permitting"),
    ("bob@example.com", "planning"),
]

PROMPTS = [
    "Summarize the status of a building permit application.",
    "List the mandatory fields on a permit intake form.",
]


def _call(base: str, key: str, deployment: str, api_version: str, user_id: str, prompt: str):
    from openai import AzureOpenAI

    client = AzureOpenAI(
        azure_endpoint=base,
        api_key=key,
        api_version=api_version,
        default_headers={"x-user-id": user_id},  # attribution dimension (proxy-stamped)
    )
    resp = client.chat.completions.create(
        model=deployment,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0,
    )
    return resp.usage.total_tokens if resp.usage else 0


def main() -> None:
    load_dotenv()
    base = os.environ.get("AOAI_VIA_APIM_BASE")
    key = os.environ.get("APIM_SUBSCRIPTION_KEY")
    deployment = os.environ.get("AOAI_DEPLOYMENT", "gpt-4o-mini")
    api_version = os.environ.get("AOAI_API_VERSION", "2024-10-21")

    if not base or not key:
        print("Set AOAI_VIA_APIM_BASE and APIM_SUBSCRIPTION_KEY in .env first.")
        return

    print(f"{'user':<24}{'team':<14}{'tokens':>8}{'cost_usd':>12}")
    for (user_id, team), prompt in zip(SAMPLE_USERS, PROMPTS, strict=False):
        tokens = _call(base, key, deployment, api_version, user_id, prompt)
        cost = round(tokens / 1000.0 * PRICE_PER_1K_TOKENS_USD, 6)
        print(f"{user_id:<24}{team:<14}{tokens:>8}{cost:>12}")


if __name__ == "__main__":
    main()
