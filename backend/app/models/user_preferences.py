from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class UserPreferences(Base):
    """One row per user: their saved home location, search defaults and sky
    preference sliders. The Settings screen reads and writes this, and the
    home-screen flows default to it.
    """

    __tablename__ = "user_preferences"

    user_id: Mapped[str] = mapped_column(String, primary_key=True)

    home_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    home_lon: Mapped[float | None] = mapped_column(Float, nullable=True)
    # Human-readable name for the saved location (e.g. "Brooklyn, NY").
    home_label: Mapped[str | None] = mapped_column(String, nullable=True)

    radius_km: Mapped[float] = mapped_column(Float, nullable=False, default=10.0)
    place_types: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    event: Mapped[str] = mapped_column(String, nullable=False, default="sunset")
    preference_profile: Mapped[dict] = mapped_column(JSONB, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utcnow, onupdate=_utcnow, nullable=False
    )
