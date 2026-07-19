"""Health/readiness endpoint."""

from __future__ import annotations

from fastapi import APIRouter

from ais_demo import __version__
from ais_demo.config import get_settings

router = APIRouter(tags=["health"])


@router.get("/api/health")
def health() -> dict:
    settings = get_settings()
    return {
        "status": "ok",
        "version": __version__,
        "mode": "simulated" if settings.simulated_mode else "live",
        "useCaseProfile": settings.use_case_profile,
        "env": settings.app_env,
    }
