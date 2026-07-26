from sqlalchemy.orm import Session

from app.models.feedback import FeedbackEntry
from app.schemas.feedback import FeedbackCreate


def create_feedback(db: Session, data: FeedbackCreate) -> FeedbackEntry:
    entry = FeedbackEntry(
        location_id=data.location_id,
        location_name=data.location_name,
        location_type=data.location_type.value,
        event=data.event.value,
        event_date=data.event_date,
        photo_storage_path=data.photo_storage_path,
        user_id=data.user_id,
        preference_profile=data.preference_profile.model_dump(),
        forecast_snapshot=data.forecast_snapshot.model_dump(),
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


def list_feedback_for_location(db: Session, location_id: str) -> list[FeedbackEntry]:
    return (
        db.query(FeedbackEntry)
        .filter(FeedbackEntry.location_id == location_id)
        .order_by(FeedbackEntry.created_at.desc())
        .all()
    )
