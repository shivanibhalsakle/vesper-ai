"""The shared, anonymous collection of sky previews for each known place.

When someone generates a preview for a known public place, a copy goes into a
collection that anyone looking at that place can open. The copy is separate from
the person's own gallery and holds no user id at all, so it never reveals who
made it and survives their account being deleted.
"""

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, not_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.data.curated_locations import CURATED_LOCATIONS
from app.models.generated_preview import GeneratedPreview
from app.models.osm_place import OsmPlace
from app.models.shared_preview import SharedPreview
from app.schemas.simulation import PlacePreviewCount, SharedPreviewRecord, SimulationRequest
from app.services.place_index import mask_to_types
from app.services.preview_storage import PreviewStorage, make_thumbnail

logger = logging.getLogger(__name__)

# Only this many previews are kept and shown per place, newest first.
MAX_PER_PLACE = 12
# A forecast picture from long ago says little about the sky now: older ones
# are hidden, and removed the next time that place gets a new preview.
MAX_AGE_DAYS = 90
# One person can add at most this many previews of one place, so a place can't
# look popular because a single person kept generating.
MAX_PER_PERSON_PER_PLACE = 3
# At this many previews a place is labelled popular.
POPULAR_AT = 10
# Counts are asked for a screenful of places at a time.
MAX_PLACES_PER_COUNT_REQUEST = 30

STORAGE_FOLDER = "shared-previews"


@dataclass(frozen=True)
class TrustedPlace:
    """A place as our own data knows it, not as the app described it."""

    id: str
    name: str
    type: str | None


def resolve_place(db: Session, place_id: str | None) -> TrustedPlace | None:
    """The place with this id from our curated list or loaded OSM data, or
    None. Only places we know are ever shared, so an address someone typed or
    their current location can never end up in the collection.
    """
    if not place_id:
        return None
    for entry in CURATED_LOCATIONS:
        if entry["id"] == place_id:
            return TrustedPlace(id=place_id, name=entry["name"], type=entry["type"].value)
    row = db.get(OsmPlace, place_id)
    if row is None:
        return None
    types = mask_to_types(row.type_mask)
    return TrustedPlace(id=row.id, name=row.name, type=types[0].value if types else None)


def _cutoff(now: datetime | None) -> datetime:
    now = now or datetime.now(timezone.utc).replace(tzinfo=None)
    return now - timedelta(days=MAX_AGE_DAYS)


def share_preview(
    db: Session,
    storage: PreviewStorage,
    user_id: str,
    request: SimulationRequest,
    prompt_hash: str,
    image_bytes: bytes,
    now: datetime | None = None,
) -> bool:
    """Adds an anonymous copy of this preview to its place's collection. The
    request's place_id must already be a resolved, trusted one. Returns whether
    a copy was added; false when this person already added their share for the
    place, or this exact sky is already there.
    """
    place_id = request.place_id
    if not place_id:
        return False

    # The person's own gallery rows (this new one included) are only used to
    # count; nothing about them is copied into the shared row.
    made_here = (
        db.query(GeneratedPreview)
        .filter(GeneratedPreview.user_id == user_id, GeneratedPreview.place_id == place_id)
        .count()
    )
    if made_here > MAX_PER_PERSON_PER_PLACE:
        return False
    if (
        db.query(SharedPreview)
        .filter(SharedPreview.place_id == place_id, SharedPreview.prompt_hash == prompt_hash)
        .first()
        is not None
    ):
        return False

    shared_id = str(uuid.uuid4())
    path = f"{STORAGE_FOLDER}/{shared_id}.webp"
    thumb_path = f"{STORAGE_FOLDER}/{shared_id}-thumb.webp"
    uploaded: list[str] = []
    try:
        storage.upload(path, image_bytes, "image/webp")
        uploaded.append(path)
        storage.upload(thumb_path, make_thumbnail(image_bytes), "image/webp")
        uploaded.append(thumb_path)
        db.add(
            SharedPreview(
                id=shared_id,
                place_id=place_id,
                place_name=request.location_name,
                place_type=request.location_type.value if request.location_type else None,
                event=request.event.value,
                event_date=request.event_date,
                prompt_hash=prompt_hash,
                storage_path=path,
                thumb_path=thumb_path,
            )
        )
        db.commit()
    except IntegrityError:
        db.rollback()  # two people made the same sky at the same moment
        _delete_blobs(storage, uploaded)
        return False
    except Exception:
        db.rollback()
        _delete_blobs(storage, uploaded)
        raise

    _tidy(db, storage, place_id, now)
    return True


def _tidy(db: Session, storage: PreviewStorage, place_id: str, now: datetime | None) -> None:
    """Keeps a place's collection to the newest few that are still fresh."""
    rows = (
        db.query(SharedPreview)
        .filter(SharedPreview.place_id == place_id)
        .order_by(SharedPreview.created_at.desc(), SharedPreview.id)
        .all()
    )
    cutoff = _cutoff(now)
    for index, row in enumerate(rows):
        if index >= MAX_PER_PLACE or row.created_at < cutoff:
            paths = [row.storage_path, row.thumb_path]
            db.delete(row)
            db.commit()
            _delete_blobs(storage, paths)


def _delete_blobs(storage: PreviewStorage, paths: list[str]) -> None:
    for path in paths:
        try:
            storage.delete(path)
        except Exception:
            # A leftover file costs almost nothing; never fail a request over it.
            logger.warning("Could not delete shared preview file %s", path, exc_info=True)


def _others_only(user_id: str):
    """Rows whose sky this person hasn't already generated themselves. Matching
    on the prompt hash finds their own contributions without the shared rows
    ever storing who made them; those are in the person's own gallery already.
    """
    mine = select(GeneratedPreview.prompt_hash).where(GeneratedPreview.user_id == user_id)
    return not_(SharedPreview.prompt_hash.in_(mine))


def list_shared(
    db: Session,
    storage: PreviewStorage,
    user_id: str,
    place_id: str,
    now: datetime | None = None,
) -> list[SharedPreviewRecord]:
    """The place's collection, newest first, without this person's own."""
    rows = (
        db.query(SharedPreview)
        .filter(
            SharedPreview.place_id == place_id,
            SharedPreview.created_at >= _cutoff(now),
            _others_only(user_id),
        )
        .order_by(SharedPreview.created_at.desc(), SharedPreview.id)
        .limit(MAX_PER_PLACE)
        .all()
    )
    records = []
    for row in rows:
        try:
            image_url = storage.signed_url(row.storage_path)
            thumb_url = storage.signed_url(row.thumb_path)
        except Exception:
            continue  # one unreadable file shouldn't hide the rest
        records.append(
            SharedPreviewRecord(
                id=row.id,
                image_url=image_url,
                thumb_url=thumb_url,
                place_name=row.place_name,
                event=row.event,
                event_date=row.event_date,
                created_at=row.created_at,
            )
        )
    return records


def counts_for(
    db: Session, user_id: str, place_ids: list[str], now: datetime | None = None
) -> list[PlacePreviewCount]:
    """For each place: how many previews by others there are to open, and
    whether the place is popular overall. Places with nothing are left out.
    """
    place_ids = list(dict.fromkeys(place_ids))[:MAX_PLACES_PER_COUNT_REQUEST]
    if not place_ids:
        return []

    fresh = and_(SharedPreview.place_id.in_(place_ids), SharedPreview.created_at >= _cutoff(now))
    totals = dict(
        db.query(SharedPreview.place_id, func.count())
        .filter(fresh)
        .group_by(SharedPreview.place_id)
        .all()
    )
    others = dict(
        db.query(SharedPreview.place_id, func.count())
        .filter(fresh, _others_only(user_id))
        .group_by(SharedPreview.place_id)
        .all()
    )
    return [
        PlacePreviewCount(
            place_id=place_id,
            count=min(others.get(place_id, 0), MAX_PER_PLACE),
            popular=totals.get(place_id, 0) >= POPULAR_AT,
        )
        for place_id in place_ids
        if totals.get(place_id)
    ]
