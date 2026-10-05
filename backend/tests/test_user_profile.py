from fastapi.testclient import TestClient

from app.core.auth import get_current_user_id
from app.main import app
from app.models.user_profile import UserProfile

TEST_USER_ID = "test-user"


def _body(**overrides):
    body = {"display_name": "Shivani", "phone": "+1 (555) 010-2030", "avatar_id": "sun"}
    body.update(overrides)
    return body


def test_no_profile_yet_is_404(client):
    assert client.get("/me/profile").status_code == 404


def test_save_then_read(client):
    saved = client.put("/me/profile", json=_body())

    assert saved.status_code == 200
    body = client.get("/me/profile").json()
    assert body["display_name"] == "Shivani"
    assert body["phone"] == "+1 (555) 010-2030"
    assert body["avatar_id"] == "sun"
    assert body["photo_storage_path"] is None
    assert body["updated_at"]


def test_saving_again_updates_the_same_row(client, db_session):
    client.put("/me/profile", json=_body())
    client.put("/me/profile", json=_body(display_name="Shivani B", avatar_id="moon"))

    rows = db_session.query(UserProfile).filter_by(user_id=TEST_USER_ID).all()
    assert len(rows) == 1
    assert rows[0].display_name == "Shivani B"
    assert rows[0].avatar_id == "moon"


def test_name_is_required_and_trimmed(client):
    assert client.put("/me/profile", json=_body(display_name="   ")).status_code == 422
    assert client.put("/me/profile", json={"phone": None}).status_code == 422
    assert client.put("/me/profile", json=_body(display_name="x" * 81)).status_code == 422

    client.put("/me/profile", json=_body(display_name="  Shivani  "))
    assert client.get("/me/profile").json()["display_name"] == "Shivani"


def test_phone_is_optional_and_blank_means_none(client):
    client.put("/me/profile", json=_body(phone=""))
    assert client.get("/me/profile").json()["phone"] is None

    client.put("/me/profile", json=_body(phone=None))
    assert client.get("/me/profile").json()["phone"] is None


def test_rejects_junk_phone_numbers(client):
    assert client.put("/me/profile", json=_body(phone="call me maybe")).status_code == 422
    assert client.put("/me/profile", json=_body(phone="123")).status_code == 422


def test_photo_must_be_in_the_callers_own_folder(client):
    own = client.put(
        "/me/profile",
        json=_body(avatar_id=None, photo_storage_path=f"profiles/{TEST_USER_ID}/1.jpg"),
    )
    assert own.status_code == 200

    other = client.put(
        "/me/profile",
        json=_body(avatar_id=None, photo_storage_path="profiles/someone-else/1.jpg"),
    )
    assert other.status_code == 400

    feedback = client.put(
        "/me/profile",
        json=_body(avatar_id=None, photo_storage_path=f"feedback/{TEST_USER_ID}/1.jpg"),
    )
    assert feedback.status_code == 400


def test_photo_and_avatar_are_mutually_exclusive(client):
    response = client.put(
        "/me/profile",
        json=_body(photo_storage_path=f"profiles/{TEST_USER_ID}/1.jpg", avatar_id="sun"),
    )

    assert response.status_code == 422


def test_avatar_ids_must_look_like_ids(client):
    assert client.put("/me/profile", json=_body(avatar_id="../etc")).status_code == 422
    assert client.put("/me/profile", json=_body(avatar_id="Sun!")).status_code == 422


def test_profiles_are_per_user(client):
    client.put("/me/profile", json=_body())

    app.dependency_overrides[get_current_user_id] = lambda: "someone-else"
    assert client.get("/me/profile").status_code == 404


def test_requires_authentication():
    anonymous = TestClient(app)

    assert anonymous.get("/me/profile").status_code == 401
    assert anonymous.put("/me/profile", json=_body()).status_code == 401
