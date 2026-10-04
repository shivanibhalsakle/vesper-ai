from datetime import date as date_type
from datetime import datetime

from pydantic import BaseModel

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent


class ForecastSnapshot(BaseModel):
    """A frozen copy of the ScoringResult fields at the time of the visit,
    so later scoring-accuracy analysis isn't affected by algorithm changes.
    """

    cloud_cover_summary: str
    visibility_likelihood: float
    color_probabilities: ColorProbabilities
    preference_match_score: float


class FeedbackCreate(BaseModel):
    location_id: str
    location_name: str
    location_type: LocationType
    event: SunEvent
    event_date: date_type
    photo_storage_path: str
    preference_profile: PreferenceProfile
    forecast_snapshot: ForecastSnapshot
    # No user_id: the author always comes from the verified Firebase token.


class FeedbackRecord(BaseModel):
    id: str
    location_id: str
    location_name: str
    location_type: LocationType
    event: SunEvent
    event_date: date_type
    photo_storage_path: str
    # user_id is deliberately not exposed — these records are readable by
    # other signed-in users, who shouldn't see each other's account IDs.
    preference_profile: PreferenceProfile
    forecast_snapshot: ForecastSnapshot
    created_at: datetime

    model_config = {"from_attributes": True}
