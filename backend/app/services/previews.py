import logging
import uuid

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.generated_preview import GeneratedPreview
from app.schemas.simulation import SimulationRequest
from app.services.preview_storage import PreviewStorage, to_webp

logger = logging.getLogger(__name__)

# Only the latest previews are kept per user; older ones are deleted as new
# ones arrive. Together with the daily generation caps this bounds storage.
MAX_PREVIEWS_PER_USER = 30


def find_by_prompt(db: Session, user_id: str, prompt_hash: str) -> GeneratedPreview | None:
    return (
        db.query(GeneratedPreview)
        .filter(GeneratedPreview.user_id == user_id, GeneratedPreview.prompt_hash == prompt_hash)
        .first()
    )


def list_previews(db: Session, user_id: str) -> list[GeneratedPreview]:
    """The user's previews, newest first."""
    return (
        db.query(GeneratedPreview)
        .filter(GeneratedPreview.user_id == user_id)
        .order_by(GeneratedPreview.created_at.desc(), GeneratedPreview.id)
        .all()
    )


def save_preview(
    db: Session,
    storage: PreviewStorage,
    user_id: str,
    prompt_hash: str,
    prompt: str,
    request: SimulationRequest,
    image_bytes: bytes,
) -> GeneratedPreview:
    """Stores the image (as WebP) and records it. If the user already has
    this exact sky (a double tap, two devices), that preview is returned and
    nothing new is kept."""
    path = f"previews/{user_id}/{uuid.uuid4()}.webp"
    storage.upload(path, to_webp(image_bytes), "image/webp")

    row = GeneratedPreview(
        user_id=user_id,
        prompt_hash=prompt_hash,
        prompt=prompt,
        location_name=request.location_name,
        location_type=request.location_type.value,
        event=request.event.value,
        storage_path=path,
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        _delete_blob(storage, path)
        existing = find_by_prompt(db, user_id, prompt_hash)
        if existing is None:
            raise
        return existing

    _trim(db, storage, user_id)
    return row


def delete_preview(db: Session, storage: PreviewStorage | None, user_id: str, preview_id: str) -> bool:
    row = (
        db.query(GeneratedPreview)
        .filter(GeneratedPreview.id == preview_id, GeneratedPreview.user_id == user_id)
        .first()
    )
    if row is None:
        return False
    path = row.storage_path
    db.delete(row)
    db.commit()
    if storage is not None:
        _delete_blob(storage, path)
    return True


def _trim(db: Session, storage: PreviewStorage, user_id: str) -> None:
    rows = list_previews(db, user_id)
    for old in rows[MAX_PREVIEWS_PER_USER:]:
        path = old.storage_path
        db.delete(old)
        db.commit()
        _delete_blob(storage, path)


def _delete_blob(storage: PreviewStorage, path: str) -> None:
    try:
        storage.delete(path)
    except Exception:
        # A leftover file costs almost nothing; never fail a request over it.
        logger.warning("Could not delete preview file %s", path, exc_info=True)
