from datetime import date as date_type
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ColorProbabilities, SkyProfile
from app.schemas.session import SunEvent


class Confidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class SkyRequest(BaseModel):
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    event: SunEvent
    date: date_type
    # Optional: only used to compute a match score against the user's tastes.
    preferences: PreferenceProfile | None = None
    # "auto" resolves the zone from the coordinates (via the forecast
    # provider), so event times come back in the place's own local time.
    tz_name: str = "auto"


class SkyResponse(BaseModel):
    event: SunEvent
    date: date_type
    timezone: str

    event_time: datetime
    event_passed: bool
    recommended_arrival_offset_minutes: int
    best_viewing_window_start: datetime
    best_viewing_window_end: datetime

    visibility_likelihood: float
    cloud_cover_summary: str
    color_probabilities: ColorProbabilities
    sky_profile: SkyProfile
    rain_or_unsafe_alert: str | None

    # None when the request carried no sky preferences to match against.
    preference_match_score: float | None

    # How far ahead the forecast is, and how much to trust it because of it.
    lead_days: int
    confidence: Confidence
