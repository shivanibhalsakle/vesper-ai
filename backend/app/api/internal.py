import secrets

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.services.notification_scheduler import rescore_saved_profiles

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
    """Re-scores every saved profile's area and sends push notifications for
    strong matches. Replaces the old Celery-beat daily job — Render's free
    tier doesn't support background workers, so this is triggered instead by
    a scheduled GitHub Actions workflow hitting this endpoint once a day.
    """
    return rescore_saved_profiles(db)
