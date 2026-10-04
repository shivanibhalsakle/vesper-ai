from fastapi.testclient import TestClient

from app.main import app
from app.schemas.saved_profile import SavedProfileCreate
from app.services.saved_profiles import create_saved_profile

# The `client` fixture (conftest.py) is signed in as this user.
TEST_USER_ID = "test-user"


def _payload(**overrides):
    body = {
        "home_lat": 40.7003,
        "home_lon": -73.9967,
        "radius_km": 10.0,
        "place_types": ["park", "waterfront"],
        "event": "sunset",
        "tz_name": "America/New_York",
        "preference_profile": {"golden_orange": 1.0, "dramatic_clouds": 0.5},
        "fcm_token": "fake-device-token",
        "notification_enabled": True,
        "match_threshold": 0.7,
    }
    body.update(overrides)
    return body


def test_submit_profile_returns_persisted_record(client):
    response = client.post("/profiles", json=_payload())
    body = response.json()

    assert response.status_code == 201
    assert body["id"]
    assert body["user_id"] == TEST_USER_ID
    assert body["place_types"] == ["park", "waterfront"]
    assert body["preference_profile"]["golden_orange"] == 1.0
    assert body["notification_enabled"] is True
    assert body["match_threshold"] == 0.7


def test_owner_comes_from_the_token_not_the_request_body(client):
    response = client.post("/profiles", json=_payload(user_id="attacker"))

    assert response.status_code == 201
    assert response.json()["user_id"] == TEST_USER_ID


def test_list_profiles_returns_only_the_callers_profiles(client, db_session):
    client.post("/profiles", json=_payload())
    client.post("/profiles", json=_payload(event="sunrise"))
    create_saved_profile(db_session, SavedProfileCreate(**_payload()), "someone-else")

    response = client.get("/profiles")
    body = response.json()

    assert response.status_code == 200
    assert len(body) == 2
    assert all(p["user_id"] == TEST_USER_ID for p in body)


def test_list_profiles_ignores_a_user_id_query_param(client, db_session):
    create_saved_profile(db_session, SavedProfileCreate(**_payload()), "someone-else")

    response = client.get("/profiles", params={"user_id": "someone-else"})

    assert response.status_code == 200
    assert response.json() == []


def test_list_profiles_returns_empty_when_caller_has_none(client):
    response = client.get("/profiles")

    assert response.status_code == 200
    assert response.json() == []


def test_profile_without_fcm_token_is_allowed(client):
    payload = _payload()
    del payload["fcm_token"]

    response = client.post("/profiles", json=payload)
    body = response.json()

    assert response.status_code == 201
    assert body["fcm_token"] is None


def test_profiles_require_authentication():
    unauthenticated = TestClient(app)

    assert unauthenticated.post("/profiles", json=_payload()).status_code == 401
    assert unauthenticated.get("/profiles").status_code == 401
