import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.api.coverage import outside_coverage_error
from app.api.limits import check_search_budget
from app.core.auth import get_current_user_id
from app.core.diagnostics import describe_error, describe_place_error
from app.schemas.best_date import BestDateRequest, BestDateResponse
from app.services.best_date import find_best_dates
from app.services.places import OutsideCoverage, PlaceDataUnavailable

logger = logging.getLogger(__name__)

router = APIRouter(tags=["best-date"])


@router.post("/best-date", response_model=BestDateResponse)
def best_date(
    request: BestDateRequest, user_id: str = Depends(get_current_user_id)
) -> BestDateResponse:
    """Scores each of the next few days against the user's sky preferences
    and returns the earliest best one, with that day's full sky details.
    """
    check_search_budget("best-date", user_id)
    try:
        return find_best_dates(request)
    except OutsideCoverage:
        raise outside_coverage_error()
    except PlaceDataUnavailable as exc:
        logger.warning("Place data unavailable: %s", describe_place_error(exc))
        raise HTTPException(
            status_code=503,
            detail="Place data is temporarily unavailable. Please try again in a moment.",
        )
    except httpx.HTTPError as exc:
        logger.warning("Weather provider failed: %s", describe_error(exc))
        raise HTTPException(
            status_code=503,
            detail="Weather data is temporarily unavailable. Please try again in a moment.",
        )
