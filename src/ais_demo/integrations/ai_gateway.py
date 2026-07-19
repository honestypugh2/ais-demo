"""AI-gateway compliance scoring (Demo Track step B4).

Runs the extracted fields past a language model to produce a 0-100 policy
compliance score. The model is fronted by API Management (the AI gateway), so
token limits and per-consumer token metrics apply — the same pattern as the
``wordpress-chatbot`` accelerator.
"""

from __future__ import annotations

import json

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger
from ais_demo.schemas import ComplianceResult, ExtractedPermit

logger = get_logger(__name__)

RUBRIC = (
    "Score this permit application 0-100 for completeness, consistency, and "
    "policy compliance. Return JSON: {score, missing[], flags[]}."
)


def score_compliance(extracted: ExtractedPermit) -> ComplianceResult:
    """Return a compliance score for the extracted permit fields."""
    settings = get_settings()
    if settings.simulated_mode or not settings.aoai_via_apim_base:
        return _score_simulated(extracted)
    return _score_live(extracted, settings)


def _score_simulated(extracted: ExtractedPermit) -> ComplianceResult:
    logger.info("Compliance scoring (simulated)")
    missing: list[str] = []
    if not extracted.applicant_name:
        missing.append("applicantName")
    if not extracted.service_address:
        missing.append("serviceAddress")
    if not extracted.signature_present:
        missing.append("signature")

    score = max(0, 100 - len(missing) * 25)
    flags = [] if score >= 90 else ["verify parcel against recorded plat"]
    return ComplianceResult(score=score, missing=missing, flags=flags, tokens=0)


def _score_live(extracted: ExtractedPermit, settings) -> ComplianceResult:
    from openai import AzureOpenAI

    logger.info("Compliance scoring via APIM AI gateway (%s)", settings.aoai_deployment)
    client = AzureOpenAI(
        azure_endpoint=settings.aoai_via_apim_base,  # APIM gateway, not the raw AOAI endpoint
        api_version=settings.aoai_api_version,
        api_key=settings.apim_subscription_key,  # APIM subscription key
        default_headers={"x-dept": "permitting"},  # attribution dimension for chargeback
    )
    resp = client.chat.completions.create(
        model=settings.aoai_deployment,
        messages=[
            {"role": "system", "content": RUBRIC},
            {"role": "user", "content": extracted.model_dump_json(by_alias=True)},
        ],
        temperature=0.0,
        response_format={"type": "json_object"},
    )
    review = json.loads(resp.choices[0].message.content or "{}")
    return ComplianceResult(
        score=int(review.get("score", 0)),
        missing=review.get("missing", []),
        flags=review.get("flags", []),
        tokens=resp.usage.total_tokens if resp.usage else 0,
    )
