from fastapi import APIRouter

from app.schemas.trip_window import TripWindowRequest, TripWindowResponse, TripWindowResult
from app.services.explanation import generate_explanation
from app.services.trip_window import find_best_day_and_location

router = APIRouter(tags=["trip-window"])


@router.post("/trip-window", response_model=TripWindowResponse)
def create_trip_window(request: TripWindowRequest) -> TripWindowResponse:
    days_considered = (request.end_date - request.start_date).days + 1

    search = find_best_day_and_location(
        request.lat,
        request.lon,
        request.event,
        request.start_date,
        request.end_date,
        request.radius_km,
        request.place_types,
        request.preferences,
        request.tz_name,
    )

    if search.best is None:
        return TripWindowResponse(
            best=None,
            candidates_considered=search.candidates_considered,
            days_considered=days_considered,
        )

    candidate, best_date, event_time, score = search.best

    try:
        explanation = generate_explanation(candidate, score, request.preferences)
    except Exception:
        explanation = None

    result = TripWindowResult(
        location_id=candidate.id,
        name=candidate.name,
        type=candidate.type,
        distance_km=candidate.distance_km,
        date=best_date,
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

    return TripWindowResponse(
        best=result,
        candidates_considered=search.candidates_considered,
        days_considered=days_considered,
    )
