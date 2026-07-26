from fastapi.testclient import TestClient

from app.main import app
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import DISCLAIMER, SimulationRequest
from app.services.simulation import ImageGenProvider, generate_simulation

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


def test_prompt_includes_location_event_and_foreground():
    result = generate_simulation(_request())

    assert "Brooklyn Bridge Park" in result.prompt
    assert "sunset" in result.prompt
    assert "water reflecting the sky" in result.prompt
    assert "partly cloudy (high clouds)" in result.prompt


def test_prompt_describes_dominant_and_hinted_colors():
    result = generate_simulation(_request())

    # pink (0.6), orange (0.8), golden (0.85) are dominant (>=0.5); purple (0.2) is muted
    assert "pink" in result.prompt
    assert "orange" in result.prompt
    assert "golden" in result.prompt
    assert "purple" not in result.prompt  # 0.2 is below the 0.25 hint threshold


def test_prompt_sun_visibility_wording_scales_with_likelihood():
    high = generate_simulation(_request(visibility_likelihood=0.9))
    mid = generate_simulation(_request(visibility_likelihood=0.5))
    low = generate_simulation(_request(visibility_likelihood=0.1))

    assert "clearly visible" in high.prompt
    assert "partially visible" in mid.prompt
    assert "obscured" in low.prompt


def test_no_provider_configured_degrades_gracefully():
    result = generate_simulation(_request())

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


def test_simulate_endpoint_returns_disclaimer_and_prompt():
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
