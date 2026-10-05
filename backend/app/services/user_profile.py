from sqlalchemy.orm import Session

from app.models.user_profile import UserProfile
from app.schemas.user_profile import UserProfileUpdate


def photo_folder(user_id: str) -> str:
    return f"profiles/{user_id}/"


def get_profile(db: Session, user_id: str) -> UserProfile | None:
    return db.get(UserProfile, user_id)


def upsert_profile(db: Session, user_id: str, data: UserProfileUpdate) -> UserProfile:
    row = db.get(UserProfile, user_id)
    if row is None:
        row = UserProfile(user_id=user_id)
        db.add(row)

    row.display_name = data.display_name
    row.phone = data.phone
    row.photo_storage_path = data.photo_storage_path
    row.avatar_id = data.avatar_id
    db.commit()
    db.refresh(row)
    return row
