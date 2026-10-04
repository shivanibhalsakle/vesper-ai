from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models.osm_place import OsmLoadedRegion, OsmPlace
from app.services.place_index import types_to_mask
from app.services.places import TAG_QUERIES

# Well under Postgres' 65k bind-parameter limit (5 columns per row).
BATCH_SIZE = 5000


def mask_for_tags(tags) -> int:
    """Place-type bitmask for an OSM tag set (a dict or osmium's TagList),
    using the same tag mapping the Overpass path queries with.
    """
    mask = 0
    for place_type, tag_pairs in TAG_QUERIES.items():
        if any(tags.get(key) == value for key, value in tag_pairs):
            mask |= types_to_mask([place_type])
    return mask


def upsert_places(session: Session, rows: list[dict]) -> None:
    """Insert-or-update by id, so re-running a region (or loading two states
    that share a border feature) is safe.
    """
    for start in range(0, len(rows), BATCH_SIZE):
        unique_rows = list({row["id"]: row for row in rows[start : start + BATCH_SIZE]}.values())
        statement = insert(OsmPlace).values(unique_rows)
        statement = statement.on_conflict_do_update(
            index_elements=[OsmPlace.id],
            set_={
                "name": statement.excluded.name,
                "type_mask": statement.excluded.type_mask,
                "lat": statement.excluded.lat,
                "lon": statement.excluded.lon,
            },
        )
        session.execute(statement)
    session.commit()


def region_loaded(session: Session, region: str) -> bool:
    return session.get(OsmLoadedRegion, region) is not None


def record_region(session: Session, region: str, row_count: int) -> None:
    session.merge(
        OsmLoadedRegion(
            region=region,
            row_count=row_count,
            loaded_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )
    session.commit()


def database_size_mb(session: Session) -> float:
    size_bytes = session.execute(text("SELECT pg_database_size(current_database())")).scalar()
    return size_bytes / (1024 * 1024)
