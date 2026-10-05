from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.location import LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent


class UserPreferencesUpdate(BaseModel):
    # Owner comes from the verified Firebase token, never the body.
    home_lat: float | None = Field(None, ge=-90, le=90)
    home_lon: float | None = Field(None, ge=-180, le=180)
    home_label: str | None = Field(None, max_length=200)
    radius_km: float = Field(10.0, gt=0, le=100)
    # Empty list = no preference (all place types).
    place_types: list[LocationType] = []
    event: SunEvent = SunEvent.SUNSET
    preference_profile: PreferenceProfile = PreferenceProfile()


class UserPreferencesRecord(UserPreferencesUpdate):
    updated_at: datetime

    model_config = {"from_attributes": True}
