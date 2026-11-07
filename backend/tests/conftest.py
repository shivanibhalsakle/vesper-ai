import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.core.auth import get_current_user_id
from app.db.session import engine, get_db
from app.main import app

TEST_USER_ID = "test-user"


class UnknownCoverage:
    def covers(self, lat, lon):
        return None


class InMemoryCache:
    def __init__(self):
        self.counts: dict[str, int] = {}

    def get(self, key):
        return None

    def set(self, key, value, ttl_seconds):
        pass

    def incr(self, key, ttl_seconds):
        self.counts[key] = self.counts.get(key, 0) + 1
        return self.counts[key]


@pytest.fixture(autouse=True)
def fresh_search_budget(monkeypatch):
    """Search budgets are counted in Redis, which outlives a test run; each
    test gets empty in-memory counters instead, so none depends on another.
    """
    counters = InMemoryCache()
    monkeypatch.setattr("app.services.request_limits.RedisCache", lambda: counters)


@pytest.fixture()
def signed_in():
    """For test files that make their own TestClient: stand in for sign-in."""
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def unknown_coverage(monkeypatch):
    """Place lookups don't depend on which regions the dev database has loaded;
    tests that care pass their own coverage (see test_coverage.py).
    """
    monkeypatch.setattr("app.services.places.PostgresCoverage", UnknownCoverage)


@pytest.fixture()
def db_session():
    """A DB session bound to a transaction that's rolled back after the test,
    so feedback tests don't leave rows behind in the shared dev database.
    """
    connection = engine.connect()
    transaction = connection.begin()
    # create_saved_profile/create_feedback/etc. call session.commit() as part
    # of normal application code. Without join_transaction_mode, that commit
    # ends the outer transaction too, so the later transaction.rollback()
    # becomes a no-op and rows leak into the real dev database. Binding to a
    # savepoint means an app-level commit only releases the savepoint (a new
    # one reopens automatically); the outer transaction — and everything in
    # it — is still rolled back below.
    testing_session_local = sessionmaker(bind=connection, join_transaction_mode="create_savepoint")
    session = testing_session_local()

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture()
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
