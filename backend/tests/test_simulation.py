from fastapi.testclient import TestClient

import app.services.simulation as simulation_module
from app.main import app
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import DISCLAIMER, SimulationRequest
from app.services.simulation import (
    ImageGenProvider,
    OpenAIImageProvider,
    UnavailableImageProvider,
    _get_default_provider,
    generate_simulation,
)

client = TestClient(app)


def _request(**overrides) -> SimulationRequest:
    defaults = dict(
        location_name="Brooklyn Bridge Park",
        location_type=LocationType.WATERFRONT,
        event=SunEvent.SUNSET,
        cloud_cover_summary="partly cloudy (high clouds)",
        visibility_likelihood=0.9,
        color_probabilities=ColorProbabilities(
            pink=0.6, purple=0.2, orange=0.8, red=0.1, golden=0.85
        ),
    )
    defaults.update(overrides)
    return SimulationRequest(**defaults)


# These tests exercise prompt-building and graceful degradation only, so they
# always inject the placeholder provider explicitly — otherwise they'd depend
# on whether a real OPENAI_API_KEY happens to be set in the environment, and
# would fire real (billed) API calls whenever one is.


def test_prompt_includes_location_event_and_foreground():
    result = generate_simulation(_request(), provider=UnavailableImageProvider())

    assert "Brooklyn Bridge Park" in result.prompt
    assert "sunset" in result.prompt
    assert "water reflecting the sky" in result.prompt
    assert "partly cloudy (high clouds)" in result.prompt


def test_prompt_describes_dominant_and_hinted_colors():
    result = generate_simulation(_request(), provider=UnavailableImageProvider())

    # pink (0.6), orange (0.8), golden (0.85) are dominant (>=0.5); purple (0.2) is muted
    assert "pink" in result.prompt
    assert "orange" in result.prompt
    assert "golden" in result.prompt
    assert "purple" not in result.prompt  # 0.2 is below the 0.25 hint threshold


def test_prompt_sun_visibility_wording_scales_with_likelihood():
    provider = UnavailableImageProvider()
    high = generate_simulation(_request(visibility_likelihood=0.9), provider=provider)
    mid = generate_simulation(_request(visibility_likelihood=0.5), provider=provider)
    low = generate_simulation(_request(visibility_likelihood=0.1), provider=provider)

    assert "clearly visible" in high.prompt
    assert "partially visible" in mid.prompt
    assert "obscured" in low.prompt


def test_no_provider_configured_degrades_gracefully():
    result = generate_simulation(_request(), provider=UnavailableImageProvider())

    assert result.image_url is None
    assert result.provider_status == "not_configured"
    assert result.disclaimer == DISCLAIMER
    assert len(result.prompt) > 0


def test_working_provider_returns_image_url():
    class FakeProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            return "https://example.com/generated.png"

    result = generate_simulation(_request(), provider=FakeProvider())

    assert result.image_url == "https://example.com/generated.png"
    assert result.provider_status == "generated"


def test_provider_error_degrades_gracefully_without_raising():
    class BrokenProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            raise ConnectionError("provider unreachable")

    result = generate_simulation(_request(), provider=BrokenProvider())

    assert result.image_url is None
    assert result.provider_status == "error"


def test_simulate_endpoint_returns_disclaimer_and_prompt(monkeypatch):
    # This test is about the /simulate route's shape, not provider selection —
    # force the "unconfigured" path so it's deterministic regardless of
    # whatever OPENAI_API_KEY happens to be set in this environment.
    monkeypatch.setattr(
        simulation_module, "_get_default_provider", lambda: UnavailableImageProvider()
    )

    response = client.post(
        "/simulate",
        json={
            "location_name": "Top of the Rock",
            "location_type": "elevated_viewpoint",
            "event": "sunset",
            "cloud_cover_summary": "mostly clear skies",
            "visibility_likelihood": 0.95,
            "color_probabilities": {
                "pink": 0.2,
                "purple": 0.1,
                "orange": 0.9,
                "red": 0.1,
                "golden": 0.9,
            },
        },
    )
    body = response.json()

    assert response.status_code == 200
    assert body["provider_status"] == "not_configured"
    assert body["image_url"] is None
    assert body["disclaimer"] == DISCLAIMER
    assert "Top of the Rock" in body["prompt"]


# --- Provider selection ---


def test_default_provider_is_unavailable_without_api_key(monkeypatch):
    monkeypatch.setattr(
        simulation_module, "get_settings", lambda: type("S", (), {"openai_api_key": ""})()
    )

    assert isinstance(_get_default_provider(), UnavailableImageProvider)


def test_default_provider_is_openai_with_api_key(monkeypatch):
    monkeypatch.setattr(
        simulation_module, "get_settings", lambda: type("S", (), {"openai_api_key": "sk-fake"})()
    )

    assert isinstance(_get_default_provider(), OpenAIImageProvider)


# --- OpenAIImageProvider itself, mocked (no real network call) ---


class _FakeImageData:
    def __init__(self, b64_json: str):
        self.b64_json = b64_json


class _FakeImagesResponse:
    def __init__(self, b64_json: str):
        self.data = [_FakeImageData(b64_json)]


class _FakeImagesResource:
    def __init__(self, b64_json: str):
        self._b64_json = b64_json
        self.calls: list[dict] = []

    def generate(self, model, prompt, size, quality):
        self.calls.append({"model": model, "prompt": prompt, "size": size, "quality": quality})
        return _FakeImagesResponse(self._b64_json)


class _FakeOpenAIClient:
    def __init__(self, b64_json: str = "ZmFrZS1pbWFnZS1ieXRlcw=="):
        self.images = _FakeImagesResource(b64_json)


def test_openai_provider_returns_data_uri_from_b64_response():
    fake_client = _FakeOpenAIClient()
    provider = OpenAIImageProvider(client=fake_client)

    image_url = provider.generate_image("a test prompt")

    assert image_url == "data:image/png;base64,ZmFrZS1pbWFnZS1ieXRlcw=="
    assert fake_client.images.calls[0]["model"] == "gpt-image-2"
    assert fake_client.images.calls[0]["prompt"] == "a test prompt"
