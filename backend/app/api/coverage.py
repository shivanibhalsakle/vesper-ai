from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.coverage import covered_regions, outside_coverage_message

router = APIRouter(tags=["coverage"])


class CoverageRegion(BaseModel):
    slug: str
    name: str
    south: float
    west: float
    north: float
    east: float


class CoverageResponse(BaseModel):
    regions: list[CoverageRegion]


@router.get("/coverage", response_model=CoverageResponse)
def coverage() -> CoverageResponse:
    """Where Vesper has place data. Public: it's the same list the app shows
    users who search somewhere we don't cover yet.
    """
    return CoverageResponse(regions=covered_regions())


def outside_coverage_error() -> HTTPException:
    """422, not 503: retrying won't help, and the message says where it does work."""
    return HTTPException(status_code=422, detail=outside_coverage_message())
