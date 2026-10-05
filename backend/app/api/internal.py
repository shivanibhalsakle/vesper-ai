import secrets

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.services.notification_scheduler import rescore_saved_profiles
from app.services.saved_date_reminders import send_saved_date_reminders

router = APIRouter(tags=["internal"])


def verify_internal_secret(x_internal_secret: str | None = Header(default=None)) -> None:
    expected = get_settings().internal_api_secret
    if not expected or not x_internal_secret or not secrets.compare_digest(
        x_internal_secret, expected
    ):
        raise HTTPException(status_code=401, detail="Invalid or missing internal secret.")


@router.post(
    "/internal/rescore-notifications",
    dependencies=[Depends(verify_internal_secret)],
)
def trigger_rescore(db: Session = Depends(get_db)) -> list[dict]:
    """Sends the day-before reminders for dates users saved, then re-scores
    every saved profile's area and notifies for strong matches. Saved dates
    go first and take priority: a user reminded about their own date gets no
    automatic saved-search alert the same day. Replaces the old Celery-beat
    daily job — Render's free tier doesn't support background workers, so
    this is triggered instead by a scheduled GitHub Actions workflow hitting
    this endpoint once a day.
    """
    date_results, notified_users = send_saved_date_reminders(db)
    return date_results + rescore_saved_profiles(db, skip_user_ids=notified_users)
