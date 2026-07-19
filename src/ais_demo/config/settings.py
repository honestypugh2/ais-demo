"""Application configuration loaded from environment / .env."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Strongly-typed settings for the AIS demo.

    All fields have safe defaults so the app boots in ``SIMULATED_MODE`` with
    no Azure credentials. Set ``SIMULATED_MODE=false`` and provide real values
    to run against live Azure services.
    """

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # ── Run mode ────────────────────────────────────────────────────────────
    simulated_mode: bool = Field(default=True, alias="SIMULATED_MODE")
    app_env: str = Field(default="development", alias="APP_ENV")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    use_case_profile: str = Field(default="permit-intake", alias="USE_CASE_PROFILE")

    # ── Microsoft Entra ─────────────────────────────────────────────────────
    tenant_id: str = Field(default="", alias="TENANT_ID")
    client_id: str = Field(default="", alias="CLIENT_ID")
    client_secret: str = Field(default="", alias="CLIENT_SECRET")
    api_scope: str = Field(default="api://ais-demo-permits/.default", alias="API_SCOPE")

    # ── API Management ──────────────────────────────────────────────────────
    apim_base: str = Field(default="", alias="APIM_BASE")
    apim_subscription_key: str = Field(default="", alias="APIM_SUBSCRIPTION_KEY")
    permits_api_path: str = Field(default="/permits/v1/permits", alias="PERMITS_API_PATH")

    # ── Service Bus ─────────────────────────────────────────────────────────
    servicebus_fqdn: str = Field(default="", alias="SERVICEBUS_FQDN")
    servicebus_queue: str = Field(default="permits-in", alias="SERVICEBUS_QUEUE")

    # ── Document Intelligence ───────────────────────────────────────────────
    docintel_endpoint: str = Field(default="", alias="DOCINTEL_ENDPOINT")
    docintel_model: str = Field(default="prebuilt-layout", alias="DOCINTEL_MODEL")

    # ── Azure OpenAI via APIM AI gateway ────────────────────────────────────
    aoai_via_apim_base: str = Field(default="", alias="AOAI_VIA_APIM_BASE")
    aoai_deployment: str = Field(default="gpt-4o-mini", alias="AOAI_DEPLOYMENT")
    aoai_api_version: str = Field(default="2024-10-21", alias="AOAI_API_VERSION")

    # ── Event Grid ──────────────────────────────────────────────────────────
    eventgrid_endpoint: str = Field(default="", alias="EVENTGRID_ENDPOINT")
    event_source: str = Field(default="ais-demo/permitting", alias="EVENT_SOURCE")
    event_type_prefix: str = Field(default="AisDemo.Permitting", alias="EVENT_TYPE_PREFIX")

    # ── CRM ─────────────────────────────────────────────────────────────────
    crm_base: str = Field(default="", alias="CRM_BASE")

    # ── Observability ───────────────────────────────────────────────────────
    log_analytics_workspace_id: str = Field(default="", alias="LOG_ANALYTICS_WORKSPACE_ID")
    applicationinsights_connection_string: str = Field(
        default="", alias="APPLICATIONINSIGHTS_CONNECTION_STRING"
    )

    # ── API host ────────────────────────────────────────────────────────────
    cors_origins: str = Field(default="http://localhost:5173", alias="CORS_ORIGINS")
    compliance_threshold: int = Field(default=70, alias="COMPLIANCE_THRESHOLD")

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
