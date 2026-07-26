import uuid
from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class FeedbackEntry(Base):
    __tablename__ = "feedback_entries"

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    location_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    location_name: Mapped[str] = mapped_column(String, nullable=False)
    location_type: Mapped[str] = mapped_column(String, nullable=False)
    event: Mapped[str] = mapped_column(String, nullable=False)
    event_date: Mapped[date_type] = mapped_column(Date, nullable=False)
    # Photo bytes live in Firebase Storage, not this backend — the client
    # uploads directly and sends us the resulting path/URL to record.
    photo_storage_path: Mapped[str] = mapped_column(String, nullable=False)
    user_id: Mapped[str | None] = mapped_column(String, nullable=True)
    preference_profile: Mapped[dict] = mapped_column(JSONB, nullable=False)
    forecast_snapshot: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc).replace(tzinfo=None), nullable=False
    )
