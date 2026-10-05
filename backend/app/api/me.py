from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.user_preferences import UserPreferencesRecord, UserPreferencesUpdate
from app.services.user_preferences import get_preferences, upsert_preferences

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/preferences", response_model=UserPreferencesRecord)
def read_preferences(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
) -> UserPreferencesRecord:
    row = get_preferences(db, user_id)
    if row is None:
        raise HTTPException(status_code=404, detail="No saved preferences yet.")
    return UserPreferencesRecord.model_validate(row)


@router.put("/preferences", response_model=UserPreferencesRecord)
def save_preferences(
    payload: UserPreferencesUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> UserPreferencesRecord:
    row = upsert_preferences(db, user_id, payload)
    return UserPreferencesRecord.model_validate(row)
