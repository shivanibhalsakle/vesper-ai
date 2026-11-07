from fastapi import HTTPException

from app.services.request_limits import SearchesPaused, SearchLimitExceeded, ensure_within_budget


def check_search_budget(scope: str, user_id: str) -> None:
    """Call first in an endpoint that spends money; turns a spent budget into
    the HTTP errors the app already shows (the message is the detail).
    """
    try:
        ensure_within_budget(scope, user_id)
    except SearchesPaused:
        raise HTTPException(
            status_code=503,
            detail="Vesper is taking a short break. Please try again a little later.",
        )
    except SearchLimitExceeded as exc:
        raise HTTPException(status_code=429, detail=str(exc))
