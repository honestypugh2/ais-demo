"""End-to-end trace query (Demo Track step B8).

Runs a Kusto query against the Log Analytics workspace (workspace-based
Application Insights tables) for a correlation ID and returns the whole journey.

The journey spans two Application Insights operations: the intake request at API
Management (which logs ``X-Correlation-Id``) and the Function's processing
operation (Document Intelligence, the AI-gateway call back through APIM, and the
Event Grid publish), whose logs carry the correlation ID. The Service Bus hop
doesn't carry W3C trace context, so the query finds every operation that
mentions the correlation ID and returns their requests, dependencies, and the
log records that name it. In simulated
mode a representative trace is returned so the demo works offline.
"""

from datetime import timedelta

from ais_demo.config import get_settings
from ais_demo.core.logging import get_logger

logger = get_logger(__name__)

KQL_TEMPLATE = """
let cid = '{cid}';
let hits = union AppRequests, AppDependencies, AppTraces, AppExceptions
    | where OperationId == cid or Message has cid or tostring(Properties) has cid;
let ops = hits
    | where isnotempty(OperationId) and OperationId != '00000000000000000000000000000000'
    | distinct OperationId;
union
    (union AppRequests, AppDependencies, AppExceptions | where OperationId in (ops)),
    (hits | where Type == 'AppTraces')
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
