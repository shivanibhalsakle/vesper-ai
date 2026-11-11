from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "development"
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunset"
    redis_url: str = "redis://localhost:6379/0"
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    firebase_credentials_path: str = ""
    # Firebase Storage bucket where generated sky previews are kept (e.g.
    # "vesper-ai-37d6f.firebasestorage.app"). Empty = previews still generate
    # but aren't saved to the user's gallery.
    firebase_storage_bucket: str = ""
    # Geoapify geocoding (address / place-name search) — see
    # app/services/geocoding.py. Free tier: 3,000 requests/day.
    geoapify_api_key: str = ""
    # Public Overpass instances, tried in order on failure. Configurable so a
    # dead mirror can be swapped out without a code change.
    overpass_urls: str = (
        "https://overpass-api.de/api/interpreter,"
        "https://overpass.kumi.systems/api/interpreter,"
        "https://overpass.private.coffee/api/interpreter"
    )
    # Searches outside the regions we've loaded (osm_loaded_regions) are refused
    # with a "not covered yet" message. Set true to let them try the public
    # Overpass service instead, which is slow and unreliable.
    overpass_outside_coverage: bool = False
    # Kill switches for the features that spend money. Set to false on Render
    # (no redeploy of code needed) to pause them if costs or abuse spike.
    searches_enabled: bool = True
    previews_enabled: bool = True
    # Sky previews are the costliest feature (an image per preview). This caps
    # how many are generated per day across all users, whatever the per-user
    # limit says; change it on Render without a code change.
    preview_global_daily_limit: int = 50
    # OpenAI image quality: "low" costs roughly a tenth of "medium". See
    # scripts/compare_image_quality.py to look at the difference.
    image_quality: Literal["low", "medium", "high"] = "medium"
    # Shared secret for the /internal/* endpoints (e.g. the daily
    # notification rescore), called by a scheduled GitHub Actions workflow
    # rather than a Celery beat process — see app/api/internal.py.
    internal_api_secret: str = ""
    allowed_origins: str = (
        "http://localhost:5050,"
        "https://vesper-ai-37d6f.web.app,"
        "https://vesper-ai-37d6f.firebaseapp.com"
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
