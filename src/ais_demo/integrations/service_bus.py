"""Service Bus durable messaging (Demo Track steps B2 and B7).

Publishes permit messages to a queue and consumes them, dead-lettering poison
messages. In live mode it uses ``azure-servicebus`` with
``DefaultAzureCredential`` (managed identity — no secrets on the wire); in
simulated mode an in-memory queue stands in for the broker.
"""

from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass, field

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger

logger = get_logger(__name__)


@dataclass
class _SimMessage:
    body: str
    message_id: str
    correlation_id: str
    application_properties: dict = field(default_factory=dict)


# Module-level in-memory queues (simulated mode only).
_QUEUE: deque[_SimMessage] = deque()
_DEAD_LETTER: deque[tuple[_SimMessage, str]] = deque()


def publish_permit(permit: dict, correlation_id: str, message_id: str) -> None:
    """Enqueue a permit message (step B2)."""
    settings = get_settings()
    if settings.simulated_mode or not settings.servicebus_fqdn:
        _QUEUE.append(
            _SimMessage(
                body=json.dumps(permit),
                message_id=message_id,
                correlation_id=correlation_id,
                application_properties={"correlationId": correlation_id},
            )
        )
        logger.info("Enqueued permit %s on %s (simulated)", message_id, settings.servicebus_queue)
        return

    from azure.identity import DefaultAzureCredential
    from azure.servicebus import ServiceBusClient, ServiceBusMessage

    credential = DefaultAzureCredential()
    with ServiceBusClient(settings.servicebus_fqdn, credential) as client:
        sender = client.get_queue_sender(settings.servicebus_queue)
        with sender:
            msg = ServiceBusMessage(
                json.dumps(permit),
                content_type="application/json",
                message_id=message_id,  # enables duplicate detection
                correlation_id=correlation_id,
                application_properties={"correlationId": correlation_id},
            )
            sender.send_messages(msg)
    logger.info("Enqueued permit %s on %s", message_id, settings.servicebus_queue)


def consume_and_process(handler) -> int:
    """Consume queued messages, dead-lettering poison ones (step B7).

    ``handler(body: dict) -> None`` processes each message. A ``ValueError``
    raised by the handler dead-letters the message instead of losing it.
    Returns the number of successfully processed messages.
    """
    settings = get_settings()
    if settings.simulated_mode or not settings.servicebus_fqdn:
        return _consume_simulated(handler)
    return _consume_live(handler, settings)


def _consume_simulated(handler) -> int:
    processed = 0
    while _QUEUE:
        msg = _QUEUE.popleft()
        try:
            body = json.loads(msg.body)
            if "type" not in body:
                raise ValueError("malformed permit packet")
            handler(body)
            processed += 1
        except ValueError as ex:
            _DEAD_LETTER.append((msg, str(ex)))
            logger.warning("dead-lettered: %s", ex)
    return processed


def _consume_live(handler, settings) -> int:
    from azure.identity import DefaultAzureCredential
    from azure.servicebus import ServiceBusClient

    processed = 0
    credential = DefaultAzureCredential()
    with ServiceBusClient(settings.servicebus_fqdn, credential) as client:
        receiver = client.get_queue_receiver(settings.servicebus_queue, max_wait_time=5)
        with receiver:
            for msg in receiver:
                try:
                    body = json.loads(str(msg))
                    if "type" not in body:
                        raise ValueError("malformed permit packet")
                    handler(body)
                    receiver.complete_message(msg)
                    processed += 1
                except ValueError as ex:
                    receiver.dead_letter_message(
                        msg, reason="ValidationError", error_description=str(ex)
                    )
                    logger.warning("dead-lettered: %s", ex)
    return processed


def dead_letter_count() -> int:
    """Return the number of dead-lettered messages (simulated mode)."""
    return len(_DEAD_LETTER)


def reset_simulated_queues() -> None:
    """Clear the in-memory queues (test/demo reset helper)."""
    _QUEUE.clear()
    _DEAD_LETTER.clear()
