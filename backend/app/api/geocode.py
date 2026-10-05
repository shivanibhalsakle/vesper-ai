from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.auth import get_current_user_id
from app.schemas.geocode import GeocodeResult
from app.services.geocoding import (
    GeocodeLimitExceeded,
    GeocodingUnavailable,
    ensure_within_daily_limit,
    geocode,
)

router = APIRouter(tags=["geocode"])


@router.get("/geocode", response_model=list[GeocodeResult])
def search_places(
    q: str = Query(..., min_length=2, max_length=200),
    user_id: str = Depends(get_current_user_id),
) -> list[GeocodeResult]:
    try:
        ensure_within_daily_limit(user_id)
    except GeocodeLimitExceeded as exc:
        raise HTTPException(status_code=429, detail=str(exc))
    try:
        return geocode(q)
    except GeocodingUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Location search is temporarily unavailable. Please try again in a moment.",
        )
