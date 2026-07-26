from dataclasses import dataclass
from datetime import date, datetime, timedelta

from app.schemas.location import LocationRecord, LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ScoringResult
from app.schemas.session import SunEvent
from app.services.astronomy import get_sun_events
from app.services.places import find_candidate_locations
from app.services.scoring import score_location
from app.services.weather import fetch_hourly_forecast

# Same bound as /session, for the same reason — each candidate is an
# external Open-Meteo call (one call per candidate covers the whole
# trip window, not one call per day, so this bound doesn't scale with
# window length).
MAX_CANDIDATES_SCORED = 15

BestMatch = tuple[LocationRecord, date, datetime, ScoringResult]


@dataclass
class TripWindowSearchResult:
    best: BestMatch | None
    candidates_considered: int


def find_best_day_and_location(
    lat: float,
    lon: float,
    event: SunEvent,
    start_date: date,
    end_date: date,
    radius_km: float,
    place_types: list[LocationType],
    preferences: PreferenceProfile,
    tz_name: str = "UTC",
) -> TripWindowSearchResult:
    candidates = find_candidate_locations(lat, lon, radius_km, place_types)[
        :MAX_CANDIDATES_SCORED
    ]

    best: BestMatch | None = None
    for candidate in candidates:
        forecast = fetch_hourly_forecast(
            candidate.lat, candidate.lon, start_date, tz_name, end_date=end_date
        )

        current_date = start_date
        while current_date <= end_date:
            sun_events = get_sun_events(candidate.lat, candidate.lon, current_date, tz_name)
            event_time = (
                sun_events.sunset if event == SunEvent.SUNSET else sun_events.sunrise
            )
            score = score_location(event_time, forecast.hourly, preferences)

            if best is None or score.preference_match_score > best[3].preference_match_score:
                best = (candidate, current_date, event_time, score)

            current_date += timedelta(days=1)

    return TripWindowSearchResult(best=best, candidates_considered=len(candidates))
