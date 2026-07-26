from datetime import date as date_type
from datetime import datetime

from pydantic import BaseModel, Field, model_validator

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent

# Open-Meteo's forecast horizon — bounds how far out a trip window can run.
MAX_TRIP_WINDOW_DAYS = 16


class TripWindowRequest(BaseModel):
    lat: float
    lon: float
    event: SunEvent
    start_date: date_type
    end_date: date_type
    radius_km: float = Field(10.0, gt=0, le=100)
    place_types: list[LocationType]
    preferences: PreferenceProfile = PreferenceProfile()
    tz_name: str = "UTC"

    @model_validator(mode="after")
    def _validate_date_range(self) -> "TripWindowRequest":
        if self.end_date < self.start_date:
            raise ValueError("end_date must not be before start_date")
        if (self.end_date - self.start_date).days >= MAX_TRIP_WINDOW_DAYS:
            raise ValueError(f"trip window cannot exceed {MAX_TRIP_WINDOW_DAYS} days")
        return self


class TripWindowResult(BaseModel):
    location_id: str
    name: str
    type: LocationType
    distance_km: float
    date: date_type

    event_time: datetime
    recommended_arrival_offset_minutes: int
    best_viewing_window_start: datetime
    best_viewing_window_end: datetime

    visibility_likelihood: float
    cloud_cover_summary: str
    color_probabilities: ColorProbabilities
    rain_or_unsafe_alert: str | None
    preference_match_score: float
    explanation: str | None = None


class TripWindowResponse(BaseModel):
    best: TripWindowResult | None
    candidates_considered: int
    days_considered: int
