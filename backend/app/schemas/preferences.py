from pydantic import BaseModel, Field

Weight = float  # 0.0 (no preference) to 1.0 (strong preference)


class PreferenceProfile(BaseModel):
    """Structured tag weights parsed from a user's sky preferences.

    The five sky-condition tags (clear_sky through red_sky) drive the
    Scoring Engine's weather-based match score. The remaining tags describe
    location composition and are matched against location records once the
    Places Service exists (Phase 3+); the Scoring Engine ignores them for now.
    """

    clear_sky: Weight = Field(0.0, ge=0.0, le=1.0)
    dramatic_clouds: Weight = Field(0.0, ge=0.0, le=1.0)
    pink_purple: Weight = Field(0.0, ge=0.0, le=1.0)
    golden_orange: Weight = Field(0.0, ge=0.0, le=1.0)
    red_sky: Weight = Field(0.0, ge=0.0, le=1.0)

    silhouettes: Weight = Field(0.0, ge=0.0, le=1.0)
    water_reflection: Weight = Field(0.0, ge=0.0, le=1.0)
    city_skyline: Weight = Field(0.0, ge=0.0, le=1.0)
    unobstructed_horizon: Weight = Field(0.0, ge=0.0, le=1.0)
