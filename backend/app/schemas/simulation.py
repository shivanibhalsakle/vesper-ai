from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent

DISCLAIMER = (
    "This is an AI-generated illustrative representation of expected sky "
    "conditions, not a guaranteed photograph of the future."
)


class SimulationRequest(BaseModel):
    """Fields the client already has from a /session result — no server-side
    session state needed to request a preview for the location the user picked.
    """

    # Both strings end up inside the image prompt, so they're kept short.
    location_name: str = Field(..., min_length=1, max_length=120)
    # None for a place picked on the map, which has no spot type; the prompt
    # then uses a generic viewpoint foreground.
    location_type: LocationType | None = None
    event: SunEvent
    cloud_cover_summary: str = Field(..., max_length=80)
    visibility_likelihood: float
    color_probabilities: ColorProbabilities


class SimulationResponse(BaseModel):
    prompt: str
    image_url: str | None
    disclaimer: str = DISCLAIMER
    provider_status: str  # "generated" | "not_configured" | "error"
    remaining_today: int  # previews left today under the per-user daily cap
    # Set when the image was also kept in the user's "Sky previews" gallery;
    # image_url is then a short-lived link to the stored copy.
    preview_id: str | None = None
    saved: bool = False


class RemainingPreviews(BaseModel):
    remaining_today: int
    daily_limit: int


class PreviewRecord(BaseModel):
    """One image in the user's gallery."""

    id: str
    image_url: str  # short-lived signed link; fetched fresh on every list
    location_name: str
    location_type: LocationType | None = None
    event: SunEvent
    prompt: str
    disclaimer: str = DISCLAIMER
    created_at: datetime
