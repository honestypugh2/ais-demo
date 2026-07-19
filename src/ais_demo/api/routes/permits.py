"""Permit submission + processing endpoints.

This router represents the backend that API Management fronts. It accepts a
submission asynchronously (202 + correlation ID), enqueues it to Service Bus,
and exposes an endpoint to drain the queue through the processing orchestrator
(what the Service Bus-triggered Function does in the deployed flow).
"""

from __future__ import annotations

from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

from ais_demo.core.correlation import CORRELATION_HEADER, get_correlation_id
from ais_demo.integrations import monitor, service_bus
from ais_demo.orchestrator import process_permit
from ais_demo.schemas import PermitRequest, ProcessResult, SubmitResponse

router = APIRouter(prefix="/api", tags=["permits"])


@router.post("/permits", status_code=status.HTTP_202_ACCEPTED)
def submit_permit(request: PermitRequest) -> JSONResponse:
    """Accept a permit submission and enqueue it for async processing."""
    correlation_id = get_correlation_id()
    permit = request.model_dump(by_alias=True)
    service_bus.publish_permit(
        permit, correlation_id=correlation_id, message_id=request.parcel or correlation_id
    )
    body = SubmitResponse(correlationId=correlation_id).model_dump(by_alias=True)
    return JSONResponse(
        status_code=status.HTTP_202_ACCEPTED,
        content=body,
        headers={CORRELATION_HEADER: correlation_id},
    )


@router.post("/process", response_model=list[ProcessResult])
def drain_queue() -> list[ProcessResult]:
    """Process all queued permits (mirrors the Service Bus-triggered Function)."""
    results: list[ProcessResult] = []
    correlation_id = get_correlation_id()

    def handler(body: dict) -> None:
        results.append(process_permit(body, correlation_id))

    service_bus.consume_and_process(handler)
    return results


@router.get("/trace/{correlation_id}")
def get_trace(correlation_id: str) -> dict:
    """Return the end-to-end distributed trace for a correlation ID."""
    columns = ["itemType", "name", "resultCode", "duration", "cloudRoleName"]
    rows = monitor.query_trace(correlation_id)
    return {
        "correlationId": correlation_id,
        "columns": columns,
        "rows": rows,
    }
