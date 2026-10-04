from fastapi.testclient import TestClient

from app.main import app
from app.models.feedback import FeedbackEntry

# The `client` fixture (conftest.py) is signed in as this user.
TEST_USER_ID = "test-user"


def _payload(**overrides):
    body = {
        "location_id": "osm:node/123",
        "location_name": "Brooklyn Bridge Park",
        "location_type": "waterfront",
        "event": "sunset",
        "event_date": "2026-07-20",
        "photo_storage_path": f"feedback/{TEST_USER_ID}/photo1.jpg",
        "preference_profile": {"golden_orange": 1.0, "dramatic_clouds": 0.5},
        "forecast_snapshot": {
            "cloud_cover_summary": "partly cloudy (high clouds)",
            "visibility_likelihood": 0.85,
            "color_probabilities": {
                "pink": 0.3,
                "purple": 0.2,
                "orange": 0.8,
                "red": 0.1,
                "golden": 0.9,
            },
            "preference_match_score": 0.78,
        },
    }
    body.update(overrides)
    return body


def test_submit_feedback_returns_persisted_record(client):
    response = client.post("/feedback", json=_payload())
    body = response.json()

    assert response.status_code == 201
    assert body["id"]
    assert body["location_id"] == "osm:node/123"
    assert body["photo_storage_path"] == f"feedback/{TEST_USER_ID}/photo1.jpg"
    assert body["preference_profile"]["golden_orange"] == 1.0
    assert body["forecast_snapshot"]["preference_match_score"] == 0.78
    assert body["created_at"]


def test_author_comes_from_the_token_not_the_request_body(client, db_session):
    response = client.post("/feedback", json=_payload(user_id="attacker"))

    assert response.status_code == 201
    stored = db_session.get(FeedbackEntry, response.json()["id"])
    assert stored.user_id == TEST_USER_ID


def test_responses_do_not_expose_user_ids(client):
    client.post("/feedback", json=_payload())

    listed = client.get("/feedback", params={"location_id": "osm:node/123"}).json()

    assert len(listed) == 1
    assert "user_id" not in listed[0]


def test_photo_path_outside_the_callers_folder_is_rejected(client):
    response = client.post(
        "/feedback", json=_payload(photo_storage_path="feedback/someone-else/photo1.jpg")
    )

    assert response.status_code == 400


def test_list_feedback_filters_by_location_id(client):
    client.post("/feedback", json=_payload(location_id="loc-a"))
    client.post("/feedback", json=_payload(location_id="loc-a"))
    client.post("/feedback", json=_payload(location_id="loc-b"))

    response = client.get("/feedback", params={"location_id": "loc-a"})
    body = response.json()

    assert response.status_code == 200
    assert len(body) == 2
    assert all(entry["location_id"] == "loc-a" for entry in body)


def test_list_feedback_returns_empty_for_unknown_location(client):
    response = client.get("/feedback", params={"location_id": "no-such-location"})

    assert response.status_code == 200
    assert response.json() == []


def test_feedback_requires_authentication():
    unauthenticated = TestClient(app)

    assert unauthenticated.post("/feedback", json=_payload()).status_code == 401
    assert unauthenticated.get("/feedback", params={"location_id": "x"}).status_code == 401
