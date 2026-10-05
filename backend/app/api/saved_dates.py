from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.saved_date import SavedDateCreate, SavedDateRecord, SavedDateUpdate
from app.services.saved_dates import (
    SavedDateLimitReached,
    create_saved_date,
    delete_saved_date,
    list_saved_dates,
    set_notification_enabled,
)

router = APIRouter(prefix="/me/saved-dates", tags=["saved-dates"])


@router.post("", response_model=SavedDateRecord, status_code=201)
def save_date(
    payload: SavedDateCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SavedDateRecord:
    try:
        row = create_saved_date(db, user_id, payload)
    except SavedDateLimitReached as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return SavedDateRecord.model_validate(row)


@router.get("", response_model=list[SavedDateRecord])
def get_saved_dates(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
) -> list[SavedDateRecord]:
    return [SavedDateRecord.model_validate(row) for row in list_saved_dates(db, user_id)]


@router.patch("/{saved_date_id}", response_model=SavedDateRecord)
def update_saved_date(
    saved_date_id: str,
    payload: SavedDateUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SavedDateRecord:
    row = set_notification_enabled(db, user_id, saved_date_id, payload.notification_enabled)
    if row is None:
        raise HTTPException(status_code=404, detail="Saved date not found.")
    return SavedDateRecord.model_validate(row)


@router.delete("/{saved_date_id}", status_code=204)
def remove_saved_date(
    saved_date_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> Response:
    if not delete_saved_date(db, user_id, saved_date_id):
        raise HTTPException(status_code=404, detail="Saved date not found.")
    return Response(status_code=204)
