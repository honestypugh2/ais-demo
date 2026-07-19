"""Baseline governed model call through the APIM AI Gateway (Demo Track A5/B4).

Sends a chat completion to the model *fronted by APIM*, so the gateway's
``azure-openai-token-limit`` and ``azure-openai-emit-token-metric`` policies apply
to the call. Prints the token usage the gateway metered.

Run:
    uv run python ai_demo/ai_gateway_call.py
"""

from __future__ import annotations

import os

from dotenv import load_dotenv


def main() -> None:
    load_dotenv()
    base = os.environ.get("AOAI_VIA_APIM_BASE")
    key = os.environ.get("APIM_SUBSCRIPTION_KEY")
    deployment = os.environ.get("AOAI_DEPLOYMENT", "gpt-4o-mini")
    api_version = os.environ.get("AOAI_API_VERSION", "2024-10-21")

    if not base or not key:
        print("Set AOAI_VIA_APIM_BASE and APIM_SUBSCRIPTION_KEY in .env first.")
        return

    from openai import AzureOpenAI

    client = AzureOpenAI(azure_endpoint=base, api_key=key, api_version=api_version)
    resp = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "You are a concise assistant."},
            {"role": "user", "content": "In one sentence, what is an API gateway?"},
        ],
        temperature=0.0,
    )
    print("answer:", resp.choices[0].message.content)
    print("tokens:", resp.usage.total_tokens if resp.usage else "n/a")


if __name__ == "__main__":
    main()
