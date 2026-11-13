from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.simulation import PlacePreviewCount, SharedPreviewRecord
from app.services.preview_storage import PreviewStorage, get_default_storage
from app.services.shared_previews import counts_for, list_shared

router = APIRouter(prefix="/shared-previews", tags=["shared-previews"])

MAX_PLACE_ID_LENGTH = 200


@router.get("", response_model=list[SharedPreviewRecord])
def previews_for_place(
    place_id: str = Query(..., min_length=1, max_length=MAX_PLACE_ID_LENGTH),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    storage: PreviewStorage | None = Depends(get_default_storage),
) -> list[SharedPreviewRecord]:
    """Previews other people generated for this place, newest first. They are
    anonymous: nothing in the answer says who made them.
    """
    if storage is None:
        return []
    return list_shared(db, storage, user_id, place_id)


@router.get("/counts", response_model=list[PlacePreviewCount])
def preview_counts(
    place_ids: list[str] = Query(default=[]),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> list[PlacePreviewCount]:
    """For a screenful of places at once: how many previews by others each has
    (so the app can show a link) and whether it is popular. Places without any
    are left out of the answer.
    """
    valid = [place_id for place_id in place_ids if 0 < len(place_id) <= MAX_PLACE_ID_LENGTH]
    return counts_for(db, user_id, valid)
