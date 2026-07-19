"""Orchestrator + resilience tests (simulated backends)."""

from ais_demo.integrations import event_grid, service_bus
from ais_demo.orchestrator import process_permit


def test_process_permit_full_pipeline():
    permit = {"name": "Priya Chandra", "type": "Plumbing", "parcel": "AIS-2026-00622"}
    result = process_permit(permit, correlation_id="cid-1")

    assert result.permit_id
    assert result.extracted.applicant_name == "Priya Chandra"
    assert result.event_published is True
    # An event was recorded in the simulated Event Grid sink.
    assert len(event_grid.published_events()) == 1


def test_poison_message_is_dead_lettered():
    # Missing 'type' → poison packet.
    service_bus.publish_permit(
        {"name": "No Type"}, correlation_id="cid-2", message_id="poison-1"
    )
    processed = service_bus.consume_and_process(lambda _body: None)

    assert processed == 0
    assert service_bus.dead_letter_count() == 1


def test_valid_message_is_processed():
    service_bus.publish_permit(
        {"name": "Jordan Lee", "type": "Building"},
        correlation_id="cid-3",
        message_id="ok-1",
    )
    seen: list[dict] = []
    processed = service_bus.consume_and_process(seen.append)

    assert processed == 1
    assert seen[0]["type"] == "Building"
    assert service_bus.dead_letter_count() == 0
