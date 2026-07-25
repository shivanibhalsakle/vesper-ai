from datetime import date, timedelta

from app.services.astronomy import get_sun_events, get_sun_position

NYC_LAT, NYC_LON = 40.7128, -74.0060


def test_get_sun_events_orders_events_correctly():
    events = get_sun_events(NYC_LAT, NYC_LON, date(2026, 7, 25), tz_name="America/New_York")

    assert events.dawn < events.sunrise < events.noon < events.sunset < events.dusk


def test_get_sun_events_matches_known_nyc_sunset_time():
    # Reference: NYC sunset on 2026-07-25 is ~8:18 PM local time.
    events = get_sun_events(NYC_LAT, NYC_LON, date(2026, 7, 25), tz_name="America/New_York")

    expected = events.sunset.replace(hour=20, minute=18, second=0, microsecond=0)
    assert abs(events.sunset - expected) < timedelta(minutes=2)


def test_get_sun_position_at_sunset_is_near_horizon():
    events = get_sun_events(NYC_LAT, NYC_LON, date(2026, 7, 25), tz_name="America/New_York")
    position = get_sun_position(NYC_LAT, NYC_LON, events.sunset)

    assert -1.0 < position.elevation < 1.0
    assert 0 <= position.azimuth <= 360
