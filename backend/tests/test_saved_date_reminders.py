from datetime import date, datetime

import httpx

import app.services.notification_scheduler as ns_module
from app.models.saved_date import SavedDate
from app.models.saved_profile import SavedProfile
from app.models.user_preferences import UserPreferences
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ColorProbabilities, SkyProfile
from app.schemas.session import SunEvent
from app.schemas.sky import Confidence, SkyRequest, SkyResponse
from app.services.notification_scheduler import rescore_saved_profiles
from app.services.notifications import PushNotifier
from app.services.saved_date_reminders import build_reminder, send_saved_date_reminders

TARGET = date(2026, 10, 7)


class FakeNotifier(PushNotifier):
    def __init__(self):
        self.calls = []

    def send_notification(self, token, title, body):
        self.calls.append((token, title, body))


class FailingNotifier(PushNotifier):
    def send_notification(self, token, title, body):
        raise RuntimeError("fcm down")


def _sky(score: float | None = 0.84, alert: str | None = None) -> SkyResponse:
    stamp = datetime(2026, 10, 7, 18, 8)
    return SkyResponse(
        event=SunEvent.SUNSET,
        date=TARGET,
        timezone="America/New_York",
        event_time=stamp,
        event_passed=False,
        recommended_arrival_offset_minutes=-20,
        best_viewing_window_start=stamp,
        best_viewing_window_end=stamp,
        visibility_likelihood=0.9,
        cloud_cover_summary="light cloud cover (high clouds)",
        color_probabilities=ColorProbabilities(pink=0, purple=0, orange=0, red=0, golden=0),
        sky_profile=SkyProfile(
            clear_sky=0.8, dramatic_clouds=0.3, pink_purple=0.3, golden_orange=0.7, red_sky=0.2
        ),
        rain_or_unsafe_alert=alert,
        preference_match_score=score,
        lead_days=1,
        confidence=Confidence.HIGH,
    )


def _saved_date(db, **overrides) -> SavedDate:
    defaults = dict(
        user_id="user-1",
        event_date=TARGET,
        event="sunset",
        lat=40.7,
        lon=-73.99,
        label="Brooklyn Bridge Park",
        saved_score=0.8,
        fcm_token="token-1",
        notification_enabled=True,
    )
    defaults.update(overrides)
    row = SavedDate(**defaults)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _sky_fn(sky=None, seen=None):
    def fn(request: SkyRequest) -> SkyResponse:
        if seen is not None:
            seen.append(request)
        return sky or _sky()

    return fn


def test_sends_a_reminder_for_tomorrows_saved_date(db_session):
    _saved_date(db_session)
    notifier = FakeNotifier()

    results, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=notifier, sky_fn=_sky_fn()
    )

    assert [r["status"] for r in results] == ["sent"]
    assert notified == {"user-1"}
    token, title, body = notifier.calls[0]
    assert token == "token-1"
    assert title == "Sunset tomorrow: Brooklyn Bridge Park"
    assert "84% match" in body


def test_each_date_is_reminded_only_once(db_session):
    row = _saved_date(db_session)
    notifier = FakeNotifier()

    send_saved_date_reminders(db_session, on_date=TARGET, notifier=notifier, sky_fn=_sky_fn())
    again, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=notifier, sky_fn=_sky_fn()
    )

    assert len(notifier.calls) == 1
    assert again == [] and notified == set()
    db_session.refresh(row)
    assert row.notified_at is not None


def test_ignores_other_days_and_muted_dates(db_session):
    _saved_date(db_session, event_date=date(2026, 10, 9))
    _saved_date(db_session, notification_enabled=False)
    notifier = FakeNotifier()

    results, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=notifier, sky_fn=_sky_fn()
    )

    assert results == [] and notified == set()
    assert notifier.calls == []


def test_dates_without_a_device_token_are_reported_not_sent(db_session):
    _saved_date(db_session, fcm_token=None)
    notifier = FakeNotifier()

    results, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=notifier, sky_fn=_sky_fn()
    )

    assert results[0]["status"] == "no_fcm_token"
    assert notified == set()


def test_uses_the_users_saved_sky_preferences(db_session):
    db_session.add(
        UserPreferences(
            user_id="user-1",
            radius_km=10.0,
            place_types=[],
            event="sunset",
            preference_profile=PreferenceProfile(golden_orange=0.9).model_dump(),
        )
    )
    db_session.commit()
    _saved_date(db_session)
    seen: list[SkyRequest] = []

    send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=FakeNotifier(), sky_fn=_sky_fn(seen=seen)
    )

    assert seen[0].preferences.golden_orange == 0.9
    assert seen[0].event == SunEvent.SUNSET
    assert seen[0].date == TARGET


def test_weather_outage_skips_that_date_and_leaves_it_unsent(db_session):
    row = _saved_date(db_session)

    def outage(request):
        raise httpx.ConnectError("down")

    results, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=FakeNotifier(), sky_fn=outage
    )

    assert results[0]["status"] == "data_unavailable"
    assert notified == set()
    db_session.refresh(row)
    assert row.notified_at is None


def test_failed_send_is_not_marked_as_notified(db_session):
    row = _saved_date(db_session)

    results, notified = send_saved_date_reminders(
        db_session, on_date=TARGET, notifier=FailingNotifier(), sky_fn=_sky_fn()
    )

    assert results[0]["status"] == "error"
    assert notified == set()
    db_session.refresh(row)
    assert row.notified_at is None


def test_reminder_text_without_preferences_or_with_rain():
    row = SavedDate(label="Pier 1", event="sunrise")

    _, plain = build_reminder(row, _sky(score=None))
    assert plain == "Light cloud cover (high clouds)."

    title, rainy = build_reminder(row, _sky(alert="60% chance of rain around this time."))
    assert title == "Sunrise tomorrow: Pier 1"
    assert rainy.endswith("60% chance of rain around this time.")


def test_saved_date_users_are_skipped_by_saved_search_alerts(db_session, monkeypatch):
    profile = SavedProfile(
        user_id="user-1",
        home_lat=40.7,
        home_lon=-73.99,
        radius_km=5.0,
        place_types=["park"],
        event="sunset",
        tz_name="auto",
        preference_profile={"golden_orange": 1.0},
        fcm_token="token-1",
        notification_enabled=True,
        match_threshold=0.1,
    )
    db_session.add(profile)
    db_session.commit()
    monkeypatch.setattr(
        ns_module, "find_candidate_locations", lambda *a, **k: (_ for _ in ()).throw(AssertionError)
    )
    notifier = FakeNotifier()

    results = rescore_saved_profiles(
        db_session, on_date=TARGET, notifier=notifier, skip_user_ids={"user-1"}
    )

    assert results == [{"profile_id": profile.id, "status": "skipped_saved_date_priority"}]
    assert notifier.calls == []
