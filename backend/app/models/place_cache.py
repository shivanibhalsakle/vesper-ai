from datetime import datetime, timezone

from sqlalchemy import DateTime, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class PlaceSearchCache(Base):
    """Durable copy of Overpass results per map cell, so a place search
    survives Redis restarts and Overpass outages (see app/services/places.py).
    """

    __tablename__ = "place_search_cache"

    cache_key: Mapped[str] = mapped_column(String, primary_key=True)
    payload: Mapped[list] = mapped_column(JSONB, nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
