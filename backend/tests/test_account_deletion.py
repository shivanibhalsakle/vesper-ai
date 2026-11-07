from datetime import date

import pytest

import app.api.me as me_api
from app.core.auth import get_current_user_id
from app.main import app
from app.models.feedback import FeedbackEntry
from app.models.generated_preview import GeneratedPreview
from app.models.image_usage import ImageGenerationUsage
from app.models.saved_date import SavedDate
from app.models.saved_profile import SavedProfile
from app.models.user_preferences import UserPreferences
from app.models.user_profile import UserProfile
from app.services.account_deletion import (
    OWNED_MODELS,
    AccountDeletionFailed,
    delete_account,
)
from app.services.preview_storage import get_default_storage
from tests.conftest import TEST_USER_ID

LEAVING = "leaving-user"
STAYING = "staying-user"


class FakeStorage:
    def __init__(self, events=None, fail=False):
        self.events = events if events is not None else []
        self.fail = fail

    def delete_prefix(self, prefix):
        if self.fail:
            raise ConnectionError("storage down")
        self.events.append(("files", prefix))


def _add_everything(db, user_id):
    db.add_all(
        [
            FeedbackEntry(
                location_id="osm:node/1",
                location_name="Park",
                location_type="park",
                event="sunset",
                event_date=date(2026, 11, 1),
                photo_storage_path=f"feedback/{user_id}/a.jpg",
                user_id=user_id,
                preference_profile={},
                forecast_snapshot={},
            ),
            GeneratedPreview(
                user_id=user_id,
                prompt_hash="hash",
                prompt="prompt",
                location_name="Park",
                location_type="park",
                event="sunset",
                storage_path=f"previews/{user_id}/a.webp",
            ),
            ImageGenerationUsage(user_id=user_id, usage_date=date(2026, 11, 1), count=2),
            SavedDate(
                user_id=user_id,
                event_date=date(2026, 12, 1),
                event="sunset",
                lat=40.7,
                lon=-74.0,
                label="Park",
                fcm_token="token",
            ),
            SavedProfile(
                user_id=user_id,
                home_lat=40.7,
                home_lon=-74.0,
                radius_km=10,
                place_types=["park"],
                event="sunset",
                preference_profile={},
                fcm_token="token",
            ),
            UserPreferences(user_id=user_id, preference_profile={}),
            UserProfile(user_id=user_id, display_name="Someone"),
        ]
    )
    db.commit()


def _rows_for(db, user_id) -> int:
    return sum(db.query(model).filter(model.user_id == user_id).count() for model in OWNED_MODELS)


def test_every_table_with_a_user_is_covered():
    assert len(OWNED_MODELS) == 7  # update OWNED_MODELS when a table gains a user_id


def test_everything_belonging_to_the_user_is_deleted_and_nothing_else(db_session):
    _add_everything(db_session, LEAVING)
    _add_everything(db_session, STAYING)

    delete_account(db_session, LEAVING, FakeStorage(), delete_sign_in=lambda uid: None)

    assert _rows_for(db_session, LEAVING) == 0
    assert _rows_for(db_session, STAYING) == len(OWNED_MODELS)


def test_the_users_three_storage_folders_are_emptied(db_session):
    storage = FakeStorage()

    delete_account(db_session, LEAVING, storage, delete_sign_in=lambda uid: None)

    assert storage.events == [
        ("files", f"feedback/{LEAVING}/"),
        ("files", f"profiles/{LEAVING}/"),
        ("files", f"previews/{LEAVING}/"),
    ]


def test_the_sign_in_is_removed_last(db_session):
    _add_everything(db_session, LEAVING)
    events = []
    storage = FakeStorage(events)

    def remove_sign_in(user_id):
        events.append(("sign-in", user_id, _rows_for(db_session, user_id)))

    delete_account(db_session, LEAVING, storage, delete_sign_in=remove_sign_in)

    assert events[-1] == ("sign-in", LEAVING, 0)  # the data was already gone
    assert [event[0] for event in events] == ["files", "files", "files", "sign-in"]


def test_a_storage_failure_changes_nothing_so_it_can_be_retried(db_session):
    _add_everything(db_session, LEAVING)
    removed = []

    with pytest.raises(AccountDeletionFailed) as failure:
        delete_account(
            db_session, LEAVING, FakeStorage(fail=True), delete_sign_in=removed.append
        )

    assert failure.value.step == "files"
    assert _rows_for(db_session, LEAVING) == len(OWNED_MODELS)
    assert removed == []


def test_a_sign_in_failure_can_be_retried_to_completion(db_session):
    _add_everything(db_session, LEAVING)

    def broken(user_id):
        raise ConnectionError("firebase down")

    with pytest.raises(AccountDeletionFailed) as failure:
        delete_account(db_session, LEAVING, FakeStorage(), delete_sign_in=broken)
    assert failure.value.step == "sign-in"
    assert _rows_for(db_session, LEAVING) == 0

    removed = []
    delete_account(db_session, LEAVING, FakeStorage(), delete_sign_in=removed.append)  # retry
    assert removed == [LEAVING]


def test_it_works_when_no_storage_is_configured(db_session):
    _add_everything(db_session, LEAVING)

    delete_account(db_session, LEAVING, None, delete_sign_in=lambda uid: None)

    assert _rows_for(db_session, LEAVING) == 0


@pytest.mark.parametrize("user_id", ["", "../other", "a/b"])
def test_an_unsafe_user_id_is_refused_before_anything_is_deleted(db_session, user_id):
    storage = FakeStorage()

    with pytest.raises(ValueError):
        delete_account(db_session, user_id, storage, delete_sign_in=lambda uid: None)

    assert storage.events == []


def test_the_endpoint_deletes_the_signed_in_users_account(client, monkeypatch):
    calls = []
    storage = FakeStorage()
    monkeypatch.setattr(
        me_api, "delete_account", lambda db, user_id, store: calls.append((user_id, store))
    )
    app.dependency_overrides[get_default_storage] = lambda: storage

    response = client.delete("/me")

    assert response.status_code == 204
    assert response.content == b""
    assert calls == [(TEST_USER_ID, storage)]


def test_the_endpoint_reports_a_failed_deletion_as_retryable(client, monkeypatch):
    def fail(db, user_id, store):
        raise AccountDeletionFailed("data")

    monkeypatch.setattr(me_api, "delete_account", fail)
    app.dependency_overrides[get_default_storage] = lambda: None

    response = client.delete("/me")

    assert response.status_code == 503
    assert "try again" in response.json()["detail"]


def test_the_endpoint_needs_a_sign_in(client):
    app.dependency_overrides.pop(get_current_user_id, None)

    assert client.delete("/me").status_code == 401
