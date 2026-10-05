import logging
from collections.abc import Callable
from datetime import date, datetime, timedelta, timezone

import httpx
from sqlalchemy.orm import Session

from app.models.saved_date import SavedDate
from app.models.user_preferences import UserPreferences
from app.schemas.preferences import PreferenceProfile
from app.schemas.session import SunEvent
from app.schemas.sky import SkyRequest, SkyResponse
from app.services.notifications import (
    PushNotifier,
    _get_default_notifier,
    send_notification_safely,
)
from app.services.sky import sky_at

logger = logging.getLogger(__name__)


def send_saved_date_reminders(
    db: Session,
    on_date: date | None = None,
    notifier: PushNotifier | None = None,
    sky_fn: Callable[[SkyRequest], SkyResponse] = sky_at,
) -> tuple[list[dict], set[str]]:
    """Sends the day-before reminder for every saved date falling on
    `on_date` (default: tomorrow), each at most once, using a fresh forecast.

    Returns a per-date summary plus the ids of users who actually received a
    reminder, so the saved-search alerts can step aside for them: a date the
    user chose themselves takes priority over an automatic match.
    """
    target_date = on_date or (date.today() + timedelta(days=1))
    rows = (
        db.query(SavedDate)
        .filter(
            SavedDate.event_date == target_date,
            SavedDate.notification_enabled.is_(True),
            SavedDate.notified_at.is_(None),
        )
        .all()
    )
    if not rows:
        return [], set()

    notifier = notifier or _get_default_notifier()
    preferences_by_user: dict[str, PreferenceProfile | None] = {}

    results: list[dict] = []
    notified_users: set[str] = set()
    for row in rows:
        if not row.fcm_token:
            results.append({"saved_date_id": row.id, "status": "no_fcm_token"})
            continue

        if row.user_id not in preferences_by_user:
            stored = db.get(UserPreferences, row.user_id)
            preferences_by_user[row.user_id] = (
                PreferenceProfile(**stored.preference_profile) if stored else None
            )

        try:
            sky = sky_fn(
                SkyRequest(
                    lat=row.lat,
                    lon=row.lon,
                    event=SunEvent(row.event),
                    date=row.event_date,
                    preferences=preferences_by_user[row.user_id],
                )
            )
        except httpx.HTTPError:
            logger.warning("Skipping saved date %s: weather unavailable", row.id, exc_info=True)
            results.append({"saved_date_id": row.id, "status": "data_unavailable"})
            continue

        title, body = build_reminder(row, sky)
        sent, status = send_notification_safely(notifier, row.fcm_token, title, body)
        if sent:
            row.notified_at = datetime.now(timezone.utc).replace(tzinfo=None)
            notified_users.add(row.user_id)
        results.append({"saved_date_id": row.id, "status": status})

    db.commit()
    return results, notified_users


def build_reminder(row: SavedDate, sky: SkyResponse) -> tuple[str, str]:
    event_word = "Sunrise" if row.event == "sunrise" else "Sunset"
    title = f"{event_word} tomorrow: {row.label}"

    summary = sky.cloud_cover_summary
    summary = summary[0].upper() + summary[1:]
    if sky.preference_match_score is not None:
        body = f"{sky.preference_match_score:.0%} match to your taste. {summary}."
    else:
        body = f"{summary}."
    if sky.rain_or_unsafe_alert:
        body += f" {sky.rain_or_unsafe_alert}"
    return title, body
