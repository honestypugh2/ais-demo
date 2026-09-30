"""Live-path contract for the AI-gateway scorer (mocked HTTP, no Azure calls)."""

import json

import httpx2
import pytest
from openai import OpenAI

from ais_demo.config import get_settings
from ais_demo.integrations import ai_gateway
from ais_demo.schemas import ExtractedPermit

_RESPONSE = {
    "id": "resp_1",
    "object": "response",
    "created_at": 0,
    "status": "completed",
    "model": "gpt-5.4-mini",
    "output": [
        {
            "type": "message",
            "id": "msg_1",
            "role": "assistant",
            "status": "completed",
            "content": [
                {
                    "type": "output_text",
                    "text": json.dumps({"score": 75, "missing": ["signature"], "flags": ["x"]}),
                    "annotations": [],
                }
            ],
        }
    ],
    "usage": {
        "input_tokens": 10,
        "output_tokens": 20,
        "total_tokens": 30,
        "input_tokens_details": {"cached_tokens": 0},
        "output_tokens_details": {"reasoning_tokens": 5},
    },
    "parallel_tool_calls": True,
    "tool_choice": "auto",
    "tools": [],
}


@pytest.fixture
def live_settings(monkeypatch):
    monkeypatch.setenv("SIMULATED_MODE", "false")
    monkeypatch.setenv("AOAI_VIA_APIM_BASE", "https://apim.example.test/openai")
    monkeypatch.setenv("APIM_SUBSCRIPTION_KEY", "sub-key")
    get_settings.cache_clear()
    yield get_settings()
    get_settings.cache_clear()


def test_gateway_client_targets_v1_api_with_apim_key():
    client = ai_gateway.gateway_client("https://apim.example.test/openai/", "k", {"x-dept": "d"})
    assert str(client.base_url) == "https://apim.example.test/openai/v1/"
    assert client.default_headers["api-key"] == "k"
    assert client.default_headers["x-dept"] == "d"


def test_live_scoring_uses_responses_api_with_structured_output(live_settings, monkeypatch):
    seen: dict = {}

    def handler(request: httpx2.Request) -> httpx2.Response:
        seen["url"] = str(request.url)
        seen["headers"] = dict(request.headers)
        seen["body"] = json.loads(request.content)
        return httpx2.Response(200, json=_RESPONSE)

    real_factory = ai_gateway.gateway_client

    def fake_client(base, key, headers=None):
        real = real_factory(base, key, headers)
        return OpenAI(
            base_url=real.base_url,
            api_key=key,
            default_headers=dict(real.default_headers),
            http_client=httpx2.Client(transport=httpx2.MockTransport(handler)),
        )

    monkeypatch.setattr(ai_gateway, "gateway_client", fake_client)
    result = ai_gateway.score_compliance(ExtractedPermit(applicantName="Jordan Lee"))

    assert result.score == 75
    assert result.missing == ["signature"]
    assert result.tokens == 30
    assert seen["url"] == "https://apim.example.test/openai/v1/responses"
    assert "api-version" not in seen["url"]
    assert seen["headers"]["api-key"] == "sub-key"
    assert seen["headers"]["x-dept"] == "permitting"
    assert seen["body"]["model"] == live_settings.aoai_deployment
    assert seen["body"]["reasoning"] == {"effort": "low"}
    assert seen["body"]["text"]["format"]["type"] == "json_schema"
    assert "temperature" not in seen["body"]
