"""Cost/latency-aware model routing at the AI Gateway (Demo Track extension).

Demonstrates routing each request to a "cheap" or "capable" model deployment
based on a simple heuristic (prompt length / task hint), then logs the decision.
In production the routing can live in an APIM policy (backend selection) so the
choice is governed and observable; here it is shown client-side for clarity.

Run:
    uv run python ai_gateway_extras/model_router_decisions.py
"""

import os

from dotenv import load_dotenv

from ais_demo.integrations.ai_gateway import gateway_client

# Two deployment names fronted by the same APIM gateway.
CHEAP_MODEL = os.environ.get("AOAI_DEPLOYMENT", "gpt-5.4-mini")
CAPABLE_MODEL = os.environ.get("AOAI_DEPLOYMENT_CAPABLE", CHEAP_MODEL)

COMPLEX_HINTS = ("analyze", "compare", "reason", "policy", "compliance", "justify")


def choose_model(prompt: str) -> tuple[str, str]:
    """Return (deployment, reason) for the given prompt."""
    lowered = prompt.lower()
    if len(prompt) > 400 or any(h in lowered for h in COMPLEX_HINTS):
        return CAPABLE_MODEL, "complex task -> capable model"
    return CHEAP_MODEL, "simple task -> cheap model"


def main() -> None:
    load_dotenv()
    base = os.environ.get("AOAI_VIA_APIM_BASE")
    key = os.environ.get("APIM_SUBSCRIPTION_KEY")

    prompts = [
        "What is a permit?",
        "Analyze this permit application for policy compliance and justify the score.",
    ]

    for prompt in prompts:
        model, reason = choose_model(prompt)
        print(f"[route] {reason:<34} model={model}")
        if not base or not key:
            continue
        client = gateway_client(base, key)
        resp = client.responses.create(
            model=model,
            input=prompt,
            reasoning={"effort": "low"},
            store=False,
        )
        tokens = resp.usage.total_tokens if resp.usage else 0
        print(f"         tokens={tokens}")


if __name__ == "__main__":
    main()
