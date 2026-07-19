"""End-to-end demo driver mapping to Demo Track steps B1-B8.

Usage:
    uv run ais-demo            # runs the full flow (simulated by default)
    uv run python -m ais_demo.demo.run_demo
"""

from __future__ import annotations

import json

from ais_demo.config import get_settings
from ais_demo.core.correlation import set_correlation_id
from ais_demo.core.logging import configure_logging, get_logger
from ais_demo.integrations import apim_client, event_grid, monitor, service_bus
from ais_demo.orchestrator import process_permit
from ais_demo.schemas import PermitRequest

logger = get_logger(__name__)

SAMPLE_PERMIT = {
    "name": "Jordan Lee",
    "type": "Building",
    "parcel": "AIS-2026-00417",
    "documentUrl": "https://example.invalid/permit_packet_00417.pdf",
    "applicantEmail": "jordan@example.com",
}

POISON_PERMIT = {"name": "No Type", "parcel": "AIS-2026-BAD"}  # missing 'type'


def _banner(step: str, title: str) -> None:
    print(f"\n\033[95m── {step} · {title} ──\033[0m")


def main() -> None:
    settings = get_settings()
    configure_logging(settings.log_level)
    service_bus.reset_simulated_queues()
    event_grid.reset_simulated_events()

    print(f"AIS Demo · mode={'simulated' if settings.simulated_mode else 'live'}")

    # B1 — Submit a permit through APIM (Entra auth).
    _banner("B1", "Submit a permit through APIM")
    request = PermitRequest.model_validate(SAMPLE_PERMIT)
    status_code, correlation_id = apim_client.submit_permit(request.model_dump(by_alias=True))
    set_correlation_id(correlation_id)
    print(f"  -> {status_code} {correlation_id}")

    # B2 — Publish to Service Bus (durable messaging).
    _banner("B2", "Publish to Service Bus")
    service_bus.publish_permit(
        request.model_dump(by_alias=True), correlation_id=correlation_id, message_id=SAMPLE_PERMIT["parcel"]
    )
    print(f"  -> enqueued on {settings.servicebus_queue}")

    # B3-B6 — The Function/AI agent: extract, validate, CRM write, publish event.
    _banner("B3-B6", "Extract · validate · CRM · event")

    def _handler(body: dict) -> None:
        result = process_permit(body, correlation_id)
        print(f"  extracted : {result.extracted.model_dump(by_alias=True)}")
        print(f"  compliance: score={result.compliance.score} flags={result.compliance.flags}")
        print(f"  CRM       : {result.permit_id} (status={result.status})")
        print(f"  event     : published={result.event_published}")

    service_bus.consume_and_process(_handler)

    # B7 — Resilience: a poison message is dead-lettered, not lost.
    _banner("B7", "Resilience — poison message to dead-letter")
    service_bus.publish_permit(POISON_PERMIT, correlation_id=correlation_id, message_id="poison-1")
    service_bus.consume_and_process(lambda _body: None)
    print(f"  -> dead-lettered messages: {service_bus.dead_letter_count()}")

    # B8 — Query the end-to-end trace (Monitor).
    _banner("B8", "Query the end-to-end trace")
    for row in monitor.query_trace(correlation_id):
        print(f"  {row}")

    print("\n\033[92mDemo complete.\033[0m Published events:")
    print(json.dumps(event_grid.published_events(), indent=2))


if __name__ == "__main__":
    main()
