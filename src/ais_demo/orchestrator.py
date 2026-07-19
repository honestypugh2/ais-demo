"""Permit processing orchestrator (the Function / AI-agent core).

This is the logic the Service Bus-triggered Function runs for each message:
extract fields -> score compliance -> write to CRM -> publish an event. It is
framework-agnostic so it can be hosted by the FastAPI API, the Azure Functions
host, or invoked directly from the Python SDK walkthrough.
"""

from __future__ import annotations

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger
from ais_demo.integrations import ai_gateway, crm, document_intelligence, event_grid
from ais_demo.schemas import PermitEvent, ProcessResult

logger = get_logger(__name__)


def process_permit(permit: dict, correlation_id: str) -> ProcessResult:
    """Run the full extraction -> validation -> CRM -> event pipeline."""
    settings = get_settings()

    # 1) Extract fields from the packet (Document Intelligence).
    extracted = document_intelligence.extract_fields(permit)

    # 2) Score policy compliance (AOAI via the APIM AI gateway).
    compliance = ai_gateway.score_compliance(extracted)
    logger.info("compliance score=%s missing=%s", compliance.score, compliance.missing)

    # 3) Write the validated permit to CRM.
    permit_id = crm.create_permit_record(extracted, compliance, correlation_id)

    # 4) Publish a PermitCreated event (Event Grid fan-out).
    event = PermitEvent(
        permitId=permit_id,
        applicantEmail=permit.get("applicantEmail"),
        complianceScore=compliance.score,
        correlationId=correlation_id,
    )
    event_published = event_grid.publish_permit_created(event)

    status = (
        "IntakeReview"
        if compliance.score >= settings.compliance_threshold
        else "NeedsAttention"
    )
    return ProcessResult(
        permitId=permit_id,
        correlationId=correlation_id,
        extracted=extracted,
        compliance=compliance,
        status=status,
        deadLettered=False,
        eventPublished=event_published,
    )
