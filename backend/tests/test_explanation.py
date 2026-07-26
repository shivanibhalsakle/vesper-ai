from datetime import datetime

from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import CloudEffect, ColorProbabilities, ScoringResult
from app.services.explanation import generate_explanation

LOCATION = LocationRecord(
    id="osm:node/1",
    name="Brooklyn Bridge Park",
    type=LocationType.WATERFRONT,
    lat=40.7003,
    lon=-73.9967,
    source=LocationSource.OSM,
    distance_km=0.5,
)

SCORE = ScoringResult(
    visibility_likelihood=0.9,
    color_probabilities=ColorProbabilities(pink=0.3, purple=0.2, orange=0.8, red=0.2, golden=0.85),
    cloud_cover_summary="mostly clear skies",
    preference_match_score=0.75,
    best_viewing_window_start=datetime(2026, 7, 25, 19, 58),
    best_viewing_window_end=datetime(2026, 7, 25, 20, 38),
    recommended_arrival_offset_minutes=-20,
    rain_or_unsafe_alert=None,
    internal_cloud_effect=CloudEffect.NEUTRAL,
)

PREFERENCES = PreferenceProfile(golden_orange=1.0, dramatic_clouds=0.4)


class _FakeTextBlock:
    def __init__(self, text: str):
        self.type = "text"
        self.text = text


class _FakeMessage:
    def __init__(self, text: str):
        self.content = [_FakeTextBlock(text)]


class _FakeMessages:
    def __init__(self, response_text: str):
        self.response_text = response_text
        self.calls: list[dict] = []

    def create(self, model, max_tokens, messages):
        self.calls.append({"model": model, "max_tokens": max_tokens, "messages": messages})
        return _FakeMessage(self.response_text)


class _FakeClient:
    def __init__(self, response_text: str = "You'll love the golden light here!  "):
        self.messages = _FakeMessages(response_text)


def test_generate_explanation_returns_stripped_text_from_response():
    client = _FakeClient(response_text="  Golden light expected, matching your taste.  ")

    result = generate_explanation(LOCATION, SCORE, PREFERENCES, client=client)

    assert result == "Golden light expected, matching your taste."


def test_prompt_includes_location_and_forecast_context_not_internal_jargon():
    client = _FakeClient()

    generate_explanation(LOCATION, SCORE, PREFERENCES, client=client)

    prompt = client.messages.calls[0]["messages"][0]["content"]
    assert "Brooklyn Bridge Park" in prompt
    assert "mostly clear skies" in prompt
    assert "golden/orange light" in prompt
    # Internal-only fields must never leak into the prompt as raw jargon
    assert "CloudEffect" not in prompt
    assert "NEUTRAL" not in prompt
    assert "internal_cloud_effect" not in prompt


def test_prompt_omits_preferences_with_zero_weight():
    client = _FakeClient()
    preferences = PreferenceProfile(golden_orange=1.0)  # everything else 0

    generate_explanation(LOCATION, SCORE, preferences, client=client)

    prompt = client.messages.calls[0]["messages"][0]["content"]
    assert "golden/orange light" in prompt
    assert "red skies" not in prompt
    assert "pink/purple" not in prompt


def test_uses_claude_opus_model():
    client = _FakeClient()

    generate_explanation(LOCATION, SCORE, PREFERENCES, client=client)

    assert client.messages.calls[0]["model"] == "claude-opus-4-8"
