from datetime import datetime

from pydantic import BaseModel


class HourlyForecast(BaseModel):
    time: datetime
    cloud_cover_low: float
    cloud_cover_mid: float
    cloud_cover_high: float
    visibility: float
    uv_index: float
    precipitation_probability: float
    weather_code: int


class WeatherForecast(BaseModel):
    hourly: list[HourlyForecast]
    # IANA zone the hourly times are expressed in. When the request used
    # timezone="auto" this is the zone Open-Meteo resolved for the point.
    timezone: str | None = None
