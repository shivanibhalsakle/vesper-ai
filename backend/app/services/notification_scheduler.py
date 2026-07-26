from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.models.saved_profile import SavedProfile
from app.schemas.location import LocationRecord, LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ScoringResult
from app.services.astronomy import get_sun_events
from app.services.notifications import (
    PushNotifier,
    UnconfiguredPushNotifier,
    send_notification_safely,
)
from app.services.places import find_candidate_locations
from app.services.saved_profiles import list_enabled_saved_profiles
from app.services.scoring import score_location
from app.services.weather import fetch_hourly_forecast

# Same bound as the /session endpoint, for the same reason — each candidate
# is an external Open-Meteo call.
MAX_CANDIDATES_SCORED = 10


def rescore_saved_profiles(
    db: Session,
    on_date: date | None = None,
    notifier: PushNotifier | None = None,
) -> list[dict]:
    """Re-scores each saved profile's area for the given date (default:
    tomorrow) and sends a push notification when the best match clears the
    profile's threshold. Returns a per-profile summary, useful for logging
    from the Celery task and for testing without needing a real notifier.
    """
    notifier = notifier or UnconfiguredPushNotifier()
    target_date = on_date or (date.today() + timedelta(days=1))

    results = []
    for profile in list_enabled_saved_profiles(db):
        if not profile.fcm_token:
            results.append({"profile_id": profile.id, "status": "no_fcm_token"})
            continue

        best = _best_match_for_profile(profile, target_date)
        if best is None:
            results.append({"profile_id": profile.id, "status": "no_candidates"})
            continue

        location, score = best
        if score.preference_match_score < profile.match_threshold:
            results.append(
                {
                    "profile_id": profile.id,
                    "status": "below_threshold",
                    "best_score": score.preference_match_score,
                }
            )
            continue

        title, body = _build_notification_content(profile, location, score)
        sent, notify_status = send_notification_safely(
            notifier, profile.fcm_token, title, body
        )
        results.append(
            {
                "profile_id": profile.id,
                "status": notify_status,
                "best_score": score.preference_match_score,
                "location_name": location.name,
            }
        )

    return results


def _best_match_for_profile(
    profile: SavedProfile, target_date: date
) -> tuple[LocationRecord, ScoringResult] | None:
    place_types = [LocationType(t) for t in profile.place_types]
    candidates = find_candidate_locations(
        profile.home_lat, profile.home_lon, profile.radius_km, place_types
    )[:MAX_CANDIDATES_SCORED]
    if not candidates:
        return None

    preferences = PreferenceProfile(**profile.preference_profile)

    best_location = None
    best_score = None
    for candidate in candidates:
        sun_events = get_sun_events(
            candidate.lat, candidate.lon, target_date, profile.tz_name
        )
        event_time = sun_events.sunset if profile.event == "sunset" else sun_events.sunrise
        forecast = fetch_hourly_forecast(
            candidate.lat, candidate.lon, target_date, profile.tz_name
        )
        score = score_location(event_time, forecast.hourly, preferences)
        if best_score is None or score.preference_match_score > best_score.preference_match_score:
            best_location, best_score = candidate, score

    if best_location is None or best_score is None:
        return None
    return best_location, best_score


def _build_notification_content(
    profile: SavedProfile, location: LocationRecord, score: ScoringResult
) -> tuple[str, str]:
    event_word = "Sunrise" if profile.event == "sunrise" else "Sunset"
    title = f"{event_word} alert: {location.name} looks great tomorrow"
    body = f"{score.preference_match_score:.0%} match to your taste — {score.cloud_cover_summary}."
    return title, body
