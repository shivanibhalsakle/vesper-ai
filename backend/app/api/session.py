from concurrent.futures import ThreadPoolExecutor

import httpx
from fastapi import APIRouter, HTTPException

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
    try:
        for candidate in candidates:
            sun_events = get_sun_events(
                candidate.lat, candidate.lon, request.date, request.tz_name
            )
            event_time = (
                sun_events.sunset if request.event == SunEvent.SUNSET else sun_events.sunrise
            )
            forecast = fetch_hourly_forecast(
                candidate.lat, candidate.lon, request.date, request.tz_name
            )
            score = score_location(event_time, forecast.hourly, request.preferences)
            scored.append((candidate, event_time, score))
    except httpx.HTTPError:
        raise HTTPException(
            status_code=503,
            detail="Weather data is temporarily unavailable. Please try again in a moment.",
        )

    scored.sort(key=lambda item: item[2].preference_match_score, reverse=True)
    top_scored = scored[:TOP_N_RESULTS]

    # Explanation Generator is an external LLM call — only run it for the
    # locations we're actually returning, not every scored candidate. These
    # are independent calls, so running them in a thread pool means the
    # total wait is roughly one call's latency instead of TOP_N_RESULTS's.
    with ThreadPoolExecutor(max_workers=len(top_scored) or 1) as executor:
        explanations = list(
            executor.map(
                lambda item: _safe_explanation(item[0], item[2], request.preferences),
                top_scored,
            )
        )

    results = []
    for (candidate, event_time, score), explanation in zip(top_scored, explanations):
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


def _safe_explanation(candidate, score, preferences) -> str | None:
    try:
        return generate_explanation(candidate, score, preferences)
    except Exception:
        return None
