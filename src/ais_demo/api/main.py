"""FastAPI application factory for the AIS demo orchestrator."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from ais_demo import __version__
from ais_demo.api.routes import health, permits
from ais_demo.config import get_settings
from ais_demo.core.correlation import (
    CORRELATION_HEADER,
    get_correlation_id,
    new_correlation_id,
    set_correlation_id,
)
from ais_demo.core.errors import register_exception_handlers
from ais_demo.core.logging import configure_logging


class CorrelationMiddleware(BaseHTTPMiddleware):
    """Bind an inbound/generated correlation ID and echo it on the response."""

    async def dispatch(self, request: Request, call_next):
        incoming = request.headers.get(CORRELATION_HEADER) or new_correlation_id()
        set_correlation_id(incoming)
        response = await call_next(request)
        response.headers[CORRELATION_HEADER] = get_correlation_id()
        return response


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title="AIS Demo — Permit Intake API",
        version=__version__,
        description=(
            "Governed, event-driven permit-intake orchestrator for the Azure "
            "Integration Services demo. Runs offline in simulated mode."
        ),
    )

    app.add_middleware(CorrelationMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(health.router)
    app.include_router(permits.router)
    return app


app = create_app()
