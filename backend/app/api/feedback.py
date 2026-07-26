from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.feedback import FeedbackCreate, FeedbackRecord
from app.services.feedback import create_feedback, list_feedback_for_location

router = APIRouter(tags=["feedback"])


@router.post("/feedback", response_model=FeedbackRecord, status_code=201)
def submit_feedback(payload: FeedbackCreate, db: Session = Depends(get_db)) -> FeedbackRecord:
    entry = create_feedback(db, payload)
    return FeedbackRecord.model_validate(entry)


@router.get("/feedback", response_model=list[FeedbackRecord])
def get_feedback(location_id: str, db: Session = Depends(get_db)) -> list[FeedbackRecord]:
    entries = list_feedback_for_location(db, location_id)
    return [FeedbackRecord.model_validate(entry) for entry in entries]
