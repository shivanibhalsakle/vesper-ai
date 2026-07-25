import math
from datetime import datetime, timedelta

from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import CloudEffect, ColorProbabilities, ScoringResult
from app.schemas.weather import HourlyForecast

# WMO weather codes (as used by Open-Meteo) that indicate rain, snow, or storms.
UNSAFE_WEATHER_CODES = {51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99}
RAIN_PROBABILITY_ALERT_THRESHOLD = 40.0


def score_location(
    event_time: datetime,
    hourly_forecast: list[HourlyForecast],
    preferences: PreferenceProfile,
) -> ScoringResult:
    hour = _nearest_hour(hourly_forecast, event_time)

    color_probabilities = _color_probabilities(hour)
    visibility_likelihood = _visibility_likelihood(hour)
    cloud_effect = _cloud_effect(hour)
    cloud_cover_summary = _cloud_cover_summary(hour)
    preference_match_score = _preference_match_score(
        hour, color_probabilities, preferences
    )
    window_start, window_end, arrival_offset = _viewing_window(event_time, cloud_effect)
    rain_or_unsafe_alert = _rain_or_unsafe_alert(hour)

    return ScoringResult(
        visibility_likelihood=visibility_likelihood,
        color_probabilities=color_probabilities,
        cloud_cover_summary=cloud_cover_summary,
        preference_match_score=preference_match_score,
        best_viewing_window_start=window_start,
        best_viewing_window_end=window_end,
        recommended_arrival_offset_minutes=arrival_offset,
        rain_or_unsafe_alert=rain_or_unsafe_alert,
        internal_cloud_effect=cloud_effect,
    )


def _nearest_hour(hourly_forecast: list[HourlyForecast], event_time: datetime) -> HourlyForecast:
    # Open-Meteo returns naive local-time strings when a timezone is requested,
    # while astral returns tz-aware datetimes — compare on naive local time.
    target = event_time.replace(tzinfo=None)
    return min(hourly_forecast, key=lambda h: abs(h.time - target))


def _bell(value: float, peak: float, width: float) -> float:
    return math.exp(-((value - peak) ** 2) / (2 * width**2))


def _color_probabilities(hour: HourlyForecast) -> ColorProbabilities:
    low_block = hour.cloud_cover_low / 100
    clouds_for_color = (hour.cloud_cover_mid + hour.cloud_cover_high) / 2

    golden = (1 - low_block * 0.7) * (0.7 + 0.3 * _bell(hour.cloud_cover_high, 30, 30))
    orange = (1 - low_block * 0.6) * (0.6 + 0.4 * _bell(clouds_for_color, 40, 35))
    pink = (1 - low_block) * _bell(clouds_for_color, 45, 30)
    purple = (1 - low_block) * _bell(clouds_for_color, 50, 25)
    red = (1 - low_block) * _bell(clouds_for_color, 55, 30)

    return ColorProbabilities(
        pink=_clamp(pink),
        purple=_clamp(purple),
        orange=_clamp(orange),
        red=_clamp(red),
        golden=_clamp(golden),
    )


def _visibility_likelihood(hour: HourlyForecast) -> float:
    low_block = hour.cloud_cover_low / 100
    haze_factor = _clamp(hour.visibility / 10000)
    precip_penalty = _clamp(hour.precipitation_probability / 100)

    likelihood = (1 - low_block) * haze_factor * (1 - precip_penalty)
    if hour.weather_code in UNSAFE_WEATHER_CODES:
        likelihood *= 0.3
    return _clamp(likelihood)


def _cloud_effect(hour: HourlyForecast) -> CloudEffect:
    clouds_for_color = (hour.cloud_cover_mid + hour.cloud_cover_high) / 2
    if hour.cloud_cover_low >= 50:
        return CloudEffect.BLOCKS
    if 20 <= clouds_for_color <= 70:
        return CloudEffect.ENHANCES
    return CloudEffect.NEUTRAL


def _cloud_cover_summary(hour: HourlyForecast) -> str:
    total = (hour.cloud_cover_low + hour.cloud_cover_mid + hour.cloud_cover_high) / 3
    if total < 15:
        return "mostly clear skies"
    if total < 40:
        dominant = _dominant_band(hour)
        return f"light cloud cover ({dominant})"
    if total < 75:
        dominant = _dominant_band(hour)
        return f"partly cloudy ({dominant})"
    return "overcast"


def _dominant_band(hour: HourlyForecast) -> str:
    bands = {
        "low clouds": hour.cloud_cover_low,
        "mid-level clouds": hour.cloud_cover_mid,
        "high clouds": hour.cloud_cover_high,
    }
    return max(bands, key=bands.get)


def _preference_match_score(
    hour: HourlyForecast,
    color_probabilities: ColorProbabilities,
    preferences: PreferenceProfile,
) -> float:
    avg_cloud = (hour.cloud_cover_low + hour.cloud_cover_mid + hour.cloud_cover_high) / 3
    clouds_for_color = (hour.cloud_cover_mid + hour.cloud_cover_high) / 2

    satisfaction = {
        "clear_sky": 1 - avg_cloud / 100,
        "dramatic_clouds": _bell(clouds_for_color, 65, 25),
        "pink_purple": (color_probabilities.pink + color_probabilities.purple) / 2,
        "golden_orange": (color_probabilities.golden + color_probabilities.orange) / 2,
        "red_sky": color_probabilities.red,
    }

    weights = {tag: getattr(preferences, tag) for tag in satisfaction}
    total_weight = sum(weights.values())
    if total_weight == 0:
        return 0.5  # no sky-condition preference expressed — neutral score

    weighted_sum = sum(weights[tag] * satisfaction[tag] for tag in satisfaction)
    return _clamp(weighted_sum / total_weight)


def _viewing_window(
    event_time: datetime, cloud_effect: CloudEffect
) -> tuple[datetime, datetime, int]:
    if cloud_effect == CloudEffect.ENHANCES:
        return event_time - timedelta(minutes=10), event_time + timedelta(minutes=35), 5
    if cloud_effect == CloudEffect.BLOCKS:
        return event_time - timedelta(minutes=30), event_time, -25
    return event_time - timedelta(minutes=20), event_time + timedelta(minutes=20), -20


def _rain_or_unsafe_alert(hour: HourlyForecast) -> str | None:
    if hour.weather_code in UNSAFE_WEATHER_CODES:
        return "Rain or storms expected around this time — conditions may be unsafe for viewing."
    if hour.precipitation_probability >= RAIN_PROBABILITY_ALERT_THRESHOLD:
        return f"{hour.precipitation_probability:.0f}% chance of rain around this time."
    return None


def _clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))
