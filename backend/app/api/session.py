from fastapi import APIRouter

from app.schemas.session import LocationResult, SessionRequest, SessionResponse, SunEvent
from app.services.astronomy import get_sun_events
from app.services.explanation import generate_explanation
from app.services.places import find_candidate_locations
from app.services.scoring import score_location
from app.services.weather import fetch_hourly_forecast

router = APIRouter(tags=["session"])

# Bounds how many candidate locations get a weather+scoring pass, since each
# one is an external Open-Meteo call. Fine for an MVP travel radius; revisit
# (e.g. grid-based weather caching) if candidate counts grow much larger.
MAX_CANDIDATES_SCORED = 15
TOP_N_RESULTS = 5


@router.post("/session", response_model=SessionResponse)
def create_session(request: SessionRequest) -> SessionResponse:
    candidates = find_candidate_locations(
        request.lat, request.lon, request.radius_km, request.place_types
    )[:MAX_CANDIDATES_SCORED]

    scored = []
    for candidate in candidates:
        sun_events = get_sun_events(candidate.lat, candidate.lon, request.date, request.tz_name)
        event_time = (
            sun_events.sunset if request.event == SunEvent.SUNSET else sun_events.sunrise
        )
        forecast = fetch_hourly_forecast(
            candidate.lat, candidate.lon, request.date, request.tz_name
        )
        score = score_location(event_time, forecast.hourly, request.preferences)
        scored.append((candidate, event_time, score))

    scored.sort(key=lambda item: item[2].preference_match_score, reverse=True)

    # Explanation Generator is an external LLM call — only run it for the
    # locations we're actually returning, not every scored candidate.
    results = []
    for candidate, event_time, score in scored[:TOP_N_RESULTS]:
        try:
            explanation = generate_explanation(candidate, score, request.preferences)
        except Exception:
            explanation = None

        results.append(
            LocationResult(
                location_id=candidate.id,
                name=candidate.name,
                type=candidate.type,
                distance_km=candidate.distance_km,
                event_time=event_time,
                recommended_arrival_offset_minutes=score.recommended_arrival_offset_minutes,
                best_viewing_window_start=score.best_viewing_window_start,
                best_viewing_window_end=score.best_viewing_window_end,
                visibility_likelihood=score.visibility_likelihood,
                cloud_cover_summary=score.cloud_cover_summary,
                color_probabilities=score.color_probabilities,
                rain_or_unsafe_alert=score.rain_or_unsafe_alert,
                preference_match_score=score.preference_match_score,
                explanation=explanation,
            )
        )

    return SessionResponse(recommendations=results)
