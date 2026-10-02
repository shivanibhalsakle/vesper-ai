from datetime import date

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.image_usage import ImageGenerationUsage

# Per-user cap bounds any one user's cost exposure. The global cap is a
# backstop in case the per-user check has a bug or is bypassed somehow — it
# caps total images/day across every user regardless of who's asking.
DAILY_LIMIT_PER_USER = 5
GLOBAL_DAILY_LIMIT = 200


class ImageLimitExceeded(Exception):
    """Raised when generating another image would exceed a daily cap."""


def ensure_within_daily_limit(db: Session, user_id: str, on_date: date | None = None) -> None:
    """Raises ImageLimitExceeded if the user (or the whole app) has already
    hit today's cap. Pure check — does not record anything; call
    record_usage() after a successful generation.
    """
    on_date = on_date or date.today()

    global_total = (
        db.query(func.coalesce(func.sum(ImageGenerationUsage.count), 0))
        .filter(ImageGenerationUsage.usage_date == on_date)
        .scalar()
    )
    if global_total >= GLOBAL_DAILY_LIMIT:
        raise ImageLimitExceeded(
            "Vesper has hit its daily sky-preview limit across all users. Please try again tomorrow."
        )

    if _usage_count(db, user_id, on_date) >= DAILY_LIMIT_PER_USER:
        raise ImageLimitExceeded(
            f"You've used all {DAILY_LIMIT_PER_USER} sky previews for today. "
            "Come back tomorrow for more!"
        )


def record_usage(db: Session, user_id: str, on_date: date | None = None) -> None:
    """Records one real image generation. Only call this after the provider
    actually succeeds — a failed/unconfigured attempt shouldn't cost the
    user one of their daily previews, and a cache hit costs us nothing so
    it shouldn't either (see generate_simulation).
    """
    on_date = on_date or date.today()
    row = _usage_row(db, user_id, on_date)
    if row is None:
        db.add(ImageGenerationUsage(user_id=user_id, usage_date=on_date, count=1))
    else:
        row.count += 1
    db.commit()


def remaining_today(db: Session, user_id: str, on_date: date | None = None) -> int:
    on_date = on_date or date.today()
    return max(0, DAILY_LIMIT_PER_USER - _usage_count(db, user_id, on_date))


def _usage_row(db: Session, user_id: str, on_date: date) -> ImageGenerationUsage | None:
    return (
        db.query(ImageGenerationUsage)
        .filter(
            ImageGenerationUsage.user_id == user_id,
            ImageGenerationUsage.usage_date == on_date,
        )
        .first()
    )


def _usage_count(db: Session, user_id: str, on_date: date) -> int:
    row = _usage_row(db, user_id, on_date)
    return row.count if row else 0
