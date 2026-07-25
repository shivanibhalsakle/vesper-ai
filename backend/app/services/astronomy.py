from datetime import date, datetime

from astral import Observer
from astral.sun import azimuth, elevation, sun

from app.schemas.astronomy import SunEvents, SunPosition


def get_sun_events(lat: float, lon: float, on_date: date, tz_name: str = "UTC") -> SunEvents:
    observer = Observer(latitude=lat, longitude=lon)
    events = sun(observer, date=on_date, tzinfo=tz_name)
    return SunEvents(
        dawn=events["dawn"],
        sunrise=events["sunrise"],
        noon=events["noon"],
        sunset=events["sunset"],
        dusk=events["dusk"],
    )


def get_sun_position(lat: float, lon: float, at: datetime) -> SunPosition:
    observer = Observer(latitude=lat, longitude=lon)
    return SunPosition(azimuth=azimuth(observer, at), elevation=elevation(observer, at))
