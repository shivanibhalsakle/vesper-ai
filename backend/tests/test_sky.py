from datetime import date, datetime
from zoneinfo import ZoneInfo

import httpx
import pytest
from fastapi.testclient import TestClient

import app.services.sky as sky_service
from app.main import app
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent
from app.schemas.sky import Confidence, SkyRequest
from app.schemas.weather import HourlyForecast, WeatherForecast
from app.services.sky import confidence_for_lead_days, sky_at

NY = ZoneInfo("America/New_York")
SUNSET_DAY = date(2026, 10, 5)


def _hour(hour: int, low=5.0, mid=40.0, high=40.0, code=1, rain=0.0) -> HourlyForecast:
    return HourlyForecast(
        time=datetime(2026, 10, 5, hour),
        cloud_cover_low=low,
        cloud_cover_mid=mid,
        cloud_cover_high=high,
        visibility=24000,
        uv_index=0,
        precipitation_probability=rain,
        weather_code=code,
    )


@pytest.fixture()
def forecast_calls(monkeypatch):
    calls = []

    def fake_fetch(lat, lon, on_date, tz_name="UTC", **kwargs):
        calls.append(tz_name)
        return WeatherForecast(
            hourly=[_hour(h) for h in range(24)], timezone="America/New_York"
        )

    monkeypatch.setattr(sky_service, "fetch_hourly_forecast", fake_fetch)
    return calls


def _request(**overrides) -> SkyRequest:
    body = dict(lat=40.7, lon=-74.0, event=SunEvent.SUNSET, date=SUNSET_DAY)
    body.update(overrides)
    return SkyRequest(**body)


def test_auto_timezone_uses_the_zone_the_forecast_resolved(forecast_calls):
    response = sky_at(_request(), now=datetime(2026, 10, 5, 9, 0, tzinfo=NY))

    assert forecast_calls == ["auto"]
    assert response.timezone == "America/New_York"
    # Early-October sunset in New York is early evening local time, not UTC.
    assert response.event_time.utcoffset().total_seconds() == -4 * 3600
    assert 17 <= response.event_time.hour <= 19


def test_explicit_timezone_is_respected(forecast_calls):
    response = sky_at(
        _request(tz_name="America/Los_Angeles"), now=datetime(2026, 10, 5, 9, 0, tzinfo=NY)
    )

    assert response.timezone == "America/Los_Angeles"


def test_sky_profile_is_returned_in_slider_terms(forecast_calls):
    response = sky_at(_request(), now=datetime(2026, 10, 5, 9, 0, tzinfo=NY))

    profile = response.sky_profile.model_dump()
    assert set(profile) == {
        "clear_sky", "dramatic_clouds", "pink_purple", "golden_orange", "red_sky"
    }
    assert all(0.0 <= value <= 1.0 for value in profile.values())


def test_match_score_only_present_when_user_has_sky_preferences(forecast_calls):
    now = datetime(2026, 10, 5, 9, 0, tzinfo=NY)

    assert sky_at(_request(), now=now).preference_match_score is None
    assert (
        sky_at(_request(preferences=PreferenceProfile()), now=now).preference_match_score
        is None
    )
    # Composition-only preferences don't count as a sky preference.
    assert (
        sky_at(
            _request(preferences=PreferenceProfile(silhouettes=1.0)), now=now
        ).preference_match_score
        is None
    )
    scored = sky_at(_request(preferences=PreferenceProfile(golden_orange=1.0)), now=now)
    assert 0.0 <= scored.preference_match_score <= 1.0


def test_event_passed_flag(forecast_calls):
    morning = sky_at(_request(), now=datetime(2026, 10, 5, 9, 0, tzinfo=NY))
    night = sky_at(_request(), now=datetime(2026, 10, 5, 23, 0, tzinfo=NY))

    assert morning.event_passed is False
    assert night.event_passed is True


def test_lead_time_drives_confidence(forecast_calls):
    now = datetime(2026, 10, 5, 9, 0, tzinfo=NY)

    today = sky_at(_request(), now=now)
    later = sky_at(_request(date=date(2026, 10, 10)), now=now)

    assert (today.lead_days, today.confidence) == (0, Confidence.HIGH)
    assert (later.lead_days, later.confidence) == (5, Confidence.LOW)


@pytest.mark.parametrize(
    "lead_days,expected",
    [(0, Confidence.HIGH), (1, Confidence.HIGH), (2, Confidence.MEDIUM),
     (3, Confidence.MEDIUM), (4, Confidence.LOW), (7, Confidence.LOW)],
)
def test_confidence_buckets(lead_days, expected):
    assert confidence_for_lead_days(lead_days) == expected


def test_endpoint_returns_the_sky(client, forecast_calls):
    response = client.post(
        "/sky",
        json={"lat": 40.7, "lon": -74.0, "event": "sunset", "date": "2026-10-05"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["timezone"] == "America/New_York"
    assert body["confidence"] in {"high", "medium", "low"}
    assert body["preference_match_score"] is None


def test_endpoint_maps_weather_outage_to_503(client, monkeypatch):
    def boom(*args, **kwargs):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(sky_service, "fetch_hourly_forecast", boom)

    response = client.post(
        "/sky",
        json={"lat": 40.7, "lon": -74.0, "event": "sunset", "date": "2026-10-05"},
    )

    assert response.status_code == 503


def test_endpoint_validates_coordinates(client):
    response = client.post(
        "/sky", json={"lat": 400, "lon": 0, "event": "sunset", "date": "2026-10-05"}
    )

    assert response.status_code == 422


def test_endpoint_requires_authentication():
    response = TestClient(app).post(
        "/sky", json={"lat": 40.7, "lon": -74.0, "event": "sunset", "date": "2026-10-05"}
    )

    assert response.status_code == 401
