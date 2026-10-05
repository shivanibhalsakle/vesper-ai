from app.schemas.weather import WeatherForecast

# Clients send "auto" (the default) to mean "the timezone of the place being
# queried". Open-Meteo resolves it from the coordinates when the forecast is
# fetched, so the forecast is the source of truth for the zone.
AUTO_TIMEZONE = "auto"


def resolve_timezone(requested: str, forecast: WeatherForecast) -> str:
    """The IANA zone to use for sun events, given what the caller asked for
    and the forecast fetched with that same request.
    """
    if requested == AUTO_TIMEZONE:
        return forecast.timezone or "UTC"
    return requested
