from datetime import datetime
from enum import Enum

from pydantic import BaseModel


class CloudEffect(str, Enum):
    """Internal judgment of whether clouds will block or enhance the view.

    Never exposed to the client directly (per product spec) — it only
    informs visibility_likelihood, color_probabilities, and the eventual
    explanation text.
    """

    BLOCKS = "blocks"
    ENHANCES = "enhances"
    NEUTRAL = "neutral"


class ColorProbabilities(BaseModel):
    pink: float
    purple: float
    orange: float
    red: float
    golden: float


class ScoringResult(BaseModel):
    visibility_likelihood: float
    color_probabilities: ColorProbabilities
    cloud_cover_summary: str
    preference_match_score: float
    best_viewing_window_start: datetime
    best_viewing_window_end: datetime
    recommended_arrival_offset_minutes: int
    rain_or_unsafe_alert: str | None

    internal_cloud_effect: CloudEffect
