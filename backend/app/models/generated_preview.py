import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class GeneratedPreview(Base):
    """A sky preview image a user generated, kept so they can revisit it.
    The image itself lives in Firebase Storage at `storage_path`; this row is
    only the (small) record of it.
    """

    __tablename__ = "generated_previews"
    __table_args__ = (
        # The same sky for the same user is one preview, not many.
        UniqueConstraint("user_id", "prompt_hash", name="uq_generated_previews_user_prompt"),
    )

    id: Mapped[str] = mapped_column(
        String, primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    prompt_hash: Mapped[str] = mapped_column(String, nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)

    location_name: Mapped[str] = mapped_column(String, nullable=False)
    location_type: Mapped[str] = mapped_column(String, nullable=False)
    event: Mapped[str] = mapped_column(String, nullable=False)

    storage_path: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
