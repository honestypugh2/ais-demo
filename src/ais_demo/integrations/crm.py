"""CRM write (Demo Track step B5).

Persists the validated permit and its compliance score to a CRM (Dynamics 365
or an HTTP stub). In the deployed function this uses a managed identity — no
secret on the wire. In simulated mode records are kept in memory.
"""

from __future__ import annotations

import uuid

import httpx

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger
from ais_demo.schemas import ComplianceResult, ExtractedPermit

logger = get_logger(__name__)

_RECORDS: dict[str, dict] = {}


def create_permit_record(
    extracted: ExtractedPermit, compliance: ComplianceResult, correlation_id: str
) -> str:
    """Create a CRM permit record; return the new permit ID."""
    settings = get_settings()
    payload = {
        **extracted.model_dump(by_alias=True),
        "correlationId": correlation_id,
        "complianceScore": compliance.score,
        "status": "IntakeReview",
    }

    if settings.simulated_mode or not settings.crm_base:
        permit_id = f"P-{uuid.uuid4().hex[:8].upper()}"
        _RECORDS[permit_id] = payload
        logger.info("CRM permit created: %s (simulated)", permit_id)
        return permit_id

    resp = httpx.post(f"{settings.crm_base}/api/permits", json=payload, timeout=30)
    resp.raise_for_status()
    permit_id = resp.json().get("permitId", f"P-{uuid.uuid4().hex[:8].upper()}")
    logger.info("CRM permit created: %s", permit_id)
    return permit_id


def get_record(permit_id: str) -> dict | None:
    return _RECORDS.get(permit_id)


def reset_simulated_records() -> None:
    _RECORDS.clear()
