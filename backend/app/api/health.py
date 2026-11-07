from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.session import get_db

router = APIRouter(tags=["health"])


@router.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready")
def readiness_check(db: Session = Depends(get_db)) -> dict[str, str]:
    """Like /health, but also proves the database answers. Kept separate on
    purpose: a monitor pinging this every few minutes would keep Neon awake
    around the clock and burn its free compute hours, so point the platform's
    health check at /health and use this one by hand or for rare alerts.
    """
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="Database unavailable")
    return {"status": "ok"}
