"""Baseline governed model call through the APIM AI Gateway (Demo Track A5/B4).

Sends a request to the model *fronted by APIM* over the Azure OpenAI v1 API, so
the gateway's ``llm-token-limit``, ``llm-emit-token-metric``, and
``llm-content-safety`` policies apply to the call. Prints the token usage the
gateway metered.

Run:
    uv run python ai_gateway_extras/ai_gateway_call.py
"""

import os

from dotenv import load_dotenv

from ais_demo.integrations.ai_gateway import gateway_client


def main() -> None:
    load_dotenv()
    base = os.environ.get("AOAI_VIA_APIM_BASE")
    key = os.environ.get("APIM_SUBSCRIPTION_KEY")
    deployment = os.environ.get("AOAI_DEPLOYMENT", "gpt-5.4-mini")

    if not base or not key:
        print("Set AOAI_VIA_APIM_BASE and APIM_SUBSCRIPTION_KEY in .env first.")
        return

    client = gateway_client(base, key)
    resp = client.responses.create(
        model=deployment,
        instructions="You are a concise assistant.",
        input="In one sentence, what is an API gateway?",
        reasoning={"effort": "low"},
        store=False,
    )
    print("answer:", resp.output_text)
    print("tokens:", resp.usage.total_tokens if resp.usage else "n/a")


if __name__ == "__main__":
    main()
