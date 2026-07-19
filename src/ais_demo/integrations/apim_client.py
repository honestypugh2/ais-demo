"""API Management client (Demo Track step B1).

Submits a permit packet through the governed APIM front door with an Entra
bearer token and a subscription key. Returns the HTTP status and the
correlation ID stamped by the APIM policy.
"""

from __future__ import annotations

import httpx

from ais_demo.config import get_settings
from ais_demo.core.correlation import CORRELATION_HEADER, new_correlation_id
from ais_demo.core.logging import get_logger

logger = get_logger(__name__)


def acquire_token(settings) -> str:
    """Acquire an Entra access token for the consumer client (app-only)."""
    from azure.identity import ClientSecretCredential

    credential = ClientSecretCredential(
        tenant_id=settings.tenant_id,
        client_id=settings.client_id,
        client_secret=settings.client_secret,
    )
    return credential.get_token(settings.api_scope).token


def submit_permit(permit: dict) -> tuple[int, str]:
    """Submit a permit through APIM; return ``(status_code, correlation_id)``."""
    settings = get_settings()

    if settings.simulated_mode or not settings.apim_base:
        correlation_id = new_correlation_id()
        logger.info("Submitted permit through APIM (simulated) -> 202 %s", correlation_id)
        return 202, correlation_id

    token = acquire_token(settings)
    url = f"{settings.apim_base}{settings.permits_api_path}"
    resp = httpx.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Ocp-Apim-Subscription-Key": settings.apim_subscription_key,
            "Content-Type": "application/json",
        },
        json=permit,
        timeout=30,
    )
    correlation_id = resp.headers.get(CORRELATION_HEADER, "")
    logger.info("Submitted permit through APIM -> %s %s", resp.status_code, correlation_id)
    return resp.status_code, correlation_id
