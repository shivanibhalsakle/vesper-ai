from sqlalchemy.orm import Session

from app.models.saved_profile import SavedProfile
from app.schemas.saved_profile import SavedProfileCreate


def create_saved_profile(db: Session, data: SavedProfileCreate) -> SavedProfile:
    profile = SavedProfile(
        user_id=data.user_id,
        home_lat=data.home_lat,
        home_lon=data.home_lon,
        radius_km=data.radius_km,
        place_types=[t.value for t in data.place_types],
        event=data.event.value,
        tz_name=data.tz_name,
        preference_profile=data.preference_profile.model_dump(),
        fcm_token=data.fcm_token,
        notification_enabled=data.notification_enabled,
        match_threshold=data.match_threshold,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


def list_saved_profiles_for_user(db: Session, user_id: str) -> list[SavedProfile]:
    return db.query(SavedProfile).filter(SavedProfile.user_id == user_id).all()


def list_enabled_saved_profiles(db: Session) -> list[SavedProfile]:
    return db.query(SavedProfile).filter(SavedProfile.notification_enabled.is_(True)).all()
