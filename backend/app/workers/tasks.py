import logging

from app.db.session import SessionLocal
from app.services.notification_scheduler import rescore_saved_profiles
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="app.workers.tasks.rescore_saved_profiles_task")
def rescore_saved_profiles_task() -> list[dict]:
    db = SessionLocal()
    try:
        results = rescore_saved_profiles(db)
        logger.info("Rescored %d saved profiles: %s", len(results), results)
        return results
    finally:
        db.close()
