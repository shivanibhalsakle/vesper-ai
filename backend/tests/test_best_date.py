from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import httpx
import pytest
from fastapi.testclient import TestClient

import app.api.best_date as bd_api
import app.services.best_date as bd
from app.main import app
from app.schemas.best_date import BestDateRequest, DayScore
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent
from app.schemas.sky import Confidence
from app.schemas.weather import HourlyForecast, WeatherForecast
from app.services.best_date import find_best_dates, pick_best_day
from app.services.places import PlaceDataUnavailable

NY = ZoneInfo("America/New_York")
START = date(2026, 10, 5)
MORNING = datetime(2026, 10, 5, 9, 0, tzinfo=NY)

SPOT = LocationRecord(
    id="osm-1",
    name="Brooklyn Bridge Park",
    type=LocationType.WATERFRONT,
    lat=40.70,
    lon=-73.99,
    source=LocationSource.OSM,
    distance_km=1.0,
)
OTHER_SPOT = SPOT.model_copy(update={"id": "osm-2", "name": "Pier 1", "lat": 40.71})

GOOD = dict(low=0, mid=40, high=40)
BAD = dict(low=100, mid=100, high=100)


def _day(on_date: date, sky: dict) -> list[HourlyForecast]:
    return [
        HourlyForecast(
            time=datetime(on_date.year, on_date.month, on_date.day, hour),
            cloud_cover_low=sky["low"],
            cloud_cover_mid=sky["mid"],
            cloud_cover_high=sky["high"],
            visibility=24000,
            uv_index=0,
            precipitation_probability=0,
            weather_code=0,
        )
        for hour in range(24)
    ]


def _forecast(skies: list[dict]) -> WeatherForecast:
    hours = []
    for offset, sky in enumerate(skies):
        hours += _day(START + timedelta(days=offset), sky)
    return WeatherForecast(hourly=hours, timezone="America/New_York")


def _patch(monkeypatch, skies, spots=(SPOT,), forecasts=None):
    calls = []

    def fake_forecast(lat, lon, on_date, tz_name="UTC", end_date=None, **kwargs):
        calls.append((lat, tz_name, on_date, end_date))
        if forecasts is not None:
            return forecasts[lat]
        return _forecast(skies)

    monkeypatch.setattr(bd, "find_candidate_locations", lambda *args, **kwargs: list(spots))
    monkeypatch.setattr(bd, "fetch_hourly_forecast", fake_forecast)
    return calls


def _request(**overrides) -> BestDateRequest:
    body = dict(
        lat=40.7,
        lon=-73.99,
        event=SunEvent.SUNSET,
        start_date=START,
        days=3,
        preferences=PreferenceProfile(clear_sky=1.0, golden_orange=1.0),
    )
    body.update(overrides)
    return BestDateRequest(**body)


def test_picks_the_clearer_day(monkeypatch):
    _patch(monkeypatch, [BAD, GOOD, BAD])

    result = find_best_dates(_request(), now=MORNING)

    assert [d.date for d in result.days] == [START + timedelta(days=i) for i in range(3)]
    assert result.best.date == START + timedelta(days=1)
    assert result.best.sky.preference_match_score == pytest.approx(
        next(d for d in result.days if d.date == result.best.date).score
    )


def test_exact_ties_go_to_the_earliest_day(monkeypatch):
    _patch(monkeypatch, [GOOD, GOOD, GOOD])

    result = find_best_dates(_request(), now=MORNING)

    assert result.best.date == START


def test_forecast_is_fetched_once_per_spot_for_the_whole_range(monkeypatch):
    calls = _patch(monkeypatch, [GOOD, GOOD, GOOD], spots=(SPOT, OTHER_SPOT))

    find_best_dates(_request(), now=MORNING)

    assert len(calls) == 2
    assert all(c[2] == START and c[3] == START + timedelta(days=2) for c in calls)
    assert all(c[1] == "auto" for c in calls)


def test_each_day_reports_its_best_spot(monkeypatch):
    forecasts = {40.70: _forecast([GOOD, BAD, BAD]), 40.71: _forecast([BAD, GOOD, BAD])}
    _patch(monkeypatch, [], spots=(SPOT, OTHER_SPOT), forecasts=forecasts)

    result = find_best_dates(_request(), now=MORNING)

    by_date = {d.date: d for d in result.days}
    assert by_date[START].spot_name == "Brooklyn Bridge Park"
    assert by_date[START + timedelta(days=1)].spot_name == "Pier 1"


def test_today_is_skipped_once_the_event_has_passed(monkeypatch):
    _patch(monkeypatch, [GOOD, BAD, BAD])
    late = datetime(2026, 10, 5, 22, 0, tzinfo=NY)

    result = find_best_dates(_request(), now=late)

    assert START not in [d.date for d in result.days]
    assert result.best.date == START + timedelta(days=1)


def test_falls_back_to_the_searched_point_when_there_are_no_spots(monkeypatch):
    _patch(monkeypatch, [GOOD, BAD, BAD], spots=())

    result = find_best_dates(_request(), now=MORNING)

    assert result.spots_considered == 0
    assert result.best.spot is None
    assert result.best.date == START


def test_lead_time_sets_each_days_confidence(monkeypatch):
    _patch(monkeypatch, [GOOD] * 7)

    result = find_best_dates(_request(days=7), now=MORNING)

    confidences = [d.confidence for d in result.days]
    assert confidences[0] == Confidence.HIGH
    assert confidences[-1] == Confidence.LOW


def test_returns_the_best_days_sky_details(monkeypatch):
    _patch(monkeypatch, [BAD, GOOD, BAD])

    sky = find_best_dates(_request(), now=MORNING).best.sky

    assert sky.date == START + timedelta(days=1)
    assert sky.timezone == "America/New_York"
    assert sky.lead_days == 1
    assert sky.sky_profile.clear_sky > 0.5


def _tie(on_day: int, score: float) -> DayScore:
    return DayScore(
        date=START + timedelta(days=on_day), score=score, confidence=Confidence.HIGH, spot_name=None
    )


def test_near_ties_prefer_the_earlier_day():
    days = [_tie(0, 0.80), _tie(1, 0.81), _tie(2, 0.90)]
    assert pick_best_day(days).date == START + timedelta(days=2)

    days = [_tie(0, 0.80), _tie(1, 0.81), _tie(2, 0.815)]
    assert pick_best_day(days).date == START


def test_pick_best_day_handles_no_days():
    assert pick_best_day([]) is None


# --- HTTP layer ---


def _body(**overrides):
    body = {
        "lat": 40.7,
        "lon": -73.99,
        "event": "sunset",
        "start_date": "2026-10-05",
        "days": 3,
        "preferences": {"golden_orange": 1.0},
    }
    body.update(overrides)
    return body


def test_endpoint_returns_a_best_date(client, monkeypatch):
    _patch(monkeypatch, [GOOD, GOOD, GOOD])
    # Pin "now" so the test doesn't depend on the date it runs on.
    monkeypatch.setattr(
        bd_api, "find_best_dates", lambda request: find_best_dates(request, now=MORNING)
    )

    response = client.post("/best-date", json=_body())

    assert response.status_code == 200
    body = response.json()
    assert body["best"]["sky"]["sky_profile"]
    assert len(body["days"]) == 3


def test_endpoint_requires_a_sky_preference(client):
    response = client.post(
        "/best-date", json=_body(preferences={"silhouettes": 1.0})
    )

    assert response.status_code == 422


def test_endpoint_maps_outages_to_503(client, monkeypatch):
    def place_outage(*args, **kwargs):
        raise PlaceDataUnavailable("down")

    monkeypatch.setattr(bd, "find_candidate_locations", place_outage)
    assert client.post("/best-date", json=_body()).status_code == 503

    monkeypatch.setattr(bd, "find_candidate_locations", lambda *a, **k: [SPOT])

    def weather_outage(*args, **kwargs):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(bd, "fetch_hourly_forecast", weather_outage)
    assert client.post("/best-date", json=_body()).status_code == 503


def test_endpoint_validates_the_day_count(client):
    assert client.post("/best-date", json=_body(days=0)).status_code == 422
    assert client.post("/best-date", json=_body(days=40)).status_code == 422


def test_endpoint_requires_authentication():
    response = TestClient(app).post("/best-date", json=_body())

    assert response.status_code == 401
