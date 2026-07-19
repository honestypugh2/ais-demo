"""Health endpoint tests."""

from fastapi.testclient import TestClient

from ais_demo.api.main import create_app

client = TestClient(create_app())


def test_health_ok():
    resp = client.get("/api/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["mode"] in {"simulated", "live"}
    assert "version" in body


def test_correlation_header_present():
    resp = client.get("/api/health")
    assert resp.headers.get("X-Correlation-Id")
