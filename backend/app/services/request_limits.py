"""Daily budgets for the endpoints that spend money (weather lookups, Claude).

Sign-in alone doesn't bound cost, since anyone can make an account. Each
search is counted against the user and against the whole app, so one user (or
one bug) can't run up the bill, and a kill switch can pause everything.
"""

import logging
from datetime import date

from app.core.config import get_settings
from app.services.cache import Cache, RedisCache

logger = logging.getLogger(__name__)

# A little over a day, so a counter keyed to today's date always outlives it.
WINDOW_SECONDS = 60 * 60 * 26

# scope -> (per user per day, whole app per day). One search scores up to 15
# places (a weather lookup each) and writes up to 5 Claude explanations; the
# app-wide numbers also keep us inside Open-Meteo's free daily quota.
LIMITS: dict[str, tuple[int, int]] = {
    "session": (40, 500),
    "trip-window": (20, 300),
    "best-date": (40, 500),
}


class SearchesPaused(Exception):
    """The searches kill switch is on."""


class SearchLimitExceeded(Exception):
    """A per-user or app-wide daily budget is used up; the message is user-facing."""


def ensure_within_budget(scope: str, user_id: str, cache: Cache | None = None) -> None:
    """Counts one search against today's budgets, raising if either is spent.
    Fails open if Redis is down: losing the limiter briefly beats blocking
    every search (the kill switch doesn't depend on Redis).
    """
    if not get_settings().searches_enabled:
        raise SearchesPaused("Searches are paused")

    per_user, per_app = LIMITS[scope]
    today = date.today().isoformat()
    cache = cache if cache is not None else RedisCache()
    try:
        # The user's own count goes first, so a user who is already over their
        # limit doesn't also eat into everyone else's shared budget.
        user_count = cache.incr(f"limit:{scope}:{today}:user:{user_id}", WINDOW_SECONDS)
        if user_count > per_user:
            raise SearchLimitExceeded(
                f"You've reached today's limit of {per_user} searches. Try again tomorrow."
            )
        app_count = cache.incr(f"limit:{scope}:{today}:all", WINDOW_SECONDS)
    except SearchLimitExceeded:
        raise
    except Exception:
        logger.warning("Search limiter unavailable; allowing request", exc_info=True)
        return
    if app_count > per_app:
        raise SearchLimitExceeded(
            "Vesper has hit its daily search limit across all users. Please try again tomorrow."
        )
