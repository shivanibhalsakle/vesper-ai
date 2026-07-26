from datetime import datetime

from fastapi.testclient import TestClient

import app.api.trip_window as tw_api_module
import app.services.trip_window as tw_service_module
from app.main import app
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.weather import HourlyForecast, WeatherForecast

client = TestClient(app)

CANDIDATE = LocationRecord(
    id="loc-1",
    name="Test Point",
    type=LocationType.ELEVATED_VIEWPOINT,
    lat=40.75,
    lon=-73.98,
    source=LocationSource.OSM,
    distance_km=1.0,
)

# Three days of forecast for the one candidate: day 1 and 3 overcast, day 2 clear.
MULTI_DAY_FORECAST = WeatherForecast(
    hourly=[
        HourlyForecast(
            time=datetime(2026, 7, 25, 20, 0),
            cloud_cover_low=90,
            cloud_cover_mid=90,
            cloud_cover_high=90,
            visibility=8000,
            uv_index=0,
            precipitation_probability=10,
            weather_code=3,
        ),
        HourlyForecast(
            time=datetime(2026, 7, 26, 20, 0),
            cloud_cover_low=5,
            cloud_cover_mid=5,
            cloud_cover_high=10,
            visibility=24000,
            uv_index=0,
            precipitation_probability=0,
            weather_code=0,
        ),
        HourlyForecast(
            time=datetime(2026, 7, 27, 20, 0),
            cloud_cover_low=90,
            cloud_cover_mid=90,
            cloud_cover_high=90,
            visibility=8000,
            uv_index=0,
            precipitation_probability=10,
            weather_code=3,
        ),
    ]
)

fetch_calls: list[dict] = []


def fake_find_candidate_locations(lat, lon, radius_km, place_types, client=None, cache=None):
    return [CANDIDATE]


def fake_fetch_hourly_forecast(lat, lon, on_date, tz_name="UTC", end_date=None, client=None):
    fetch_calls.append({"lat": lat, "on_date": on_date, "end_date": end_date})
    return MULTI_DAY_FORECAST


def fake_generate_explanation(location, score, preferences, client=None):
    return f"Fake explanation for {location.name}"


def _patch(monkeypatch):
    fetch_calls.clear()
    monkeypatch.setattr(
        tw_service_module, "find_candidate_locations", fake_find_candidate_locations
    )
    monkeypatch.setattr(tw_service_module, "fetch_hourly_forecast", fake_fetch_hourly_forecast)
    monkeypatch.setattr(tw_api_module, "generate_explanation", fake_generate_explanation)


def _request_body(**overrides):
    body = {
        "lat": 40.70,
        "lon": -73.99,
        "event": "sunset",
        "start_date": "2026-07-25",
        "end_date": "2026-07-27",
        "radius_km": 5.0,
        "place_types": ["elevated_viewpoint"],
        "preferences": {"clear_sky": 1.0},
        # A real local tz keeps each day's event time in the evening of that
        # same calendar day, matching the fixture's per-day "20:00" markers.
        # With tz_name="UTC", a western-hemisphere sunset lands in the early
        # UTC hours of the *same* day, shifting nearest-hour matching by a day.
        "tz_name": "America/New_York",
    }
    body.update(overrides)
    return body


def test_trip_window_picks_best_day_within_range(monkeypatch):
    _patch(monkeypatch)

    response = client.post("/trip-window", json=_request_body())
    body = response.json()

    assert response.status_code == 200
    assert body["best"]["date"] == "2026-07-26"
    assert body["best"]["name"] == "Test Point"
    assert body["days_considered"] == 3
    assert body["candidates_considered"] == 1


def test_trip_window_fetches_weather_once_per_candidate_not_per_day(monkeypatch):
    _patch(monkeypatch)

    client.post("/trip-window", json=_request_body())

    assert len(fetch_calls) == 1
    assert fetch_calls[0]["on_date"].isoformat() == "2026-07-25"
    assert fetch_calls[0]["end_date"].isoformat() == "2026-07-27"


def test_trip_window_includes_explanation(monkeypatch):
    _patch(monkeypatch)

    response = client.post("/trip-window", json=_request_body())
    body = response.json()

    assert body["best"]["explanation"] == "Fake explanation for Test Point"


def test_trip_window_returns_none_best_when_no_candidates(monkeypatch):
    monkeypatch.setattr(tw_service_module, "find_candidate_locations", lambda *a, **k: [])
    monkeypatch.setattr(tw_service_module, "fetch_hourly_forecast", fake_fetch_hourly_forecast)
    monkeypatch.setattr(tw_api_module, "generate_explanation", fake_generate_explanation)

    response = client.post("/trip-window", json=_request_body())
    body = response.json()

    assert response.status_code == 200
    assert body["best"] is None
    assert body["candidates_considered"] == 0


def test_end_date_before_start_date_is_rejected():
    response = client.post(
        "/trip-window",
        json=_request_body(start_date="2026-07-27", end_date="2026-07-25"),
    )

    assert response.status_code == 422


def test_trip_window_longer_than_max_is_rejected():
    response = client.post(
        "/trip-window",
        json=_request_body(start_date="2026-07-01", end_date="2026-07-20"),
    )

    assert response.status_code == 422
