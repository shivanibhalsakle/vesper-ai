import logging
import math
from collections.abc import Callable, Iterable
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.osm_place import OsmPlace
from app.schemas.location import LocationType

logger = logging.getLogger(__name__)

# One bit per place type, persisted in osm_places.type_mask — append new types
# with the next bit, never reorder or reuse.
TYPE_BITS: dict[LocationType, int] = {
    LocationType.BEACH: 1,
    LocationType.PARK: 2,
    LocationType.WATERFRONT: 4,
    LocationType.PROMENADE: 8,
    LocationType.ELEVATED_VIEWPOINT: 16,
}

KM_PER_DEGREE = 111.32
# Callers only score the nearest few candidates, so the index never needs to
# hand back more than this — it keeps big-radius queries in dense cities cheap.
MAX_RESULTS = 500


def types_to_mask(place_types: Iterable[LocationType]) -> int:
    mask = 0
    for place_type in place_types:
        mask |= TYPE_BITS[place_type]
    return mask


def mask_to_types(mask: int) -> list[LocationType]:
    return [t for t, bit in TYPE_BITS.items() if mask & bit]


class PlaceIndex(Protocol):
    def search(
        self, lat: float, lon: float, radius_km: float, place_types: list[LocationType]
    ) -> list[dict]: ...


class PostgresPlaceIndex:
    """Searches our own osm_places table. Database trouble is logged and
    treated as "nothing found" so the caller can fall through to other
    sources instead of failing the whole request.
    """

    def __init__(self, session_factory: Callable[[], Session] = SessionLocal):
        self._session_factory = session_factory

    def search(
        self, lat: float, lon: float, radius_km: float, place_types: list[LocationType]
    ) -> list[dict]:
        mask = types_to_mask(place_types)
        cos_lat = max(math.cos(math.radians(lat)), 0.01)
        dlat = radius_km / KM_PER_DEGREE
        dlon = radius_km / (KM_PER_DEGREE * cos_lat)

        # Planar distance is only for ordering the bounding-box hits; callers
        # apply the exact haversine radius check afterwards.
        d_lat = OsmPlace.lat - lat
        d_lon = (OsmPlace.lon - lon) * cos_lat
        statement = (
            select(OsmPlace)
            .where(
                OsmPlace.lat.between(lat - dlat, lat + dlat),
                OsmPlace.lon.between(lon - dlon, lon + dlon),
                OsmPlace.type_mask.op("&")(mask) != 0,
            )
            .order_by(d_lat * d_lat + d_lon * d_lon)
            .limit(MAX_RESULTS)
        )

        session = self._session_factory()
        try:
            rows = session.scalars(statement).all()
        except SQLAlchemyError:
            logger.warning("Place index query failed", exc_info=True)
            return []
        else:
            return [
                {
                    "id": row.id,
                    "name": row.name,
                    "types": [t.value for t in mask_to_types(row.type_mask)],
                    "lat": row.lat,
                    "lon": row.lon,
                }
                for row in rows
            ]
        finally:
            session.close()
