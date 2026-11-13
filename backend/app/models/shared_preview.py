import uuid
from datetime import date as date_type
from datetime import datetime, timezone

from sqlalchemy import Date, DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class SharedPreview(Base):
    """A sky preview of a known public place, shown to every user who looks at
    that place. Deliberately anonymous: there is no user column here and there
    must never be one. The person's own copy lives in generated_previews and is
    deleted with their account; this one is a separate file with no link back
    to them, so it stays when they leave.
    """

    __tablename__ = "shared_previews"
    __table_args__ = (
        # The same sky at the same place is one preview, however many people made it.
        UniqueConstraint("place_id", "prompt_hash", name="uq_shared_previews_place_prompt"),
    )

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    # "osm:way/123" or "curated:..." — only places we know, never a typed address.
    place_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    # Taken from our own place data, not from what the app sent.
    place_name: Mapped[str] = mapped_column(String, nullable=False)
    place_type: Mapped[str | None] = mapped_column(String, nullable=True)
    event: Mapped[str] = mapped_column(String, nullable=False)
    # The day the previewed sky is for, when the app said (older app versions don't).
    event_date: Mapped[date_type | None] = mapped_column(Date, nullable=True)
    prompt_hash: Mapped[str] = mapped_column(String, nullable=False)

    storage_path: Mapped[str] = mapped_column(String, nullable=False)
    thumb_path: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
