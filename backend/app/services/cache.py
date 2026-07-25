from typing import Protocol

import redis

from app.core.config import get_settings


class Cache(Protocol):
    def get(self, key: str) -> str | None: ...
    def set(self, key: str, value: str, ttl_seconds: int) -> None: ...


class RedisCache:
    def __init__(self, redis_url: str | None = None):
        self._client = redis.Redis.from_url(redis_url or get_settings().redis_url)

    def get(self, key: str) -> str | None:
        value = self._client.get(key)
        return value.decode() if value is not None else None

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        self._client.set(key, value, ex=ttl_seconds)
