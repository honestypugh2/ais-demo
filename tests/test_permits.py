"""Permit submission + processing endpoint tests."""

from fastapi.testclient import TestClient

from ais_demo.api.main import create_app

client = TestClient(create_app())


def test_submit_returns_202_with_correlation_id():
    resp = client.post("/api/permits", json={"name": "Jordan Lee", "type": "Building"})
    assert resp.status_code == 202
    body = resp.json()
    assert body["status"] == "accepted"
    assert body["correlationId"]
    assert resp.headers.get("X-Correlation-Id") == body["correlationId"]


def test_submit_then_process_produces_result():
    submit = client.post(
        "/api/permits",
        json={"name": "Sam Rivera", "type": "Electrical", "parcel": "AIS-2026-00521"},
    )
    assert submit.status_code == 202

    processed = client.post("/api/process")
    assert processed.status_code == 200
    results = processed.json()
    assert len(results) == 1
    result = results[0]
    assert result["permitId"]
    assert 0 <= result["compliance"]["score"] <= 100
    assert result["eventPublished"] is True


def test_trace_endpoint_returns_rows():
    resp = client.get("/api/trace/test-correlation-id")
    assert resp.status_code == 200
    body = resp.json()
    assert body["correlationId"] == "test-correlation-id"
    assert len(body["rows"]) > 0
