"""Correlation-ID helpers.

A single correlation ID is created at the front door (API Management in the
deployed flow) and propagated through every hop — Logic App, Service Bus
message properties, the Function, the CRM write, and the Event Grid event — so
the whole journey renders as one distributed trace in Application Insights.
"""

from __future__ import annotations

import uuid
from contextvars import ContextVar

CORRELATION_HEADER = "X-Correlation-Id"

_correlation_id: ContextVar[str | None] = ContextVar("correlation_id", default=None)


def new_correlation_id() -> str:
    """Generate a fresh correlation ID."""
    return str(uuid.uuid4())


def set_correlation_id(value: str) -> None:
    """Bind a correlation ID to the current context."""
    _correlation_id.set(value)


def get_correlation_id() -> str:
    """Return the current correlation ID, creating one if absent."""
    value = _correlation_id.get()
    if value is None:
        value = new_correlation_id()
        _correlation_id.set(value)
    return value
