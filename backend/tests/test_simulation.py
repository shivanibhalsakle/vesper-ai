from fastapi.testclient import TestClient

import app.services.simulation as simulation_module
from app.main import app
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import DISCLAIMER, SimulationRequest
from app.services.image_limits import DAILY_LIMIT_PER_USER, ImageLimitExceeded
from app.services.simulation import (
    ImageGenProvider,
    OpenAIImageProvider,
    UnavailableImageProvider,
    _get_default_provider,
    generate_simulation,
)

client = TestClient(app)

USER_ID = "user-1"


class InMemoryCache:
    def __init__(self):
        self.store: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self.store.get(key)

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        self.store[key] = value


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


def test_prompt_includes_location_event_and_foreground(db_session):
    result = generate_simulation(
        _request(), USER_ID, db_session, provider=UnavailableImageProvider(), cache=InMemoryCache()
    )

    assert "Brooklyn Bridge Park" in result.prompt
    assert "sunset" in result.prompt
    assert "water reflecting the sky" in result.prompt
    assert "partly cloudy (high clouds)" in result.prompt


def test_prompt_describes_dominant_and_hinted_colors(db_session):
    result = generate_simulation(
        _request(), USER_ID, db_session, provider=UnavailableImageProvider(), cache=InMemoryCache()
    )

    # pink (0.6), orange (0.8), golden (0.85) are dominant (>=0.5); purple (0.2) is muted
    assert "pink" in result.prompt
    assert "orange" in result.prompt
    assert "golden" in result.prompt
    assert "purple" not in result.prompt  # 0.2 is below the 0.25 hint threshold


def test_prompt_sun_visibility_wording_scales_with_likelihood(db_session):
    provider = UnavailableImageProvider()
    high = generate_simulation(
        _request(visibility_likelihood=0.9), USER_ID, db_session, provider=provider,
        cache=InMemoryCache(),
    )
    mid = generate_simulation(
        _request(visibility_likelihood=0.5), USER_ID, db_session, provider=provider,
        cache=InMemoryCache(),
    )
    low = generate_simulation(
        _request(visibility_likelihood=0.1), USER_ID, db_session, provider=provider,
        cache=InMemoryCache(),
    )

    assert "clearly visible" in high.prompt
    assert "partially visible" in mid.prompt
    assert "obscured" in low.prompt


def test_no_provider_configured_degrades_gracefully(db_session):
    result = generate_simulation(
        _request(), USER_ID, db_session, provider=UnavailableImageProvider(), cache=InMemoryCache()
    )

    assert result.image_url is None
    assert result.provider_status == "not_configured"
    assert result.disclaimer == DISCLAIMER
    assert len(result.prompt) > 0
    # An unconfigured provider never generated anything, so it shouldn't
    # cost the user one of their daily previews.
    assert result.remaining_today == DAILY_LIMIT_PER_USER


def test_working_provider_returns_image_url(db_session):
    class FakeProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            return "https://example.com/generated.png"

    result = generate_simulation(
        _request(), USER_ID, db_session, provider=FakeProvider(), cache=InMemoryCache()
    )

    assert result.image_url == "https://example.com/generated.png"
    assert result.provider_status == "generated"
    assert result.remaining_today == DAILY_LIMIT_PER_USER - 1


def test_provider_error_degrades_gracefully_without_raising(db_session):
    class BrokenProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            raise ConnectionError("provider unreachable")

    result = generate_simulation(
        _request(), USER_ID, db_session, provider=BrokenProvider(), cache=InMemoryCache()
    )

    assert result.image_url is None
    assert result.provider_status == "error"
    # A failed generation didn't produce anything either, so it shouldn't
    # cost the user one of their daily previews.
    assert result.remaining_today == DAILY_LIMIT_PER_USER


def test_identical_prompt_is_served_from_cache_and_does_not_count(db_session):
    calls = []

    class CountingProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            calls.append(prompt)
            return "https://example.com/generated.png"

    cache = InMemoryCache()
    first = generate_simulation(
        _request(), USER_ID, db_session, provider=CountingProvider(), cache=cache
    )
    second = generate_simulation(
        _request(), USER_ID, db_session, provider=CountingProvider(), cache=cache
    )

    assert len(calls) == 1
    assert second.image_url == first.image_url
    # Only the first (real) generation counted against the daily limit.
    assert second.remaining_today == DAILY_LIMIT_PER_USER - 1


def test_raises_once_daily_limit_is_reached(db_session):
    class FakeProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            return "https://example.com/generated.png"

    # Each call uses a distinct prompt (different location name) so none of
    # them are served from cache — we're testing the limit, not the cache.
    for i in range(DAILY_LIMIT_PER_USER):
        result = generate_simulation(
            _request(location_name=f"Spot {i}"),
            USER_ID,
            db_session,
            provider=FakeProvider(),
            cache=InMemoryCache(),
        )
        assert result.provider_status == "generated"

    try:
        generate_simulation(
            _request(location_name="One too many"),
            USER_ID,
            db_session,
            provider=FakeProvider(),
            cache=InMemoryCache(),
        )
        raise AssertionError("expected ImageLimitExceeded")
    except ImageLimitExceeded:
        pass


def test_global_daily_cap_blocks_even_a_user_under_their_own_limit(db_session, monkeypatch):
    monkeypatch.setattr(simulation_module, "ensure_within_daily_limit", _raise_global_cap)

    class FakeProvider(ImageGenProvider):
        def generate_image(self, prompt: str) -> str:
            return "https://example.com/generated.png"

    try:
        generate_simulation(
            _request(), "a-fresh-user-with-zero-usage", db_session, provider=FakeProvider(),
            cache=InMemoryCache(),
        )
        raise AssertionError("expected ImageLimitExceeded")
    except ImageLimitExceeded:
        pass


def _raise_global_cap(db, user_id, on_date=None):
    raise ImageLimitExceeded("Vesper has hit its daily sky-preview limit across all users.")


def test_simulate_endpoint_requires_authentication():
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

    assert response.status_code == 401


def test_simulate_endpoint_returns_disclaimer_and_prompt(client, monkeypatch):
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
    assert body["remaining_today"] == DAILY_LIMIT_PER_USER


def test_simulate_endpoint_returns_429_when_limit_exceeded(client, monkeypatch):
    def always_exceeded(db, user_id, on_date=None):
        raise ImageLimitExceeded("limit reached")

    monkeypatch.setattr(simulation_module, "ensure_within_daily_limit", always_exceeded)

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

    assert response.status_code == 429


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
