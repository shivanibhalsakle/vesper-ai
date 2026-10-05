from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.saved_date import SavedDate
from app.schemas.saved_date import SavedDateCreate

# Bounds any one account's footprint (and its reminder work in the daily job).
MAX_SAVED_DATES_PER_USER = 100

# Two saves within ~100 m of each other are the same place.
SAME_PLACE_DEGREES = 0.001


class SavedDateLimitReached(Exception):
    """The user already has the maximum number of saved dates."""


def create_saved_date(db: Session, user_id: str, data: SavedDateCreate) -> SavedDate:
    """Saves a date. Saving the same place/day/event again returns the
    existing row (refreshing its reminder token) instead of a duplicate, so
    a double tap or a retry is harmless.
    """
    existing = _find_same(db, user_id, data)
    if existing is not None:
        if data.fcm_token:
            existing.fcm_token = data.fcm_token
            db.commit()
            db.refresh(existing)
        return existing

    count = db.query(func.count(SavedDate.id)).filter(SavedDate.user_id == user_id).scalar()
    if count >= MAX_SAVED_DATES_PER_USER:
        raise SavedDateLimitReached(
            f"You can save up to {MAX_SAVED_DATES_PER_USER} dates. Remove some to add more."
        )

    row = SavedDate(
        user_id=user_id,
        event_date=data.event_date,
        event=data.event.value,
        lat=data.lat,
        lon=data.lon,
        label=data.label,
        saved_score=data.saved_score,
        fcm_token=data.fcm_token,
        notification_enabled=data.notification_enabled,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def list_saved_dates(db: Session, user_id: str) -> list[SavedDate]:
    return (
        db.query(SavedDate)
        .filter(SavedDate.user_id == user_id)
        .order_by(SavedDate.event_date, SavedDate.created_at)
        .all()
    )


def get_saved_date(db: Session, user_id: str, saved_date_id: str) -> SavedDate | None:
    """The user's own saved date, or None — another user's id looks the same
    as a missing one, so ids can't be probed.
    """
    return (
        db.query(SavedDate)
        .filter(SavedDate.id == saved_date_id, SavedDate.user_id == user_id)
        .first()
    )


def delete_saved_date(db: Session, user_id: str, saved_date_id: str) -> bool:
    row = get_saved_date(db, user_id, saved_date_id)
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def set_notification_enabled(
    db: Session, user_id: str, saved_date_id: str, enabled: bool
) -> SavedDate | None:
    row = get_saved_date(db, user_id, saved_date_id)
    if row is None:
        return None
    row.notification_enabled = enabled
    db.commit()
    db.refresh(row)
    return row


def _find_same(db: Session, user_id: str, data: SavedDateCreate) -> SavedDate | None:
    candidates = (
        db.query(SavedDate)
        .filter(
            SavedDate.user_id == user_id,
            SavedDate.event_date == data.event_date,
            SavedDate.event == data.event.value,
        )
        .all()
    )
    for row in candidates:
        if (
            abs(row.lat - data.lat) <= SAME_PLACE_DEGREES
            and abs(row.lon - data.lon) <= SAME_PLACE_DEGREES
        ):
            return row
    return None
