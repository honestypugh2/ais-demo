"""End-to-end trace query (Demo Track step B8).

Runs a Kusto query against the Log Analytics workspace (workspace-based
Application Insights tables) for a correlation ID and returns the whole journey —
the API host's request and dependencies plus the Function's processing logs,
which carry ``correlationId`` as a custom dimension or in the message text. In simulated
mode a representative trace is returned so the demo works offline.
"""

from datetime import timedelta

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger

logger = get_logger(__name__)

KQL_TEMPLATE = """
union AppRequests, AppDependencies, AppTraces, AppExceptions
| where OperationId == '{cid}'
     or tostring(Properties['correlationId']) == '{cid}'
     or Message has '{cid}'
| project TimeGenerated, Type, Name = coalesce(Name, Message, OuterMessage),
          ResultCode, DurationMs, AppRoleName
| order by TimeGenerated asc
| project-away TimeGenerated
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
        ["dependency", "score compliance via APIM AI gateway", "200", 384, "func-permit-processor"],
        ["dependency", "create permit record", "201", 33, "func-permit-processor"],
        ["dependency", "publish PermitCreated", "200", 9, "func-permit-processor"],
    ]
