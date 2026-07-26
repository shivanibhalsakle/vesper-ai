from datetime import datetime

from fastapi.testclient import TestClient

import app.api.session as session_module
from app.main import app
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.weather import HourlyForecast, WeatherForecast

client = TestClient(app)

CANDIDATES = [
    LocationRecord(
        id="loc-clear",
        name="Clear Park",
        type=LocationType.PARK,
        lat=40.75,
        lon=-73.98,
        source=LocationSource.OSM,
        distance_km=1.0,
    ),
    LocationRecord(
        id="loc-dramatic",
        name="Dramatic Point",
        type=LocationType.ELEVATED_VIEWPOINT,
        lat=40.76,
        lon=-73.97,
        source=LocationSource.OSM,
        distance_km=2.0,
    ),
    LocationRecord(
        id="loc-overcast",
        name="Overcast Beach",
        type=LocationType.BEACH,
        lat=40.70,
        lon=-74.00,
        source=LocationSource.OSM,
        distance_km=0.5,  # physically closest, but should rank last on score
    ),
]

FORECAST_BY_LAT = {
    40.75: HourlyForecast(
        time=datetime(2026, 7, 25, 20, 0),
        cloud_cover_low=5,
        cloud_cover_mid=5,
        cloud_cover_high=10,
        visibility=24000,
        uv_index=0,
        precipitation_probability=0,
        weather_code=0,
    ),
    40.76: HourlyForecast(
        time=datetime(2026, 7, 25, 20, 0),
        cloud_cover_low=10,
        cloud_cover_mid=50,
        cloud_cover_high=60,
        visibility=20000,
        uv_index=0,
        precipitation_probability=5,
        weather_code=2,
    ),
    40.70: HourlyForecast(
        time=datetime(2026, 7, 25, 20, 0),
        cloud_cover_low=90,
        cloud_cover_mid=90,
        cloud_cover_high=90,
        visibility=8000,
        uv_index=0,
        precipitation_probability=20,
        weather_code=3,
    ),
}


def fake_find_candidate_locations(lat, lon, radius_km, place_types, client=None, cache=None):
    return CANDIDATES


def fake_fetch_hourly_forecast(lat, lon, on_date, tz_name="UTC", client=None):
    return WeatherForecast(hourly=[FORECAST_BY_LAT[lat]])


def fake_generate_explanation(location, score, preferences, client=None):
    return f"Fake explanation for {location.name}"


def _patch_network(monkeypatch):
    monkeypatch.setattr(session_module, "find_candidate_locations", fake_find_candidate_locations)
    monkeypatch.setattr(session_module, "fetch_hourly_forecast", fake_fetch_hourly_forecast)
    monkeypatch.setattr(session_module, "generate_explanation", fake_generate_explanation)


def _request_body(**overrides):
    body = {
        "lat": 40.70,
        "lon": -73.99,
        "event": "sunset",
        "date": "2026-07-25",
        "radius_km": 5.0,
        "place_types": ["park", "elevated_viewpoint", "beach"],
        "preferences": {
            "dramatic_clouds": 1.0,
            "pink_purple": 1.0,
            "golden_orange": 1.0,
            "red_sky": 1.0,
        },
    }
    body.update(overrides)
    return body


def test_session_ranks_by_preference_match_not_distance(monkeypatch):
    _patch_network(monkeypatch)

    response = client.post("/session", json=_request_body())

    assert response.status_code == 200
    recommendations = response.json()["recommendations"]
    names = [r["name"] for r in recommendations]

    assert names[0] == "Dramatic Point"  # best match despite being 2km out
    assert names[-1] == "Overcast Beach"  # closest, but worst sky match


def test_session_response_excludes_internal_cloud_effect(monkeypatch):
    _patch_network(monkeypatch)

    response = client.post("/session", json=_request_body())
    body = response.json()

    for result in body["recommendations"]:
        assert "internal_cloud_effect" not in result
        assert "cloud_effect" not in result


def test_session_caps_results_at_five(monkeypatch):
    many_candidates = [
        LocationRecord(
            id=f"loc-{i}",
            name=f"Spot {i}",
            type=LocationType.PARK,
            lat=40.75,
            lon=-73.98,
            source=LocationSource.OSM,
            distance_km=float(i),
        )
        for i in range(7)
    ]
    monkeypatch.setattr(
        session_module,
        "find_candidate_locations",
        lambda *a, **k: many_candidates,
    )
    monkeypatch.setattr(session_module, "fetch_hourly_forecast", fake_fetch_hourly_forecast)
    monkeypatch.setattr(session_module, "generate_explanation", fake_generate_explanation)

    response = client.post("/session", json=_request_body())

    assert len(response.json()["recommendations"]) == 5


def test_session_surfaces_rain_alert_separately(monkeypatch):
    _patch_network(monkeypatch)

    response = client.post("/session", json=_request_body())
    body = response.json()

    overcast = next(r for r in body["recommendations"] if r["name"] == "Overcast Beach")
    assert overcast["rain_or_unsafe_alert"] is None  # 20% precip, below alert threshold
    assert overcast["visibility_likelihood"] < 0.2


def test_session_populates_explanation_for_returned_locations_only(monkeypatch):
    _patch_network(monkeypatch)

    response = client.post("/session", json=_request_body())
    body = response.json()

    for result in body["recommendations"]:
        assert result["explanation"] == f"Fake explanation for {result['name']}"


def test_session_explanation_failure_does_not_break_the_request(monkeypatch):
    _patch_network(monkeypatch)

    def failing_explanation(location, score, preferences, client=None):
        raise RuntimeError("Claude API unavailable")

    monkeypatch.setattr(session_module, "generate_explanation", failing_explanation)

    response = client.post("/session", json=_request_body())
    body = response.json()

    assert response.status_code == 200
    assert all(r["explanation"] is None for r in body["recommendations"])
