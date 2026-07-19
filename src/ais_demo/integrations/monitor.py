"""End-to-end trace query (Demo Track step B8).

Runs a Kusto query against the Log Analytics workspace for a correlation ID and
returns the whole journey — APIM request, Logic App send, the function's
Document Intelligence and CRM calls, and the Event Grid publish. In simulated
mode a representative trace is returned so the demo works offline.
"""

from __future__ import annotations

from datetime import timedelta

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger

logger = get_logger(__name__)

KQL_TEMPLATE = """
union requests, dependencies, traces, exceptions
| where operation_Id == '{cid}'
     or customDimensions['correlationId'] == '{cid}'
| project timestamp, itemType, name, resultCode, duration, cloud_RoleName
| order by timestamp asc
"""


def query_trace(correlation_id: str) -> list[list]:
    """Return trace rows for ``correlation_id`` (columns match the KQL projection)."""
    settings = get_settings()
    if settings.simulated_mode or not settings.log_analytics_workspace_id:
        return _simulated_trace(correlation_id)

    from azure.identity import DefaultAzureCredential
    from azure.monitor.query import LogsQueryClient, LogsQueryStatus

    client = LogsQueryClient(DefaultAzureCredential())
    response = client.query_workspace(
        settings.log_analytics_workspace_id,
        KQL_TEMPLATE.format(cid=correlation_id),
        timespan=timedelta(hours=1),
    )
    # query_workspace returns a success or partial result; both expose tables.
    tables = getattr(response, "tables", None)
    if response.status == LogsQueryStatus.FAILURE or not tables:
        return []
    return [list(row) for row in tables[0].rows]


def _simulated_trace(correlation_id: str) -> list[list]:
    logger.info("Returning simulated end-to-end trace for %s", correlation_id)
    return [
        ["request", "POST /permits", "202", 41, "apim"],
        ["dependency", "send permits-in", "0", 12, "logic-app"],
        ["dependency", "ServiceBusTrigger", "0", 28, "func-permit-processor"],
        ["dependency", "analyze prebuilt-layout", "200", 612, "func-permit-processor"],
        ["dependency", "POST /api/permits", "200", 33, "func-permit-processor"],
        ["dependency", "publish PermitCreated", "200", 9, "func-permit-processor"],
    ]
