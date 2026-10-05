from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from app.schemas.best_date import BestDateRequest, BestDateResponse, BestDay, DayScore, Spot
from app.schemas.location import LocationRecord, LocationType
from app.schemas.scoring import ScoringResult
from app.schemas.session import SunEvent
from app.services.astronomy import get_sun_events
from app.services.places import find_candidate_locations
from app.services.scoring import score_location
from app.services.sky import build_sky_response, confidence_for_lead_days
from app.services.timezones import resolve_timezone
from app.services.weather import fetch_hourly_forecast

# Same bound as /session and /trip-window: each spot is one forecast call.
MAX_CANDIDATES_SCORED = 15
MAX_PARALLEL_FORECASTS = 8

# Days whose score is within this of the top score count as equally good;
# the earliest of them wins, because nearer-term forecasts are more reliable.
TIE_TOLERANCE = 0.02


@dataclass
class _DayBest:
    spot: LocationRecord | None
    event_time: datetime
    tz_name: str
    local_now: datetime
    score: ScoringResult


def find_best_dates(request: BestDateRequest, now: datetime | None = None) -> BestDateResponse:
    end_date = request.start_date + timedelta(days=request.days - 1)
    place_types = request.place_types or list(LocationType)

    candidates = find_candidate_locations(
        request.lat, request.lon, request.radius_km, place_types
    )[:MAX_CANDIDATES_SCORED]
    # No mapped spots in range: still answer, using the searched point itself.
    spots: list[LocationRecord | None] = list(candidates) or [None]

    def forecast_for(spot: LocationRecord | None):
        lat, lon = (spot.lat, spot.lon) if spot else (request.lat, request.lon)
        return fetch_hourly_forecast(
            lat, lon, request.start_date, request.tz_name, end_date=end_date
        )

    with ThreadPoolExecutor(max_workers=min(MAX_PARALLEL_FORECASTS, len(spots))) as pool:
        forecasts = list(pool.map(forecast_for, spots))

    best_by_day: dict[date, _DayBest] = {}
    for spot, forecast in zip(spots, forecasts):
        tz_name = resolve_timezone(request.tz_name, forecast)
        local_now = (now or datetime.now(ZoneInfo(tz_name))).astimezone(ZoneInfo(tz_name))
        lat, lon = (spot.lat, spot.lon) if spot else (request.lat, request.lon)

        for offset in range(request.days):
            on_date = request.start_date + timedelta(days=offset)
            sun_events = get_sun_events(lat, lon, on_date, tz_name)
            event_time = (
                sun_events.sunset if request.event == SunEvent.SUNSET else sun_events.sunrise
            )
            if event_time < local_now:
                continue  # e.g. this morning's sunrise — can't be watched any more

            score = score_location(event_time, forecast.hourly, request.preferences)
            current = best_by_day.get(on_date)
            if current is None or score.preference_match_score > current.score.preference_match_score:
                best_by_day[on_date] = _DayBest(spot, event_time, tz_name, local_now, score)

    days = [
        DayScore(
            date=on_date,
            score=day.score.preference_match_score,
            confidence=confidence_for_lead_days(_lead_days(on_date, day.local_now)),
            spot_name=day.spot.name if day.spot else None,
        )
        for on_date, day in sorted(best_by_day.items())
    ]

    chosen = pick_best_day(days)
    best = None
    if chosen is not None:
        day = best_by_day[chosen.date]
        best = BestDay(
            date=chosen.date,
            spot=_spot_info(day.spot),
            sky=build_sky_response(
                request.event,
                chosen.date,
                day.tz_name,
                day.event_time,
                day.score,
                request.preferences,
                day.local_now,
            ),
        )

    return BestDateResponse(days=days, best=best, spots_considered=len(candidates))


def _lead_days(on_date: date, local_now: datetime) -> int:
    return max(0, (on_date - local_now.date()).days)


def pick_best_day(days: list[DayScore]) -> DayScore | None:
    """The earliest day whose score is within TIE_TOLERANCE of the top one."""
    if not days:
        return None
    top = max(day.score for day in days)
    return next(day for day in sorted(days, key=lambda d: d.date) if day.score >= top - TIE_TOLERANCE)


def _spot_info(spot: LocationRecord | None) -> Spot | None:
    if spot is None:
        return None
    return Spot(
        location_id=spot.id,
        name=spot.name,
        type=spot.type,
        lat=spot.lat,
        lon=spot.lon,
        distance_km=spot.distance_km,
    )
