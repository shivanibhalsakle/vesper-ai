"""Place-name / address search, backed by Geoapify.

Results are cached (Geoapify permits storing results), so repeat searches
cost nothing against the free tier's 3,000 requests/day. A per-user daily
counter keeps any one account from draining that shared quota.
"""

import json
import logging

import httpx

from app.core.config import get_settings
from app.schemas.geocode import GeocodeResult
from app.services.cache import Cache, RedisCache

logger = logging.getLogger(__name__)

GEOAPIFY_URL = "https://api.geoapify.com/v1/geocode/search"
REQUEST_TIMEOUT_SECONDS = 8.0
MAX_RESULTS = 5
CACHE_TTL_SECONDS = 30 * 24 * 60 * 60
CACHE_KEY_PREFIX = "geocode:v1:"

DAILY_LIMIT_PER_USER = 100
LIMIT_WINDOW_SECONDS = 24 * 60 * 60


class GeocodingUnavailable(Exception):
    """The provider is unconfigured or failed — distinct from 'no matches'."""


class GeocodeLimitExceeded(Exception):
    """The user has used today's search allowance."""


def normalize_query(query: str) -> str:
    return " ".join(query.lower().split())


def ensure_within_daily_limit(user_id: str, cache: Cache | None = None) -> None:
    """Counts one search against the user's daily allowance. Fails open if
    Redis is down: losing the limiter briefly beats blocking all searches.
    """
    cache = cache if cache is not None else RedisCache()
    try:
        count = cache.incr(f"geocode:usage:{user_id}", LIMIT_WINDOW_SECONDS)
    except Exception:
        logger.warning("Geocode rate limiter unavailable; allowing request", exc_info=True)
        return
    if count > DAILY_LIMIT_PER_USER:
        raise GeocodeLimitExceeded(
            f"You've reached today's limit of {DAILY_LIMIT_PER_USER} location searches. "
            "Try again tomorrow."
        )


def geocode(
    query: str,
    client: httpx.Client | None = None,
    cache: Cache | None = None,
) -> list[GeocodeResult]:
    normalized = normalize_query(query)
    if not normalized:
        return []

    cache = cache if cache is not None else RedisCache()
    cache_key = CACHE_KEY_PREFIX + normalized

    cached = _cache_get(cache, cache_key)
    if cached is not None:
        return cached

    api_key = get_settings().geoapify_api_key
    if not api_key:
        raise GeocodingUnavailable("Geoapify API key is not configured")

    owns_client = client is None
    client = client or httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS)
    try:
        response = client.get(
            GEOAPIFY_URL,
            params={"text": normalized, "limit": MAX_RESULTS, "format": "json", "apiKey": api_key},
        )
        response.raise_for_status()
        payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        # Never log the exception text for HTTP errors: httpx includes the
        # full request URL, which carries the API key.
        raise GeocodingUnavailable(f"Geoapify request failed ({type(exc).__name__})") from None
    finally:
        if owns_client:
            client.close()

    results = _parse_results(payload)
    if results:
        _cache_set(cache, cache_key, results)
    return results


def _parse_results(payload: object) -> list[GeocodeResult]:
    if not isinstance(payload, dict):
        raise GeocodingUnavailable("Geoapify returned an unexpected response")
    results = []
    for item in payload.get("results") or []:
        try:
            results.append(
                GeocodeResult(
                    label=item.get("formatted") or item.get("name") or "",
                    lat=float(item["lat"]),
                    lon=float(item["lon"]),
                )
            )
        except (KeyError, TypeError, ValueError, AttributeError):
            continue
    return [r for r in results if r.label][:MAX_RESULTS]


def _cache_get(cache: Cache, key: str) -> list[GeocodeResult] | None:
    try:
        raw = cache.get(key)
        if raw is None:
            return None
        return [GeocodeResult(**item) for item in json.loads(raw)]
    except Exception:
        logger.warning("Geocode cache read failed", exc_info=True)
        return None


def _cache_set(cache: Cache, key: str, results: list[GeocodeResult]) -> None:
    try:
        cache.set(key, json.dumps([r.model_dump() for r in results]), CACHE_TTL_SECONDS)
    except Exception:
        logger.warning("Geocode cache write failed", exc_info=True)
