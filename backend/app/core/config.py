from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    environment: str = "development"
    database_url: str = "postgresql://postgres:postgres@localhost:5432/sunset"
    redis_url: str = "redis://localhost:6379/0"
    anthropic_api_key: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()
