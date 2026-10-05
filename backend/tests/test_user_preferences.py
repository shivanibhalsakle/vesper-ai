from app.core.auth import get_current_user_id
from app.main import app
from app.models.user_preferences import UserPreferences

TEST_USER_ID = "test-user"


def _payload(**overrides):
    body = {
        "home_lat": 40.7003,
        "home_lon": -73.9967,
        "home_label": "Brooklyn Bridge Park",
        "radius_km": 15.0,
        "place_types": ["park", "waterfront"],
        "event": "sunrise",
        "preference_profile": {"golden_orange": 0.8, "clear_sky": 0.3},
    }
    body.update(overrides)
    return body


def test_get_before_any_save_is_404(client):
    response = client.get("/me/preferences")

    assert response.status_code == 404


def test_put_then_get_round_trips(client):
    saved = client.put("/me/preferences", json=_payload())
    assert saved.status_code == 200

    body = client.get("/me/preferences").json()
    assert body["home_label"] == "Brooklyn Bridge Park"
    assert body["radius_km"] == 15.0
    assert body["place_types"] == ["park", "waterfront"]
    assert body["event"] == "sunrise"
    assert body["preference_profile"]["golden_orange"] == 0.8
    assert body["updated_at"]


def test_put_twice_updates_the_same_row(client, db_session):
    client.put("/me/preferences", json=_payload())
    client.put("/me/preferences", json=_payload(radius_km=40.0, place_types=[]))

    rows = db_session.query(UserPreferences).filter_by(user_id=TEST_USER_ID).all()
    assert len(rows) == 1
    assert rows[0].radius_km == 40.0
    assert rows[0].place_types == []


def test_location_is_optional(client):
    response = client.put(
        "/me/preferences", json={"preference_profile": {"red_sky": 1.0}}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["home_lat"] is None
    assert body["event"] == "sunset"


def test_rejects_out_of_range_values(client):
    assert client.put("/me/preferences", json=_payload(home_lat=123)).status_code == 422
    assert client.put("/me/preferences", json=_payload(radius_km=0)).status_code == 422
    assert (
        client.put(
            "/me/preferences", json=_payload(preference_profile={"clear_sky": 2.0})
        ).status_code
        == 422
    )


def test_preferences_are_per_user(client, db_session):
    client.put("/me/preferences", json=_payload())

    app.dependency_overrides[get_current_user_id] = lambda: "someone-else"
    assert client.get("/me/preferences").status_code == 404


def test_requires_authentication():
    from fastapi.testclient import TestClient

    # No dependency override: the real Firebase check rejects a missing token.
    assert TestClient(app).get("/me/preferences").status_code == 401
