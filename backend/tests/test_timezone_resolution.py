"""Regression tests for the "everything is UTC" bug: clients send no timezone,
so the backend must use the place's own zone (resolved by the forecast
provider) for sun times, never silently fall back to UTC.
"""

from datetime import datetime

from fastapi.testclient import TestClient

import app.api.session as session_module
import app.api.trip_window as tw_api_module
import app.services.trip_window as tw_service_module
from app.main import app
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.weather import HourlyForecast, WeatherForecast
from app.services.timezones import resolve_timezone

client = TestClient(app)

LOS_ANGELES = LocationRecord(
    id="loc-la",
    name="Santa Monica Pier",
    type=LocationType.WATERFRONT,
    lat=34.0089,
    lon=-118.4973,
    source=LocationSource.OSM,
    distance_km=1.0,
)


def _forecast(timezone: str | None) -> WeatherForecast:
    # Local-evening hours on 2026-07-25 and the next two days.
    hours = [
        HourlyForecast(
            time=datetime(2026, 7, day, 20, 0),
            cloud_cover_low=5,
            cloud_cover_mid=20,
            cloud_cover_high=20,
            visibility=24000,
            uv_index=0,
            precipitation_probability=0,
            weather_code=0,
        )
        for day in (25, 26, 27)
    ]
    return WeatherForecast(hourly=hours, timezone=timezone)


def _patch(monkeypatch, timezone: str | None = "America/Los_Angeles") -> list[str]:
    requested: list[str] = []

    def fake_forecast(lat, lon, on_date, tz_name="UTC", end_date=None, client=None, cache=None):
        requested.append(tz_name)
        return _forecast(timezone)

    monkeypatch.setattr(
        session_module, "find_candidate_locations", lambda *args, **kwargs: [LOS_ANGELES]
    )
    monkeypatch.setattr(session_module, "fetch_hourly_forecast", fake_forecast)
    monkeypatch.setattr(session_module, "generate_explanation", lambda *args, **kwargs: "ok")
    monkeypatch.setattr(
        tw_service_module, "find_candidate_locations", lambda *args, **kwargs: [LOS_ANGELES]
    )
    monkeypatch.setattr(tw_service_module, "fetch_hourly_forecast", fake_forecast)
    monkeypatch.setattr(tw_api_module, "generate_explanation", lambda *args, **kwargs: "ok")
    return requested


def test_resolve_timezone_prefers_the_forecasts_zone_for_auto():
    assert resolve_timezone("auto", _forecast("Asia/Tokyo")) == "Asia/Tokyo"


def test_resolve_timezone_falls_back_to_utc_only_when_unresolved():
    assert resolve_timezone("auto", _forecast(None)) == "UTC"


def test_resolve_timezone_keeps_an_explicit_zone():
    assert resolve_timezone("Europe/London", _forecast("Asia/Tokyo")) == "Europe/London"


def test_session_defaults_to_the_places_own_timezone(monkeypatch):
    requested = _patch(monkeypatch)

    response = client.post(
        "/session",
        json={
            "lat": 34.0089,
            "lon": -118.4973,
            "event": "sunset",
            "date": "2026-07-25",
            "radius_km": 5.0,
            "place_types": ["waterfront"],
        },
    )

    assert response.status_code == 200
    assert requested == ["auto"]
    event_time = response.json()["recommendations"][0]["event_time"]
    # Los Angeles in July is UTC-7, and sunset is in the evening local time.
    assert event_time.endswith("-07:00")
    assert 19 <= int(event_time[11:13]) <= 20


def test_trip_window_defaults_to_the_places_own_timezone(monkeypatch):
    requested = _patch(monkeypatch)

    response = client.post(
        "/trip-window",
        json={
            "lat": 34.0089,
            "lon": -118.4973,
            "event": "sunset",
            "start_date": "2026-07-25",
            "end_date": "2026-07-27",
            "radius_km": 5.0,
            "place_types": ["waterfront"],
            "preferences": {"clear_sky": 1.0},
        },
    )

    assert response.status_code == 200
    assert requested == ["auto"]
    event_time = response.json()["best"]["event_time"]
    assert event_time.endswith("-07:00")
    assert 19 <= int(event_time[11:13]) <= 20
