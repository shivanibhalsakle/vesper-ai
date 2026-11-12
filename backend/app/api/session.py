import logging
from concurrent.futures import ThreadPoolExecutor

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.api.coverage import outside_coverage_error
from app.api.limits import check_search_budget
from app.core.auth import get_current_user_id
from app.core.diagnostics import describe_error, describe_place_error
from app.schemas.session import LocationResult, SessionRequest, SessionResponse, SunEvent
from app.services.astronomy import get_sun_events
from app.services.explanation import generate_comparative_explanations, generate_explanation
from app.services.places import OutsideCoverage, PlaceDataUnavailable, find_candidate_locations
from app.services.scoring import score_location
from app.services.timezones import resolve_timezone
from app.services.weather import fetch_hourly_forecast

logger = logging.getLogger(__name__)

router = APIRouter(tags=["session"])

# Bounds how many candidate locations get a weather+scoring pass, since each
# one is an external Open-Meteo call. Fine for an MVP travel radius; revisit
# (e.g. grid-based weather caching) if candidate counts grow much larger.
MAX_CANDIDATES_SCORED = 15
TOP_N_RESULTS = 5


@router.post("/session", response_model=SessionResponse)
def create_session(
    request: SessionRequest, user_id: str = Depends(get_current_user_id)
) -> SessionResponse:
    check_search_budget("session", user_id)
    try:
        candidates = find_candidate_locations(
            request.lat, request.lon, request.radius_km, request.place_types
        )[:MAX_CANDIDATES_SCORED]
    except OutsideCoverage:
        raise outside_coverage_error()
    except PlaceDataUnavailable as exc:
        logger.warning("Place data unavailable: %s", describe_place_error(exc))
        raise HTTPException(
            status_code=503,
            detail="Place data is temporarily unavailable. Please try again in a moment.",
        )

    scored = []
    try:
        for candidate in candidates:
            forecast = fetch_hourly_forecast(
                candidate.lat, candidate.lon, request.date, request.tz_name
            )
            # The forecast comes first: with tz_name "auto" it's what tells
            # us the place's own timezone for the sun times.
            sun_events = get_sun_events(
                candidate.lat,
                candidate.lon,
                request.date,
                resolve_timezone(request.tz_name, forecast),
            )
            event_time = (
                sun_events.sunset if request.event == SunEvent.SUNSET else sun_events.sunrise
            )
            score = score_location(event_time, forecast.hourly, request.preferences)
            scored.append((candidate, event_time, score))
    except httpx.HTTPError as exc:
        logger.warning("Weather provider failed: %s", describe_error(exc))
        raise HTTPException(
            status_code=503,
            detail="Weather data is temporarily unavailable. Please try again in a moment.",
        )

    scored.sort(key=lambda item: item[2].preference_match_score, reverse=True)
    top_scored = scored[:TOP_N_RESULTS]

    explanations = _explanations(top_scored, request.preferences)

    results = []
    for (candidate, event_time, score), explanation in zip(top_scored, explanations):
        results.append(
            LocationResult(
                location_id=candidate.id,
                name=candidate.name,
                type=candidate.type,
                lat=candidate.lat,
                lon=candidate.lon,
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


def _explanations(top_scored, preferences) -> list[str | None]:
    """A short note per returned place. The Explanation Generator is an external
    LLM call, so it only runs for the places we're actually returning.

    With several places it's one request that sees them all, so the notes can
    say what sets each apart instead of repeating each other. If that fails or
    returns something unusable, it falls back to one independent request per
    place, run in a thread pool so the wait is about one call's latency.
    """
    if len(top_scored) > 1:
        try:
            notes = generate_comparative_explanations(
                [(candidate, score) for candidate, _, score in top_scored], preferences
            )
            return [notes[candidate.id] for candidate, _, _ in top_scored]
        except Exception as exc:
            logger.warning(
                "Combined explanations failed (%s); using one request per place",
                describe_error(exc),
            )

    with ThreadPoolExecutor(max_workers=len(top_scored) or 1) as executor:
        return list(
            executor.map(
                lambda item: _safe_explanation(item[0], item[2], preferences),
                top_scored,
            )
        )


def _safe_explanation(candidate, score, preferences) -> str | None:
    try:
        return generate_explanation(candidate, score, preferences)
    except Exception:
        return None
