from sqlalchemy.orm import Session

from app.models.user_preferences import UserPreferences
from app.schemas.user_preferences import UserPreferencesUpdate


def get_preferences(db: Session, user_id: str) -> UserPreferences | None:
    return db.get(UserPreferences, user_id)


def upsert_preferences(db: Session, user_id: str, data: UserPreferencesUpdate) -> UserPreferences:
    row = db.get(UserPreferences, user_id)
    if row is None:
        row = UserPreferences(user_id=user_id)
        db.add(row)

    row.home_lat = data.home_lat
    row.home_lon = data.home_lon
    row.home_label = data.home_label
    row.radius_km = data.radius_km
    row.place_types = [t.value for t in data.place_types]
    row.event = data.event.value
    row.preference_profile = data.preference_profile.model_dump()
    db.commit()
    db.refresh(row)
    return row
