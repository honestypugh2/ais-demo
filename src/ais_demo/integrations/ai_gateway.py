"""AI-gateway compliance scoring (Demo Track step B4).

Runs the extracted fields past a language model to produce a 0-100 policy
compliance score. The model is fronted by API Management (the AI gateway), so
the ``llm-token-limit``, ``llm-emit-token-metric``, and ``llm-content-safety``
policies apply to every call.

Live mode uses the Azure OpenAI **v1 API** (``/openai/v1``) through the gateway
with the standard ``OpenAI`` client — no dated ``api-version`` — and the
Responses API with structured output, so the score always parses into the same
schema.
"""

from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger
from ais_demo.schemas import ComplianceResult, ExtractedPermit

if TYPE_CHECKING:
    from openai import OpenAI

    from ais_demo.config.settings import Settings

logger = get_logger(__name__)

RUBRIC = (
    "You review permit intake packets. Score the application 0-100 for "
    "completeness, internal consistency, and policy compliance. List any missing "
    "mandatory fields and any reviewer flags. You only advise a human reviewer; "
    "never approve or deny."
)


class _Review(BaseModel):
    """Structured-output contract for the model's review."""

    score: int = Field(ge=0, le=100)
    missing: list[str]
    flags: list[str]


def gateway_client(
    base: str, subscription_key: str, headers: dict[str, str] | None = None
) -> OpenAI:
    """Return an ``OpenAI`` client for the APIM-fronted Azure OpenAI v1 API.

    ``base`` is the APIM API base (for example ``https://<apim>.azure-api.net/openai``).
    APIM validates the subscription key from the ``api-key`` header. The OpenAI
    client also sends it as a bearer token; the gateway replaces that header with
    its managed-identity token before calling the model, so the key never
    reaches the backend.
    """
    from openai import OpenAI

    return OpenAI(
        base_url=f"{base.rstrip('/')}/v1/",
        api_key=subscription_key,
        default_headers={"api-key": subscription_key, **(headers or {})},
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


def _score_live(extracted: ExtractedPermit, settings: Settings) -> ComplianceResult:
    logger.info("Compliance scoring via APIM AI gateway (%s)", settings.aoai_deployment)
    client = gateway_client(
        settings.aoai_via_apim_base,
        settings.apim_subscription_key,
        headers={"x-dept": "permitting"},  # attribution dimension for chargeback
    )
    resp = client.responses.parse(
        model=settings.aoai_deployment,
        instructions=RUBRIC,
        input=extracted.model_dump_json(by_alias=True),
        text_format=_Review,
        reasoning={"effort": settings.aoai_reasoning_effort},
        max_output_tokens=settings.aoai_max_output_tokens,
        store=False,
    )
    review = resp.output_parsed
    if review is None:
        raise ValueError("model returned no structured review")
    return ComplianceResult(
        score=review.score,
        missing=review.missing,
        flags=review.flags,
        tokens=resp.usage.total_tokens if resp.usage else 0,
    )
