"""Event Grid fan-out (Demo Track step B6).

Publishes a ``PermitCreated`` CloudEvent so decoupled subscribers (resident
notification, analytics/audit) can react without the permit flow knowing who is
listening. In simulated mode the event is recorded in memory.
"""

from __future__ import annotations

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger
from ais_demo.schemas import PermitEvent

logger = get_logger(__name__)

# In-memory sink for simulated mode (inspectable by tests/demos).
_PUBLISHED: list[dict] = []


def publish_permit_created(event: PermitEvent) -> bool:
    """Publish a ``PermitCreated`` event; return True on success."""
    settings = get_settings()
    event_type = f"{settings.event_type_prefix}.PermitCreated"

    if settings.simulated_mode or not settings.eventgrid_endpoint:
        _PUBLISHED.append({"type": event_type, "data": event.model_dump(by_alias=True, mode="json")})
        logger.info("published %s for %s (simulated)", event_type, event.permit_id)
        return True

    from azure.core.messaging import CloudEvent
    from azure.eventgrid import EventGridPublisherClient
    from azure.identity import DefaultAzureCredential

    client = EventGridPublisherClient(settings.eventgrid_endpoint, DefaultAzureCredential())
    cloud_event = CloudEvent(
        source=settings.event_source,
        type=event_type,
        data=event.model_dump(by_alias=True, mode="json"),
        subject=f"permits/{event.permit_id}",
    )
    client.send(cloud_event)
    logger.info("published %s for %s", event_type, event.permit_id)
    return True


def published_events() -> list[dict]:
    """Return events recorded in simulated mode."""
    return list(_PUBLISHED)


def reset_simulated_events() -> None:
    _PUBLISHED.clear()
