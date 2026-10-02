import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.core.auth import get_current_user_id
from app.db.session import engine, get_db
from app.main import app

TEST_USER_ID = "test-user"


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
