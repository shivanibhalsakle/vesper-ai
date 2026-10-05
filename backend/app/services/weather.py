import time
from datetime import date

import httpx
import redis

from app.schemas.weather import HourlyForecast, WeatherForecast
from app.services.cache import Cache, RedisCache

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# Forecasts drift slowly, and Open-Meteo rate-limits shared IPs (Render's
# free tier shares outbound IPs), so an hour of caching cuts upstream calls
# a lot without noticeable staleness.
FORECAST_CACHE_TTL_SECONDS = 60 * 60

# 429/5xx from Open-Meteo are usually transient (shared-IP throttling or a
# brief upstream blip) — worth a couple of quick retries before giving up.
RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}
MAX_ATTEMPTS = 3
RETRY_BACKOFF_SECONDS = 0.5

HOURLY_VARIABLES = [
    "cloud_cover_low",
    "cloud_cover_mid",
    "cloud_cover_high",
    "visibility",
    "uv_index",
    "precipitation_probability",
    "weather_code",
]


def fetch_hourly_forecast(
    lat: float,
    lon: float,
    on_date: date,
    tz_name: str = "UTC",
    end_date: date | None = None,
    client: httpx.Client | None = None,
    cache: Cache | None = None,
) -> WeatherForecast:
    """Fetches hourly forecast from on_date through end_date (inclusive).

    end_date defaults to on_date for a single-day forecast. Open-Meteo
    accepts a date range in one call — Trip-Window Mode uses this to fetch
    a whole trip's forecast per candidate location in a single request
    instead of one call per (location, day) pair.

    Results are cached per ~1km grid cell. The request itself uses the
    rounded coordinates so a cached entry is exactly what a fresh fetch for
    that cell would return (Open-Meteo's own grid is coarser than this).
    """
    cache = cache if cache is not None else RedisCache()
    last_date = end_date or on_date
    grid_lat, grid_lon = round(lat, 2), round(lon, 2)
    cache_key = f"forecast:{grid_lat}:{grid_lon}:{on_date}:{last_date}:{tz_name}"

    cached = _cache_get(cache, cache_key)
    if cached is not None:
        return WeatherForecast.model_validate_json(cached)

    owns_client = client is None
    client = client or httpx.Client()
    try:
        response = _get_with_retry(
            client,
            {
                "latitude": grid_lat,
                "longitude": grid_lon,
                "hourly": ",".join(HOURLY_VARIABLES),
                "start_date": on_date.isoformat(),
                "end_date": last_date.isoformat(),
                "timezone": tz_name,
            },
        )
        forecast = _parse_hourly_response(response.json())
    finally:
        if owns_client:
            client.close()

    _cache_set(cache, cache_key, forecast.model_dump_json())
    return forecast


def _get_with_retry(client: httpx.Client, params: dict) -> httpx.Response:
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = client.get(OPEN_METEO_URL, params=params)
            response.raise_for_status()
            return response
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code not in RETRYABLE_STATUS_CODES or attempt == MAX_ATTEMPTS:
                raise
        except httpx.TransportError:
            if attempt == MAX_ATTEMPTS:
                raise
        time.sleep(RETRY_BACKOFF_SECONDS * attempt)
    raise AssertionError("unreachable")  # loop always returns or raises above


def _cache_get(cache: Cache, key: str) -> str | None:
    # Render's free Redis can restart at any time; a cache outage should cost
    # us a cache miss, not fail the whole request.
    try:
        return cache.get(key)
    except redis.RedisError:
        return None


def _cache_set(cache: Cache, key: str, value: str) -> None:
    try:
        cache.set(key, value, FORECAST_CACHE_TTL_SECONDS)
    except redis.RedisError:
        pass


def _parse_hourly_response(payload: dict) -> WeatherForecast:
    hourly = payload["hourly"]
    times = hourly["time"]

    forecasts = [
        HourlyForecast(
            time=times[i],
            cloud_cover_low=hourly["cloud_cover_low"][i],
            cloud_cover_mid=hourly["cloud_cover_mid"][i],
            cloud_cover_high=hourly["cloud_cover_high"][i],
            visibility=hourly["visibility"][i],
            uv_index=hourly["uv_index"][i],
            precipitation_probability=hourly["precipitation_probability"][i],
            weather_code=hourly["weather_code"][i],
        )
        for i in range(len(times))
    ]
    return WeatherForecast(hourly=forecasts, timezone=payload.get("timezone"))
