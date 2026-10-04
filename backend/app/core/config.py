from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "development"
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunset"
    redis_url: str = "redis://localhost:6379/0"
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    firebase_credentials_path: str = ""
    # Public Overpass instances, tried in order on failure. Configurable so a
    # dead mirror can be swapped out without a code change.
    overpass_urls: str = (
        "https://overpass-api.de/api/interpreter,"
        "https://overpass.kumi.systems/api/interpreter,"
        "https://overpass.private.coffee/api/interpreter"
    )
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
