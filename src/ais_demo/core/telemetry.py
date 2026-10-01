"""OpenTelemetry export to Application Insights (Azure Monitor distro)."""

from ais_demo.core.logging import get_logger

logger = get_logger(__name__)


def configure_telemetry(connection_string: str) -> bool:
    """Enable traces, metrics, and logs export when a connection string is set.

    Call before creating the FastAPI app so the FastAPI instrumentation applies.
    The Azure Functions host enables the same export through the
    ``PYTHON_APPLICATIONINSIGHTS_ENABLE_TELEMETRY`` app setting instead.
    """
    if not connection_string:
        return False

    from azure.monitor.opentelemetry import configure_azure_monitor

    configure_azure_monitor(connection_string=connection_string, logger_name="ais_demo")
    logger.info("OpenTelemetry export to Application Insights enabled")
    return True
