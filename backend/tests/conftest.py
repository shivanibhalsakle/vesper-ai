import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.db.session import engine, get_db
from app.main import app


@pytest.fixture()
def db_session():
    """A DB session bound to a transaction that's rolled back after the test,
    so feedback tests don't leave rows behind in the shared dev database.
    """
    connection = engine.connect()
    transaction = connection.begin()
    testing_session_local = sessionmaker(bind=connection)
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
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
