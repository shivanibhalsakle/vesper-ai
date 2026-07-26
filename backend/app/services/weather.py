from datetime import date

import httpx

from app.schemas.weather import HourlyForecast, WeatherForecast

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

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
) -> WeatherForecast:
    """Fetches hourly forecast from on_date through end_date (inclusive).

    end_date defaults to on_date for a single-day forecast. Open-Meteo
    accepts a date range in one call — Trip-Window Mode uses this to fetch
    a whole trip's forecast per candidate location in a single request
    instead of one call per (location, day) pair.
    """
    owns_client = client is None
    client = client or httpx.Client()
    try:
        response = client.get(
            OPEN_METEO_URL,
            params={
                "latitude": lat,
                "longitude": lon,
                "hourly": ",".join(HOURLY_VARIABLES),
                "start_date": on_date.isoformat(),
                "end_date": (end_date or on_date).isoformat(),
                "timezone": tz_name,
            },
        )
        response.raise_for_status()
        return _parse_hourly_response(response.json())
    finally:
        if owns_client:
            client.close()


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
    return WeatherForecast(hourly=forecasts)
