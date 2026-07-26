from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.saved_profile import SavedProfileCreate, SavedProfileRecord
from app.services.saved_profiles import create_saved_profile, list_saved_profiles_for_user

router = APIRouter(tags=["profiles"])


@router.post("/profiles", response_model=SavedProfileRecord, status_code=201)
def submit_profile(
    payload: SavedProfileCreate, db: Session = Depends(get_db)
) -> SavedProfileRecord:
    profile = create_saved_profile(db, payload)
    return SavedProfileRecord.model_validate(profile)


@router.get("/profiles", response_model=list[SavedProfileRecord])
def get_profiles(user_id: str, db: Session = Depends(get_db)) -> list[SavedProfileRecord]:
    profiles = list_saved_profiles_for_user(db, user_id)
    return [SavedProfileRecord.model_validate(profile) for profile in profiles]
