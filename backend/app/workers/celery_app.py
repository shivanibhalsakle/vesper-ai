from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery("vesper", broker=settings.redis_url, backend=settings.redis_url)
celery_app.conf.timezone = "UTC"
celery_app.conf.broker_connection_retry_on_startup = True

celery_app.conf.beat_schedule = {
    "rescore-saved-profiles-daily": {
        "task": "app.workers.tasks.rescore_saved_profiles_task",
        # Once a day is a reasonable MVP cadence; tune once real usage data exists.
        "schedule": crontab(hour=12, minute=0),
    },
}

celery_app.autodiscover_tasks(["app.workers"])
