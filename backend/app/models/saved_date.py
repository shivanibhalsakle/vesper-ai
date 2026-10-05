import uuid
from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import Boolean, Date, DateTime, Float, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class SavedDate(Base):
    """A sunrise/sunset the user wants to remember (and be reminded about):
    one place on one day.
    """

    __tablename__ = "saved_dates"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String, index=True, nullable=False)

    event_date: Mapped[date_type] = mapped_column(Date, nullable=False)
    event: Mapped[str] = mapped_column(String, nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lon: Mapped[float] = mapped_column(Float, nullable=False)
    label: Mapped[str] = mapped_column(String, nullable=False)

    # The match score shown when the user saved it (None if they had no sky
    # preferences). A snapshot — the live forecast is fetched when they open it.
    saved_score: Mapped[float | None] = mapped_column(Float, nullable=True)

    fcm_token: Mapped[str | None] = mapped_column(String, nullable=True)
    notification_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # Set once the day-before reminder has gone out, so it is sent only once.
    notified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
