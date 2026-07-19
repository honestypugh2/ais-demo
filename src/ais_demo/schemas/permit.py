"""Pydantic schemas for the permit-intake flow.

These models are intentionally generic. To adapt the demo to another intake
use case, change the field set here and the sample data under ``data/``.
"""

from __future__ import annotations

from datetime import UTC, datetime

from pydantic import BaseModel, Field


class PermitRequest(BaseModel):
    """Inbound request submitted through the governed API (APIM front door)."""

    name: str = Field(..., description="Applicant name")
    type: str = Field(..., description="Permit / request type, e.g. 'Building'")
    parcel: str | None = Field(default=None, description="Parcel / reference identifier")
    document_url: str | None = Field(
        default=None,
        alias="documentUrl",
        description="URL to the submitted packet (application form + attachments)",
    )

    model_config = {"populate_by_name": True}


class ExtractedPermit(BaseModel):
    """Structured fields extracted from the packet by Document Intelligence."""

    applicant_name: str | None = Field(default=None, alias="applicantName")
    service_address: str | None = Field(default=None, alias="serviceAddress")
    parcel_id: str | None = Field(default=None, alias="parcelId")
    service_type: str | None = Field(default=None, alias="serviceType")
    signature_present: bool = Field(default=False, alias="signaturePresent")

    model_config = {"populate_by_name": True}


class ComplianceResult(BaseModel):
    """Policy-compliance score returned by the AI validation step."""

    score: int = Field(..., ge=0, le=100, description="0-100 compliance score")
    missing: list[str] = Field(default_factory=list, description="Missing mandatory fields")
    flags: list[str] = Field(default_factory=list, description="Reviewer flags / warnings")
    tokens: int = Field(default=0, description="Model tokens consumed (for chargeback)")


class SubmitResponse(BaseModel):
    """Response returned by the API after accepting a submission (async 202)."""

    status: str = "accepted"
    correlation_id: str = Field(..., alias="correlationId")
    message: str = "Permit accepted for processing"

    model_config = {"populate_by_name": True}


class ProcessResult(BaseModel):
    """Terminal result of processing a permit end to end."""

    permit_id: str | None = Field(default=None, alias="permitId")
    correlation_id: str = Field(..., alias="correlationId")
    extracted: ExtractedPermit
    compliance: ComplianceResult
    status: str
    dead_lettered: bool = Field(default=False, alias="deadLettered")
    event_published: bool = Field(default=False, alias="eventPublished")

    model_config = {"populate_by_name": True}


class PermitEvent(BaseModel):
    """CloudEvents payload published to Event Grid on a permit lifecycle change."""

    permit_id: str = Field(..., alias="permitId")
    applicant_email: str | None = Field(default=None, alias="applicantEmail")
    compliance_score: int = Field(..., alias="complianceScore")
    correlation_id: str = Field(..., alias="correlationId")
    occurred_at: datetime = Field(default_factory=lambda: datetime.now(UTC))

    model_config = {"populate_by_name": True}
