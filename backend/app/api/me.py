from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.user_preferences import UserPreferencesRecord, UserPreferencesUpdate
from app.schemas.user_profile import UserProfileRecord, UserProfileUpdate
from app.services.account_deletion import AccountDeletionFailed, delete_account
from app.services.preview_storage import PreviewStorage, get_default_storage
from app.services.user_preferences import get_preferences, upsert_preferences
from app.services.user_profile import get_profile, photo_folder, upsert_profile

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/profile", response_model=UserProfileRecord)
def read_profile(
    user_id: str = Depends(get_current_user_id), db: Session = Depends(get_db)
) -> UserProfileRecord:
    row = get_profile(db, user_id)
    if row is None:
        raise HTTPException(status_code=404, detail="No profile yet.")
    return UserProfileRecord.model_validate(row)


@router.put("/profile", response_model=UserProfileRecord)
def save_profile(
    payload: UserProfileUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> UserProfileRecord:
    # A photo path must be inside the caller's own folder, so nobody can point
    # their profile at someone else's stored file.
    if payload.photo_storage_path and not payload.photo_storage_path.startswith(
        photo_folder(user_id)
    ):
        raise HTTPException(
            status_code=400,
            detail="photo_storage_path must be inside your own profile folder.",
        )
    row = upsert_profile(db, user_id, payload)
    return UserProfileRecord.model_validate(row)


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


@router.delete("", status_code=204)
def delete_my_account(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    storage: PreviewStorage | None = Depends(get_default_storage),
) -> Response:
    """Permanently deletes the signed-in user's account: their photos and sky
    previews, saved dates and searches, preferences, profile and feedback, and
    finally the sign-in itself. Safe to call again if it fails part-way.
    """
    try:
        delete_account(db, user_id, storage)
    except AccountDeletionFailed:
        raise HTTPException(
            status_code=503,
            detail="We couldn't finish deleting your account. Please try again in a moment.",
        )
    return Response(status_code=204)
