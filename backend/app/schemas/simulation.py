import unicodedata
from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator

from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent

DISCLAIMER = (
    "This is an AI-generated illustrative representation of expected sky "
    "conditions, not a guaranteed photograph of the future."
)


_NAME_PUNCTUATION = set(" .,'’&()/:#-")


def clean_prompt_text(text: str) -> str:
    """Reduces text that goes into an image prompt to plain place-name
    characters: letters and digits in any script, and a little punctuation.
    Line breaks, quotes, brackets, symbols and emoji are dropped, so a name
    can't smuggle its own instructions or formatting into the prompt.
    """
    kept = []
    for char in unicodedata.normalize("NFKC", text):
        category = unicodedata.category(char)
        if char.isspace():
            kept.append(" ")
        elif char in _NAME_PUNCTUATION or category[0] in "LNM" or category == "Pd":
            kept.append(char)
    return " ".join("".join(kept).split())


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
    # The known place this is for (the id from the suggested spots), so the
    # preview can join that place's shared collection. Absent for a searched
    # address or the current location, which are never shared.
    place_id: str | None = Field(None, max_length=200)
    # The day the previewed sky is for.
    event_date: date | None = None
    cloud_cover_summary: str = Field(..., max_length=80)
    visibility_likelihood: float
    color_probabilities: ColorProbabilities

    @field_validator("location_name", "cloud_cover_summary")
    @classmethod
    def _plain_text_only(cls, value: str) -> str:
        cleaned = clean_prompt_text(value)
        if not cleaned:
            raise ValueError("must contain letters or numbers")
        return cleaned


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


class SharedPreviewRecord(BaseModel):
    """One preview in a place's shared collection. Nothing here says who made it."""

    id: str
    image_url: str  # short-lived signed links, fetched fresh on every list
    thumb_url: str
    place_name: str
    event: SunEvent
    event_date: date | None = None
    disclaimer: str = DISCLAIMER
    created_at: datetime


class PlacePreviewCount(BaseModel):
    place_id: str
    count: int  # previews by other people the user can open for this place
    popular: bool  # the place has a large number of previews overall

