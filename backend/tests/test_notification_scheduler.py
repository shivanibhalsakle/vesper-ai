from datetime import date, datetime

import app.services.notification_scheduler as ns_module
from app.models.saved_profile import SavedProfile
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.schemas.weather import HourlyForecast, WeatherForecast
from app.services.notification_scheduler import rescore_saved_profiles
from app.services.notifications import PushNotifier

TARGET_DATE = date(2026, 7, 27)

STRONG_MATCH_CANDIDATE = LocationRecord(
    id="loc-strong",
    name="Golden Point",
    type=LocationType.ELEVATED_VIEWPOINT,
    lat=40.75,
    lon=-73.98,
    source=LocationSource.OSM,
    distance_km=1.0,
)
WEAK_MATCH_CANDIDATE = LocationRecord(
    id="loc-weak",
    name="Overcast Beach",
    type=LocationType.BEACH,
    lat=40.70,
    lon=-74.00,
    source=LocationSource.OSM,
    distance_km=0.5,
)

FORECAST_BY_LAT = {
    40.75: HourlyForecast(
        time=datetime(2026, 7, 27, 20, 0),
        cloud_cover_low=5,
        cloud_cover_mid=5,
        cloud_cover_high=10,
        visibility=24000,
        uv_index=0,
        precipitation_probability=0,
        weather_code=0,
    ),
    40.70: HourlyForecast(
        time=datetime(2026, 7, 27, 20, 0),
        cloud_cover_low=90,
        cloud_cover_mid=90,
        cloud_cover_high=90,
        visibility=8000,
        uv_index=0,
        precipitation_probability=20,
        weather_code=3,
    ),
}


class FakeNotifier(PushNotifier):
    def __init__(self):
        self.calls = []

    def send_notification(self, token, title, body):
        self.calls.append((token, title, body))


def _make_profile(db_session, **overrides):
    defaults = dict(
        user_id="user-1",
        home_lat=40.70,
        home_lon=-73.99,
        radius_km=5.0,
        place_types=["elevated_viewpoint", "beach"],
        event="sunset",
        tz_name="UTC",
        preference_profile={"golden_orange": 1.0, "clear_sky": 1.0},
        fcm_token="token-1",
        notification_enabled=True,
        match_threshold=0.6,
    )
    defaults.update(overrides)
    profile = SavedProfile(**defaults)
    db_session.add(profile)
    db_session.commit()
    db_session.refresh(profile)
    return profile


def _patch(monkeypatch, candidates):
    def fake_find(lat, lon, radius_km, place_types, client=None, cache=None):
        return candidates

    def fake_forecast(lat, lon, on_date, tz_name="UTC", client=None):
        return WeatherForecast(hourly=[FORECAST_BY_LAT[lat]])

    monkeypatch.setattr(ns_module, "find_candidate_locations", fake_find)
    monkeypatch.setattr(ns_module, "fetch_hourly_forecast", fake_forecast)


def test_sends_notification_for_strong_match(db_session, monkeypatch):
    _patch(monkeypatch, [STRONG_MATCH_CANDIDATE])
    _make_profile(db_session)
    notifier = FakeNotifier()

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=notifier)

    assert results[0]["status"] == "sent"
    assert len(notifier.calls) == 1
    token, title, body = notifier.calls[0]
    assert token == "token-1"
    assert "Golden Point" in title


def test_below_threshold_does_not_notify(db_session, monkeypatch):
    _patch(monkeypatch, [WEAK_MATCH_CANDIDATE])
    _make_profile(db_session, match_threshold=0.6)
    notifier = FakeNotifier()

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=notifier)

    assert results[0]["status"] == "below_threshold"
    assert notifier.calls == []


def test_profile_without_token_is_skipped_before_scoring(db_session, monkeypatch):
    _patch(monkeypatch, [STRONG_MATCH_CANDIDATE])
    _make_profile(db_session, fcm_token=None)
    notifier = FakeNotifier()

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=notifier)

    assert results[0]["status"] == "no_fcm_token"
    assert notifier.calls == []


def test_disabled_profiles_are_excluded_entirely(db_session, monkeypatch):
    _patch(monkeypatch, [STRONG_MATCH_CANDIDATE])
    _make_profile(db_session, notification_enabled=False)
    notifier = FakeNotifier()

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=notifier)

    assert results == []


def test_no_candidates_reports_status(db_session, monkeypatch):
    _patch(monkeypatch, [])
    _make_profile(db_session)
    notifier = FakeNotifier()

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=notifier)

    assert results[0]["status"] == "no_candidates"


def test_notifier_failure_is_reported_not_raised(db_session, monkeypatch):
    _patch(monkeypatch, [STRONG_MATCH_CANDIDATE])
    _make_profile(db_session)

    class BrokenNotifier(PushNotifier):
        def send_notification(self, token, title, body):
            raise RuntimeError("FCM down")

    results = rescore_saved_profiles(db_session, on_date=TARGET_DATE, notifier=BrokenNotifier())

    assert results[0]["status"] == "error"
