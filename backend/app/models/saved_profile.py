import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class SavedProfile(Base):
    __tablename__ = "saved_profiles"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    # No Firebase Auth wired up yet — client supplies a stable identifier
    # (future Firebase UID) so notifications can be addressed to someone.
    user_id: Mapped[str] = mapped_column(String, index=True, nullable=False)

    home_lat: Mapped[float] = mapped_column(Float, nullable=False)
    home_lon: Mapped[float] = mapped_column(Float, nullable=False)
    radius_km: Mapped[float] = mapped_column(Float, nullable=False)
    place_types: Mapped[list] = mapped_column(JSONB, nullable=False)
    event: Mapped[str] = mapped_column(String, nullable=False)
    tz_name: Mapped[str] = mapped_column(String, nullable=False, default="UTC")
    preference_profile: Mapped[dict] = mapped_column(JSONB, nullable=False)

    fcm_token: Mapped[str | None] = mapped_column(String, nullable=True)
    notification_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    match_threshold: Mapped[float] = mapped_column(Float, nullable=False, default=0.75)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utcnow, onupdate=_utcnow, nullable=False
    )
