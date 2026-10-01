"""Live-path contract for Document Intelligence extraction (mocked SDK client)."""

from types import SimpleNamespace

import pytest

from ais_demo.config import get_settings
from ais_demo.integrations import document_intelligence


def _kv(key: str, value: str) -> SimpleNamespace:
    return SimpleNamespace(key=SimpleNamespace(content=key), value=SimpleNamespace(content=value))


class _FakeClient:
    calls: list[dict] = []

    def __init__(self, endpoint, credential):
        self.endpoint = endpoint

    def begin_analyze_document(self, model_id, body, **kwargs):
        _FakeClient.calls.append({"model_id": model_id, "body": body, **kwargs})
        # prebuilt-layout only returns key-value pairs when the add-on is requested.
        requested = [str(getattr(f, "value", f)) for f in kwargs.get("features") or []]
        pairs = (
            [
                _kv("Property Owner Name", "[Applicant Name]"),
                _kv("Service Address", "1200 Main St, Anytown"),
                _kv("Lot/Block Number", "Lot 7 / Block 3"),
                _kv("Service Type", "Building"),
            ]
            if "keyValuePairs" in requested
            else []
        )
        page = SimpleNamespace(lines=[SimpleNamespace(content="Applicant signature: J. Lee")])
        result = SimpleNamespace(key_value_pairs=pairs, pages=[page])
        return SimpleNamespace(result=lambda: result)


@pytest.fixture
def live_docintel(monkeypatch):
    import azure.ai.documentintelligence as sdk
    import azure.identity

    monkeypatch.setenv("SIMULATED_MODE", "false")
    monkeypatch.setenv("DOCINTEL_ENDPOINT", "https://docintel.example.test/")
    monkeypatch.setattr(sdk, "DocumentIntelligenceClient", _FakeClient)
    monkeypatch.setattr(azure.identity, "DefaultAzureCredential", lambda: object())
    _FakeClient.calls.clear()
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_live_extraction_requests_key_value_pairs_and_maps_fields(live_docintel):
    extracted = document_intelligence.extract_fields(
        {"name": "[Applicant Name]", "type": "Building", "documentUrl": "https://example.invalid/p.pdf"}
    )

    call = _FakeClient.calls[0]
    assert call["model_id"] == "prebuilt-layout"
    assert [str(getattr(f, "value", f)) for f in call["features"]] == ["keyValuePairs"]
    assert extracted.applicant_name == "[Applicant Name]"
    assert extracted.service_address == "1200 Main St, Anytown"
    assert extracted.parcel_id == "Lot 7 / Block 3"
    assert extracted.signature_present is True
