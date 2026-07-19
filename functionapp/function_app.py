"""Azure Functions host — Service Bus-triggered permit processor.

Reuses the shared orchestrator in ``src/ais_demo``. Each message on the
``permits-in`` queue is extracted, validated, written to CRM, and fans out a
``PermitCreated`` event. Poison messages are dead-lettered by the runtime after
the configured max delivery count.
"""

from __future__ import annotations

import json
import logging

import azure.functions as func

from ais_demo.core.correlation import new_correlation_id, set_correlation_id
from ais_demo.orchestrator import process_permit

app = func.FunctionApp()


@app.function_name(name="ProcessPermit")
@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="permits-in",
    connection="ServiceBusConnection",
)
def process_permit_message(msg: func.ServiceBusMessage) -> None:
    correlation_id = (
        msg.application_properties.get("correlationId")
        if msg.application_properties
        else None
    ) or msg.correlation_id or new_correlation_id()
    set_correlation_id(correlation_id)

    body = json.loads(msg.get_body().decode("utf-8"))
    if "type" not in body:
        # Raising moves the message toward the dead-letter queue after retries.
        raise ValueError("malformed permit packet")

    result = process_permit(body, correlation_id)
    logging.info(
        "Processed permit %s status=%s score=%s",
        result.permit_id,
        result.status,
        result.compliance.score,
    )
