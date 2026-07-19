"""Application error types and FastAPI exception handlers."""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from ais_demo.core.correlation import CORRELATION_HEADER, get_correlation_id


class AisDemoError(Exception):
    """Base application error."""

    status_code = 500
    code = "internal_error"

    def __init__(self, message: str, *, status_code: int | None = None, code: str | None = None):
        super().__init__(message)
        self.message = message
        if status_code is not None:
            self.status_code = status_code
        if code is not None:
            self.code = code


class ValidationFailedError(AisDemoError):
    status_code = 422
    code = "validation_failed"


class UpstreamServiceError(AisDemoError):
    status_code = 502
    code = "upstream_error"


def register_exception_handlers(app: FastAPI) -> None:
    """Attach a consistent JSON error contract to the app."""

    @app.exception_handler(AisDemoError)
    async def _handle_app_error(_: Request, exc: AisDemoError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {"code": exc.code, "message": exc.message},
                "correlationId": get_correlation_id(),
            },
            headers={CORRELATION_HEADER: get_correlation_id()},
        )

    @app.exception_handler(Exception)
    async def _handle_unexpected(_: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content={
                "error": {"code": "internal_error", "message": "Unexpected error"},
                "correlationId": get_correlation_id(),
            },
            headers={CORRELATION_HEADER: get_correlation_id()},
        )
