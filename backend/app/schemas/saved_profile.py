from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent


class SavedProfileCreate(BaseModel):
    user_id: str
    home_lat: float
    home_lon: float
    radius_km: float = Field(10.0, gt=0, le=100)
    place_types: list[LocationType]
    event: SunEvent
    tz_name: str = "UTC"
    preference_profile: PreferenceProfile
    fcm_token: str | None = None
    notification_enabled: bool = True
    match_threshold: float = Field(0.75, ge=0.0, le=1.0)


class SavedProfileRecord(BaseModel):
    id: str
    user_id: str
    home_lat: float
    home_lon: float
    radius_km: float
    place_types: list[LocationType]
    event: SunEvent
    tz_name: str
    preference_profile: PreferenceProfile
    fcm_token: str | None
    notification_enabled: bool
    match_threshold: float
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
