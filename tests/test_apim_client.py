"""Live-path contract for the APIM client (mocked HTTP, no Azure calls)."""

import httpx2
import pytest

from ais_demo.config import get_settings
from ais_demo.integrations import apim_client


@pytest.fixture
def live_apim(monkeypatch):
    monkeypatch.setenv("SIMULATED_MODE", "false")
    monkeypatch.setenv("APIM_BASE", "https://apim.example.test")
    monkeypatch.setenv("APIM_SUBSCRIPTION_KEY", "sub-key")
    monkeypatch.setenv("PERMITS_API_PATH", "/permits")
    for name in ("TENANT_ID", "CLIENT_ID", "CLIENT_SECRET"):
        monkeypatch.setenv(name, "")
    get_settings.cache_clear()
    yield monkeypatch
    get_settings.cache_clear()


def test_default_path_matches_the_deployed_permits_api():
    from ais_demo.config.settings import Settings

    assert Settings.model_fields["permits_api_path"].default == "/permits"


def _fake_post(seen: dict):
    def post(url, headers, json, timeout):
        seen.update(url=url, headers=headers)
        return httpx2.Response(202, headers={"X-Correlation-Id": "cid-1"})

    return post


def test_submits_to_deployed_path_with_subscription_key_only(live_apim):
    seen: dict = {}
    live_apim.setattr(apim_client.httpx2, "post", _fake_post(seen))

    status, cid = apim_client.submit_permit({"name": "[Applicant Name]", "type": "Building"})

    assert (status, cid) == (202, "cid-1")
    assert seen["url"] == "https://apim.example.test/permits"
    assert seen["headers"]["Ocp-Apim-Subscription-Key"] == "sub-key"
    assert "Authorization" not in seen["headers"]


def test_adds_entra_bearer_token_when_client_credentials_are_set(live_apim):
    seen: dict = {}
    for name, value in (("TENANT_ID", "t"), ("CLIENT_ID", "c"), ("CLIENT_SECRET", "s")):
        live_apim.setenv(name, value)
    get_settings.cache_clear()
    live_apim.setattr(apim_client.httpx2, "post", _fake_post(seen))
    live_apim.setattr(apim_client, "acquire_token", lambda settings: "tok")

    apim_client.submit_permit({"name": "[Applicant Name]", "type": "Building"})

    assert seen["headers"]["Authorization"] == "Bearer tok"
