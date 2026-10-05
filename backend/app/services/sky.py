from datetime import date, datetime
from zoneinfo import ZoneInfo

from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent
from app.schemas.sky import Confidence, SkyRequest, SkyResponse
from app.services.astronomy import get_sun_events
from app.services.scoring import score_location
from app.services.timezones import resolve_timezone
from app.services.weather import fetch_hourly_forecast

SKY_TAGS = ("clear_sky", "dramatic_clouds", "pink_purple", "golden_orange", "red_sky")


def confidence_for_lead_days(lead_days: int) -> Confidence:
    """Forecast skill falls off with lead time; this is a coarse, honest
    bucket rather than a calibrated probability.
    """
    if lead_days <= 1:
        return Confidence.HIGH
    if lead_days <= 3:
        return Confidence.MEDIUM
    return Confidence.LOW


def sky_at(request: SkyRequest, now: datetime | None = None) -> SkyResponse:
    forecast = fetch_hourly_forecast(request.lat, request.lon, request.date, request.tz_name)
    tz_name = resolve_timezone(request.tz_name, forecast)

    sun_events = get_sun_events(request.lat, request.lon, request.date, tz_name)
    event_time = sun_events.sunset if request.event == SunEvent.SUNSET else sun_events.sunrise

    score = score_location(event_time, forecast.hourly, request.preferences or PreferenceProfile())

    now = now or datetime.now(ZoneInfo(tz_name))
    today: date = now.date()
    lead_days = max(0, (request.date - today).days)

    has_sky_preference = request.preferences is not None and any(
        getattr(request.preferences, tag) > 0 for tag in SKY_TAGS
    )

    return SkyResponse(
        event=request.event,
        date=request.date,
        timezone=tz_name,
        event_time=event_time,
        event_passed=event_time < now,
        recommended_arrival_offset_minutes=score.recommended_arrival_offset_minutes,
        best_viewing_window_start=score.best_viewing_window_start,
        best_viewing_window_end=score.best_viewing_window_end,
        visibility_likelihood=score.visibility_likelihood,
        cloud_cover_summary=score.cloud_cover_summary,
        color_probabilities=score.color_probabilities,
        sky_profile=score.sky_profile,
        rain_or_unsafe_alert=score.rain_or_unsafe_alert,
        preference_match_score=score.preference_match_score if has_sky_preference else None,
        lead_days=lead_days,
        confidence=confidence_for_lead_days(lead_days),
    )
