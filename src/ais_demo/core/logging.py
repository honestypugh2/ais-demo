"""Structured logging configuration."""

from __future__ import annotations

import logging
import sys

_CONFIGURED = False


def configure_logging(level: str = "INFO") -> None:
    """Configure root logging once with a concise, structured format."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            fmt="%(asctime)s %(levelname)-7s %(name)s [%(correlation_id)s] %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%S",
        )
    )
    handler.addFilter(_CorrelationFilter())

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level.upper())
    _CONFIGURED = True


class _CorrelationFilter(logging.Filter):
    """Inject the current correlation ID into every log record."""

    def filter(self, record: logging.LogRecord) -> bool:
        from ais_demo.core.correlation import get_correlation_id

        record.correlation_id = get_correlation_id()
        return True


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
