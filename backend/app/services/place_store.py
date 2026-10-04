import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.place_cache import PlaceSearchCache

logger = logging.getLogger(__name__)


@dataclass
class StoredPlaces:
    payload: list[dict]
    fetched_at: datetime


class PlaceStore(Protocol):
    def get(self, key: str) -> StoredPlaces | None: ...
    def set(self, key: str, payload: list[dict]) -> None: ...


class PostgresPlaceStore:
    """Durable second-level cache for place searches. Database trouble is
    logged and treated as a miss/no-op — the store is an optimisation, so it
    must never be the reason a search fails.
    """

    def __init__(self, session_factory: Callable[[], Session] = SessionLocal):
        self._session_factory = session_factory

    def get(self, key: str) -> StoredPlaces | None:
        session = self._session_factory()
        try:
            row = session.get(PlaceSearchCache, key)
            if row is None:
                return None
            return StoredPlaces(payload=row.payload, fetched_at=row.fetched_at)
        except SQLAlchemyError:
            logger.warning("Place store read failed for %s", key, exc_info=True)
            return None
        finally:
            session.close()

    def set(self, key: str, payload: list[dict]) -> None:
        session = self._session_factory()
        try:
            session.merge(
                PlaceSearchCache(
                    cache_key=key,
                    payload=payload,
                    fetched_at=datetime.now(timezone.utc).replace(tzinfo=None),
                )
            )
            session.commit()
        except SQLAlchemyError:
            session.rollback()
            logger.warning("Place store write failed for %s", key, exc_info=True)
        finally:
            session.close()
