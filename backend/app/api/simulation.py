from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.simulation import (
    PreviewRecord,
    RemainingPreviews,
    SimulationRequest,
    SimulationResponse,
)
from app.services.image_limits import DAILY_LIMIT_PER_USER, ImageLimitExceeded, remaining_today
from app.services.preview_storage import PreviewStorage, get_default_storage
from app.services.previews import delete_preview, list_previews
from app.services.simulation import generate_simulation

router = APIRouter(tags=["simulation"])


@router.post("/simulate", response_model=SimulationResponse)
def create_simulation(
    request: SimulationRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SimulationResponse:
    try:
        return generate_simulation(request, user_id=user_id, db=db)
    except ImageLimitExceeded as exc:
        raise HTTPException(status_code=429, detail=str(exc))


@router.get("/simulate/remaining", response_model=RemainingPreviews)
def get_remaining_previews(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
) -> RemainingPreviews:
    """How many previews the user can still generate today. The app shows this
    in its "generate?" confirmation, before anything is spent."""
    return RemainingPreviews(
        remaining_today=remaining_today(db, user_id), daily_limit=DAILY_LIMIT_PER_USER
    )


@router.get("/me/previews", response_model=list[PreviewRecord])
def get_previews(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    storage: PreviewStorage | None = Depends(get_default_storage),
) -> list[PreviewRecord]:
    """The user's generated sky previews, newest first."""
    if storage is None:
        return []
    records = []
    for row in list_previews(db, user_id):
        try:
            url = storage.signed_url(row.storage_path)
        except Exception:
            continue  # one unreadable file shouldn't hide the rest
        records.append(
            PreviewRecord(
                id=row.id,
                image_url=url,
                location_name=row.location_name,
                location_type=row.location_type,
                event=row.event,
                prompt=row.prompt,
                created_at=row.created_at,
            )
        )
    return records


@router.delete("/me/previews/{preview_id}", status_code=204)
def remove_preview(
    preview_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    storage: PreviewStorage | None = Depends(get_default_storage),
) -> Response:
    if not delete_preview(db, storage, user_id, preview_id):
        raise HTTPException(status_code=404, detail="Preview not found.")
    return Response(status_code=204)
