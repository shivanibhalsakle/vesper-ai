"""Which areas have our own place data loaded (see osm_loaded_regions).

Outside those areas the app has no reliable place data, so searches there say
so up front instead of waiting on the public Overpass service.
"""

import logging
import time
from collections.abc import Callable
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.data.us_regions import REGION_BOUNDS, region_name
from app.db.session import SessionLocal
from app.models.osm_place import OsmLoadedRegion

logger = logging.getLogger(__name__)

# Regions change only when someone runs the loader, so a short cache keeps this
# off the hot path while a newly loaded state still shows up within a minute.
CACHE_SECONDS = 60
MAX_NAMES_IN_MESSAGE = 10

_cache: tuple[float, list[str]] | None = None


class Coverage(Protocol):
    def covers(self, lat: float, lon: float) -> bool | None:
        """True/False if we know, None if coverage can't be determined."""
        ...


def reset_cache() -> None:
    global _cache
    _cache = None


def _load_from_db(session_factory: Callable[[], Session] = SessionLocal) -> list[str] | None:
    session = session_factory()
    try:
        return list(session.scalars(select(OsmLoadedRegion.region).order_by(OsmLoadedRegion.region)))
    except SQLAlchemyError:
        logger.warning("Loaded-region lookup failed", exc_info=True)
        return None
    finally:
        session.close()


def loaded_regions() -> list[str]:
    """Slugs of the regions loaded so far; empty if none, or if the lookup failed."""
    global _cache
    now = time.monotonic()
    if _cache is not None and now - _cache[0] < CACHE_SECONDS:
        return _cache[1]
    regions = _load_from_db()
    if regions is None:  # a database blip isn't "no regions"; don't remember it
        return []
    _cache = (now, regions)
    return regions


def region_containing(regions: list[str], lat: float, lon: float) -> str | None:
    for slug in regions:
        bounds = REGION_BOUNDS.get(slug)
        if bounds is None:
            continue
        south, west, north, east = bounds
        if south <= lat <= north and west <= lon <= east:
            return slug
    return None


class PostgresCoverage:
    def __init__(self, regions_source: Callable[[], list[str]] = loaded_regions):
        self._regions_source = regions_source

    def covers(self, lat: float, lon: float) -> bool | None:
        regions = self._regions_source()
        if not regions:
            # Nothing loaded (fresh database) or the lookup failed: we can't
            # say a place is outside coverage, so don't block anyone.
            return None
        return region_containing(regions, lat, lon) is not None


def covered_regions() -> list[dict]:
    """Loaded regions with a display name and bounds, for the app to show."""
    regions = []
    for slug in loaded_regions():
        bounds = REGION_BOUNDS.get(slug)
        if bounds is None:
            continue
        south, west, north, east = bounds
        regions.append(
            {
                "slug": slug,
                "name": region_name(slug),
                "south": south,
                "west": west,
                "north": north,
                "east": east,
            }
        )
    regions.sort(key=lambda region: region["name"])
    return regions


def outside_coverage_message(regions: list[dict] | None = None) -> str:
    regions = covered_regions() if regions is None else regions
    start = "Vesper doesn't cover this area yet."
    if not regions:
        return f"{start} More places are on the way."
    if len(regions) > MAX_NAMES_IN_MESSAGE:
        return f"{start} It currently covers {len(regions)} US states and regions, with more on the way."
    names = ", ".join(region["name"] for region in regions)
    return f"{start} It currently covers {names}, with more on the way."
