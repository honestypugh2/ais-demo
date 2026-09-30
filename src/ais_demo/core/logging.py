"""Structured logging configuration."""

import logging
import sys

_CONFIGURED = False


def configure_logging(level: str = "INFO") -> None:
    """Configure root logging once with a concise, structured format.

    Every record carries a ``correlationId`` attribute, so the console format
    shows it and OpenTelemetry log export sends it to Application Insights as a
    custom dimension (``customDimensions['correlationId']``).
    """
    global _CONFIGURED
    if _CONFIGURED:
        return

    _install_correlation_record_factory()

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        logging.Formatter(
            fmt="%(asctime)s %(levelname)-7s %(name)s [%(correlationId)s] %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%S",
        )
    )

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level.upper())
    _CONFIGURED = True


def _install_correlation_record_factory() -> None:
    """Stamp the current correlation ID onto every log record."""
    base_factory = logging.getLogRecordFactory()

    def factory(*args, **kwargs) -> logging.LogRecord:
        from ais_demo.core.correlation import get_correlation_id

        record = base_factory(*args, **kwargs)
        record.correlationId = get_correlation_id()
        return record

    logging.setLogRecordFactory(factory)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
