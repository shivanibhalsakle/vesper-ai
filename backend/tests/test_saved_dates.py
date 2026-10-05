from datetime import date

from fastapi.testclient import TestClient

from app.core.auth import get_current_user_id
from app.main import app
from app.models.saved_date import SavedDate
from app.services import saved_dates as saved_dates_service

TEST_USER_ID = "test-user"


def _body(**overrides):
    body = {
        "event_date": "2026-10-07",
        "event": "sunset",
        "lat": 40.7003,
        "lon": -73.9967,
        "label": "Brooklyn Bridge Park",
        "saved_score": 0.84,
        "fcm_token": "device-token",
    }
    body.update(overrides)
    return body


def test_save_then_list(client):
    created = client.post("/me/saved-dates", json=_body())

    assert created.status_code == 201
    body = created.json()
    assert body["id"]
    assert body["label"] == "Brooklyn Bridge Park"
    assert body["saved_score"] == 0.84
    assert body["notification_enabled"] is True
    assert "fcm_token" not in body  # device tokens never leave the server

    listed = client.get("/me/saved-dates").json()
    assert [d["id"] for d in listed] == [body["id"]]


def test_list_is_sorted_by_date(client):
    client.post("/me/saved-dates", json=_body(event_date="2026-10-09", lat=1.0))
    client.post("/me/saved-dates", json=_body(event_date="2026-10-06", lat=2.0))

    dates = [d["event_date"] for d in client.get("/me/saved-dates").json()]

    assert dates == ["2026-10-06", "2026-10-09"]


def test_saving_the_same_place_and_day_twice_is_idempotent(client, db_session):
    first = client.post("/me/saved-dates", json=_body(fcm_token="old-token")).json()
    # A few metres away, same day and event: still the same spot.
    second = client.post(
        "/me/saved-dates", json=_body(lat=40.70035, fcm_token="new-token")
    ).json()

    assert second["id"] == first["id"]
    rows = db_session.query(SavedDate).filter_by(user_id=TEST_USER_ID).all()
    assert len(rows) == 1
    assert rows[0].fcm_token == "new-token"  # the reminder goes to the latest device


def test_different_event_or_day_is_a_separate_save(client):
    client.post("/me/saved-dates", json=_body())
    client.post("/me/saved-dates", json=_body(event="sunrise"))
    client.post("/me/saved-dates", json=_body(event_date="2026-10-08"))

    assert len(client.get("/me/saved-dates").json()) == 3


def test_owner_comes_from_the_token_not_the_body(client, db_session):
    client.post("/me/saved-dates", json=_body(user_id="attacker"))

    row = db_session.query(SavedDate).one()
    assert row.user_id == TEST_USER_ID


def test_users_only_see_their_own_saved_dates(client):
    client.post("/me/saved-dates", json=_body())

    app.dependency_overrides[get_current_user_id] = lambda: "someone-else"
    assert client.get("/me/saved-dates").json() == []


def test_toggle_notifications(client):
    saved = client.post("/me/saved-dates", json=_body()).json()

    off = client.patch(f"/me/saved-dates/{saved['id']}", json={"notification_enabled": False})

    assert off.status_code == 200
    assert off.json()["notification_enabled"] is False


def test_delete(client):
    saved = client.post("/me/saved-dates", json=_body()).json()

    assert client.delete(f"/me/saved-dates/{saved['id']}").status_code == 204
    assert client.get("/me/saved-dates").json() == []
    assert client.delete(f"/me/saved-dates/{saved['id']}").status_code == 404


def test_cannot_touch_another_users_saved_date(client):
    saved = client.post("/me/saved-dates", json=_body()).json()

    app.dependency_overrides[get_current_user_id] = lambda: "someone-else"
    assert client.delete(f"/me/saved-dates/{saved['id']}").status_code == 404
    assert (
        client.patch(
            f"/me/saved-dates/{saved['id']}", json={"notification_enabled": False}
        ).status_code
        == 404
    )

    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    assert len(client.get("/me/saved-dates").json()) == 1


def test_per_user_limit(client, monkeypatch):
    monkeypatch.setattr(saved_dates_service, "MAX_SAVED_DATES_PER_USER", 2)
    client.post("/me/saved-dates", json=_body(lat=1.0))
    client.post("/me/saved-dates", json=_body(lat=2.0))

    response = client.post("/me/saved-dates", json=_body(lat=3.0))

    assert response.status_code == 409
    assert "up to 2" in response.json()["detail"]


def test_validation(client):
    assert client.post("/me/saved-dates", json=_body(lat=123)).status_code == 422
    assert client.post("/me/saved-dates", json=_body(label="")).status_code == 422
    assert client.post("/me/saved-dates", json=_body(saved_score=2)).status_code == 422
    assert client.post("/me/saved-dates", json=_body(event="noon")).status_code == 422


def test_requires_authentication():
    anonymous = TestClient(app)

    assert anonymous.get("/me/saved-dates").status_code == 401
    assert anonymous.post("/me/saved-dates", json=_body()).status_code == 401
    assert anonymous.delete("/me/saved-dates/x").status_code == 401


def test_saved_date_model_defaults(db_session):
    row = SavedDate(
        user_id="u", event_date=date(2026, 10, 7), event="sunset", lat=1.0, lon=2.0, label="x"
    )
    db_session.add(row)
    db_session.commit()

    assert row.id
    assert row.notified_at is None
