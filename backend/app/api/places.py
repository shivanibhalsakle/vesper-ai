from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.auth import get_current_user_id
from app.schemas.location import LocationRecord, LocationType
from app.services.places import PlaceDataUnavailable, find_candidate_locations

router = APIRouter(tags=["places"])

MAX_SPOTS = 30


@router.get("/places/nearby", response_model=list[LocationRecord])
def nearby_places(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(10.0, gt=0, le=100),
    # Repeat the parameter for several types; omit it for all types.
    place_types: list[LocationType] = Query(default=[]),
    _user_id: str = Depends(get_current_user_id),
) -> list[LocationRecord]:
    """Viewing spots around a point, nearest first. Place data only — no
    weather or LLM calls, so it's fast and cheap.
    """
    types = place_types or list(LocationType)
    try:
        spots = find_candidate_locations(lat, lon, radius_km, types)
    except PlaceDataUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Place data is temporarily unavailable. Please try again in a moment.",
        )
    return spots[:MAX_SPOTS]
