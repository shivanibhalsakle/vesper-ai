from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class ImageGenerationUsage(Base):
    """One row per (user, day), tracking how many /simulate images a user has
    generated that day — the basis for the daily per-user limit.
    """

    __tablename__ = "image_generation_usage"

    user_id: Mapped[str] = mapped_column(String, primary_key=True)
    usage_date: Mapped[date_type] = mapped_column(Date, primary_key=True)
    count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utcnow, onupdate=_utcnow, nullable=False
    )
