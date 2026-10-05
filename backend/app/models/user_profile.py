from datetime import datetime, timezone

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class UserProfile(Base):
    """Who the user is in the app: display name, optional phone, and either an
    uploaded photo or a chosen avatar. The email isn't stored here - it comes
    from the verified sign-in token. A profile existing at all is also how the
    app knows onboarding is done.
    """

    __tablename__ = "user_profiles"

    user_id: Mapped[str] = mapped_column(String, primary_key=True)

    display_name: Mapped[str] = mapped_column(String, nullable=False)
    phone: Mapped[str | None] = mapped_column(String, nullable=True)

    # Firebase Storage path of an uploaded photo (profiles/{user_id}/...).
    photo_storage_path: Mapped[str | None] = mapped_column(String, nullable=True)
    # Id of a built-in avatar. At most one of photo/avatar is set.
    avatar_id: Mapped[str | None] = mapped_column(String, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utcnow, onupdate=_utcnow, nullable=False
    )
