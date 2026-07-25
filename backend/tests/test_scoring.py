from datetime import datetime

from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import CloudEffect
from app.schemas.weather import HourlyForecast
from app.services.scoring import score_location

EVENT_TIME = datetime(2026, 7, 25, 20, 18)


def _hour(**overrides) -> HourlyForecast:
    defaults = dict(
        time=EVENT_TIME,
        cloud_cover_low=5,
        cloud_cover_mid=5,
        cloud_cover_high=10,
        visibility=24000,
        uv_index=0,
        precipitation_probability=0,
        weather_code=0,
    )
    defaults.update(overrides)
    return HourlyForecast(**defaults)


def test_clear_sky_scenario_favors_clear_sky_preference():
    forecast = [_hour()]
    preferences = PreferenceProfile(clear_sky=1.0)

    result = score_location(EVENT_TIME, forecast, preferences)

    assert result.internal_cloud_effect == CloudEffect.NEUTRAL
    assert result.preference_match_score > 0.8
    assert result.visibility_likelihood > 0.9
    assert result.rain_or_unsafe_alert is None


def test_dramatic_clouds_scenario_enhances_and_recommends_late_arrival():
    forecast = [_hour(cloud_cover_low=10, cloud_cover_mid=50, cloud_cover_high=60, weather_code=2)]
    preferences = PreferenceProfile(dramatic_clouds=1.0)

    result = score_location(EVENT_TIME, forecast, preferences)

    assert result.internal_cloud_effect == CloudEffect.ENHANCES
    assert result.recommended_arrival_offset_minutes == 5
    assert result.best_viewing_window_end > EVENT_TIME
    assert result.preference_match_score > 0.7


def test_overcast_scenario_blocks_and_recommends_early_arrival():
    forecast = [
        _hour(
            cloud_cover_low=90,
            cloud_cover_mid=90,
            cloud_cover_high=90,
            visibility=8000,
            precipitation_probability=20,
            weather_code=3,
        )
    ]
    preferences = PreferenceProfile(clear_sky=1.0)

    result = score_location(EVENT_TIME, forecast, preferences)

    assert result.internal_cloud_effect == CloudEffect.BLOCKS
    assert result.recommended_arrival_offset_minutes == -25
    assert result.best_viewing_window_end == EVENT_TIME
    assert result.preference_match_score < 0.3
    assert result.visibility_likelihood < 0.2


def test_rain_scenario_raises_alert():
    forecast = [
        _hour(
            cloud_cover_low=80,
            cloud_cover_mid=80,
            cloud_cover_high=80,
            visibility=5000,
            precipitation_probability=70,
            weather_code=61,
        )
    ]
    preferences = PreferenceProfile(clear_sky=1.0)

    result = score_location(EVENT_TIME, forecast, preferences)

    assert result.rain_or_unsafe_alert is not None
    assert "rain" in result.rain_or_unsafe_alert.lower() or "storm" in result.rain_or_unsafe_alert.lower()


def test_no_sky_preferences_returns_neutral_match_score():
    forecast = [_hour()]
    preferences = PreferenceProfile()

    result = score_location(EVENT_TIME, forecast, preferences)

    assert result.preference_match_score == 0.5


def test_nearest_hour_is_selected_from_multiple_candidates():
    far_hour = _hour(time=datetime(2026, 7, 25, 12, 0), cloud_cover_low=99)
    near_hour = _hour(time=datetime(2026, 7, 25, 20, 0), cloud_cover_low=5)
    forecast = [far_hour, near_hour]
    preferences = PreferenceProfile(clear_sky=1.0)

    result = score_location(EVENT_TIME, forecast, preferences)

    # If the far, heavily-clouded hour had been picked, this would score low.
    assert result.preference_match_score > 0.8
