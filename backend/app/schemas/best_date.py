from datetime import date as date_type

from pydantic import BaseModel, Field, model_validator

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent
from app.schemas.sky import Confidence, SkyResponse

SKY_TAGS = ("clear_sky", "dramatic_clouds", "pink_purple", "golden_orange", "red_sky")

# Open-Meteo's forecast horizon.
MAX_DAYS = 16


class BestDateRequest(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    event: SunEvent
    # The caller's own "today": the server can't know the user's local date.
    start_date: date_type
    days: int = Field(7, ge=1, le=MAX_DAYS)
    radius_km: float = Field(10.0, gt=0, le=100)
    # Empty = all place types.
    place_types: list[LocationType] = []
    preferences: PreferenceProfile
    tz_name: str = "auto"

    @model_validator(mode="after")
    def _needs_a_sky_preference(self) -> "BestDateRequest":
        # With no sky preference every day scores the same, so "best" would
        # be meaningless — make the caller ask the user to set one.
        if not any(getattr(self.preferences, tag) > 0 for tag in SKY_TAGS):
            raise ValueError("set at least one sky preference to find a best date")
        return self


class Spot(BaseModel):
    location_id: str
    name: str
    type: LocationType
    lat: float
    lon: float
    distance_km: float


class DayScore(BaseModel):
    date: date_type
    score: float
    confidence: Confidence
    # The viewing spot that scored best that day (None when the search area
    # has no mapped spots and the searched point itself was scored).
    spot_name: str | None


class BestDay(BaseModel):
    date: date_type
    spot: Spot | None
    sky: SkyResponse


class BestDateResponse(BaseModel):
    days: list[DayScore]
    best: BestDay | None
    spots_considered: int
