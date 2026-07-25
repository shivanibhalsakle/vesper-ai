from datetime import date as date_type
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ColorProbabilities


class SunEvent(str, Enum):
    SUNRISE = "sunrise"
    SUNSET = "sunset"


class SessionRequest(BaseModel):
    lat: float
    lon: float
    event: SunEvent
    date: date_type
    radius_km: float = Field(10.0, gt=0, le=100)
    place_types: list[LocationType]
    preferences: PreferenceProfile = PreferenceProfile()
    # IANA timezone name for the queried location. Full timezone
    # auto-detection from lat/lon is a later refinement (needs an
    # additional lookup library); the client supplies it for now.
    tz_name: str = "UTC"


class LocationResult(BaseModel):
    """Client-facing per-location result. Deliberately excludes the Scoring
    Engine's internal cloud-blocks-vs-enhances judgment — that flag only
    ever informs visibility_likelihood, color_probabilities, and (later)
    the explanation text, never the raw client response.
    """

    location_id: str
    name: str
    type: LocationType
    distance_km: float

    event_time: datetime
    recommended_arrival_offset_minutes: int
    best_viewing_window_start: datetime
    best_viewing_window_end: datetime

    visibility_likelihood: float
    cloud_cover_summary: str
    color_probabilities: ColorProbabilities
    rain_or_unsafe_alert: str | None
    preference_match_score: float

    explanation: str | None = None  # populated by the Explanation Generator (Phase 5)


class SessionResponse(BaseModel):
    recommendations: list[LocationResult]
