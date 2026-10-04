from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.feedback import FeedbackCreate, FeedbackRecord
from app.services.feedback import create_feedback, list_feedback_for_location

router = APIRouter(tags=["feedback"])


@router.post("/feedback", response_model=FeedbackRecord, status_code=201)
def submit_feedback(
    payload: FeedbackCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> FeedbackRecord:
    # The client uploads photos straight to Firebase Storage and reports the
    # path; without this check it could point its feedback at someone else's photo.
    if not payload.photo_storage_path.startswith(f"feedback/{user_id}/"):
        raise HTTPException(
            status_code=400,
            detail="photo_storage_path must be inside your own feedback folder.",
        )
    entry = create_feedback(db, payload, user_id)
    return FeedbackRecord.model_validate(entry)


@router.get("/feedback", response_model=list[FeedbackRecord])
def get_feedback(
    location_id: str,
    _user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> list[FeedbackRecord]:
    entries = list_feedback_for_location(db, location_id)
    return [FeedbackRecord.model_validate(entry) for entry in entries]
