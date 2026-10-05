from datetime import date as date_type
from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.session import SunEvent


class SavedDateCreate(BaseModel):
    # Owner comes from the verified Firebase token, never the body.
    event_date: date_type
    event: SunEvent
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    label: str = Field(..., min_length=1, max_length=200)
    saved_score: float | None = Field(None, ge=0.0, le=1.0)
    fcm_token: str | None = Field(None, max_length=4096)
    notification_enabled: bool = True


class SavedDateUpdate(BaseModel):
    notification_enabled: bool


class SavedDateRecord(BaseModel):
    id: str
    event_date: date_type
    event: SunEvent
    lat: float
    lon: float
    label: str
    saved_score: float | None
    notification_enabled: bool
    created_at: datetime

    model_config = {"from_attributes": True}
