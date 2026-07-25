from datetime import datetime

from pydantic import BaseModel


class SunEvents(BaseModel):
    dawn: datetime
    sunrise: datetime
    noon: datetime
    sunset: datetime
    dusk: datetime


class SunPosition(BaseModel):
    azimuth: float
    elevation: float
