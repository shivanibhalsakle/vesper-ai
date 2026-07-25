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
