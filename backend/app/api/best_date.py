import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import get_current_user_id
from app.schemas.best_date import BestDateRequest, BestDateResponse
from app.services.best_date import find_best_dates
from app.services.places import PlaceDataUnavailable

router = APIRouter(tags=["best-date"])


@router.post("/best-date", response_model=BestDateResponse)
def best_date(
    request: BestDateRequest, _user_id: str = Depends(get_current_user_id)
) -> BestDateResponse:
    """Scores each of the next few days against the user's sky preferences
    and returns the earliest best one, with that day's full sky details.
    """
    try:
        return find_best_dates(request)
    except PlaceDataUnavailable:
        raise HTTPException(
            status_code=503,
            detail="Place data is temporarily unavailable. Please try again in a moment.",
        )
    except httpx.HTTPError:
        raise HTTPException(
            status_code=503,
            detail="Weather data is temporarily unavailable. Please try again in a moment.",
        )
