import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import get_current_user_id
from app.schemas.sky import SkyRequest, SkyResponse
from app.services.sky import sky_at

router = APIRouter(tags=["sky"])


@router.post("/sky", response_model=SkyResponse)
def sky_forecast(
    request: SkyRequest, _user_id: str = Depends(get_current_user_id)
) -> SkyResponse:
    """The predicted sky at one point on one day — no place search, so it's
    one forecast call and nothing else.
    """
    try:
        return sky_at(request)
    except httpx.HTTPError:
        raise HTTPException(
            status_code=503,
            detail="Weather data is temporarily unavailable. Please try again in a moment.",
        )
