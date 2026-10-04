from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, Index, Integer, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class OsmPlace(Base):
    """Our own copy of the named OpenStreetMap places the app recommends
    (parks, beaches, viewpoints, ...), loaded in bulk from regional extracts
    by backend/scripts/load_osm_places.py. Queried at request time instead of
    the public Overpass API, which has no uptime guarantee.
    """

    __tablename__ = "osm_places"

    # Same "osm:node/123" / "osm:way/456" ids the Overpass path produces, so
    # a place keeps one identity (feedback, dedupe) whichever source served it.
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    # Bitmask of LocationType (see app/services/place_index.py TYPE_BITS).
    type_mask: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lon: Mapped[float] = mapped_column(Float, nullable=False)

    __table_args__ = (Index("ix_osm_places_lat_lon", "lat", "lon"),)


class OsmLoadedRegion(Base):
    """One row per extract the loader has finished, so a multi-hour run can
    resume and we can tell which areas are covered.
    """

    __tablename__ = "osm_loaded_regions"

    region: Mapped[str] = mapped_column(String, primary_key=True)
    row_count: Mapped[int] = mapped_column(Integer, nullable=False)
    loaded_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
