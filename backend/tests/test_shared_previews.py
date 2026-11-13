import io
import random
from datetime import date, datetime, timedelta, timezone

import pytest
from PIL import Image

from app.core.auth import get_current_user_id
from app.main import app
from app.models.generated_preview import GeneratedPreview
from app.models.osm_place import OsmPlace
from app.models.shared_preview import SharedPreview
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import SimulationRequest
from app.services.account_deletion import delete_account
from app.services.place_index import types_to_mask
from app.services.preview_storage import get_default_storage, make_thumbnail, to_webp
from app.services.shared_previews import (
    MAX_PER_PERSON_PER_PLACE,
    MAX_PER_PLACE,
    POPULAR_AT,
    counts_for,
    list_shared,
    resolve_place,
)
from app.services.simulation import generate_simulation
from tests.test_previews import FakeStorage, InMemoryCache, PngProvider

PLACE = "curated:top-of-the-rock"  # a place in our curated list
SENT_NAME = "Whatever the app sent"


class Storage(FakeStorage):
    """The preview fake plus what shared previews and account deletion use."""

    def __init__(self, fail_on: str | None = None):
        super().__init__()
        self.fail_on = fail_on
        self.prefixes: list[str] = []

    def upload(self, path, data, content_type):
        if self.fail_on and self.fail_on in path:
            raise ConnectionError("storage down")
        super().upload(path, data, content_type)

    def delete_prefix(self, prefix):
        self.prefixes.append(prefix)
        for path in [p for p in self.files if p.startswith(prefix)]:
            del self.files[path]


def _make(db, storage, user, sky="partly cloudy", place_id=PLACE, name=SENT_NAME):
    request = SimulationRequest(
        location_name=name,
        event=SunEvent.SUNSET,
        place_id=place_id,
        event_date=date(2026, 12, 1),
        cloud_cover_summary=sky,
        visibility_likelihood=0.9,
        color_probabilities=ColorProbabilities(
            pink=0.6, purple=0.2, orange=0.8, red=0.1, golden=0.85
        ),
    )
    return generate_simulation(
        request, user, db, provider=PngProvider(), cache=InMemoryCache(), storage=storage
    )


def _shared(db, place_id=PLACE):
    return db.query(SharedPreview).filter(SharedPreview.place_id == place_id).all()


def _old_row(db, hash_, age_days, place_id=PLACE):
    row = SharedPreview(
        place_id=place_id,
        place_name="Top of the Rock",
        event="sunset",
        prompt_hash=hash_,
        storage_path=f"shared-previews/{hash_}.webp",
        thumb_path=f"shared-previews/{hash_}-thumb.webp",
        created_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=age_days),
    )
    db.add(row)
    db.commit()
    return row


# --- which places can be shared --------------------------------------------------


def test_curated_and_loaded_places_are_known_but_a_made_up_id_is_not(db_session):
    db_session.add(
        OsmPlace(
            id="osm:node/test-shared-1",
            name="Test Park",
            type_mask=types_to_mask([LocationType.PARK]),
            lat=1.0,
            lon=1.0,
        )
    )
    db_session.commit()

    assert resolve_place(db_session, PLACE).name == "Top of the Rock"
    loaded = resolve_place(db_session, "osm:node/test-shared-1")
    assert (loaded.name, loaded.type) == ("Test Park", "park")
    assert resolve_place(db_session, "123 Some Street, Springfield") is None
    assert resolve_place(db_session, None) is None


# --- adding to the collection ----------------------------------------------------


def test_a_preview_of_a_known_place_joins_the_places_collection_with_our_own_details(db_session):
    storage = Storage()

    result = _make(db_session, storage, "user-a")

    assert result.saved is True
    [shared] = _shared(db_session)
    assert shared.place_name == "Top of the Rock"  # our name, not what the app sent
    assert shared.place_type == "elevated_viewpoint"
    assert shared.event == "sunset"
    assert shared.event_date == date(2026, 12, 1)
    assert shared.storage_path.startswith("shared-previews/")
    assert shared.thumb_path.startswith("shared-previews/")
    for path in (shared.storage_path, shared.thumb_path):
        data, content_type = storage.files[path]
        assert content_type == "image/webp"
        assert data[8:12] == b"WEBP"
    assert SENT_NAME not in result.prompt
    assert "Top of the Rock" in result.prompt


def test_the_shared_collection_has_no_trace_of_who_made_a_preview(db_session):
    columns = SharedPreview.__table__.columns.keys()

    assert not [name for name in columns if "user" in name or "owner" in name]


def test_the_persons_own_copy_is_separate_and_keeps_the_place(db_session):
    storage = Storage()

    _make(db_session, storage, "user-a")

    [own] = db_session.query(GeneratedPreview).filter_by(user_id="user-a").all()
    [shared] = _shared(db_session)
    assert own.place_id == PLACE
    assert own.location_name == "Top of the Rock"
    assert own.storage_path != shared.storage_path  # two files, so either can go alone


def test_a_place_we_dont_know_or_none_at_all_is_never_shared(db_session):
    storage = Storage()

    typed_address = _make(db_session, storage, "user-a", place_id="12 Main St, Anytown")
    current_location = _make(db_session, storage, "user-a", sky="overcast", place_id=None)

    assert typed_address.saved and current_location.saved  # still in their own gallery
    assert db_session.query(SharedPreview).count() == 0
    own = db_session.query(GeneratedPreview).filter_by(user_id="user-a").all()
    assert [row.place_id for row in own] == [None, None]
    assert [p for p in storage.files if p.startswith("shared-previews/")] == []


def test_the_same_sky_at_the_same_place_is_added_once(db_session):
    storage = Storage()

    _make(db_session, storage, "user-a")
    second = _make(db_session, storage, "user-b")

    assert len(_shared(db_session)) == 1
    assert second.saved is True  # still in the second person's gallery
    assert db_session.query(GeneratedPreview).filter_by(user_id="user-b").count() == 1


def test_one_person_adds_only_a_few_previews_of_a_place(db_session):
    storage = Storage()
    skies = ["partly cloudy", "overcast", "mostly clear", "hazy"]

    for sky in skies:
        _make(db_session, storage, "user-a", sky=sky)

    assert len(_shared(db_session)) == MAX_PER_PERSON_PER_PLACE
    assert db_session.query(GeneratedPreview).filter_by(user_id="user-a").count() == len(skies)


def test_only_the_newest_few_are_kept_per_place_and_old_files_are_removed(db_session):
    storage = Storage()
    for number in range(MAX_PER_PLACE + 2):
        _make(db_session, storage, f"user-{number}", sky=f"sky number {number}")

    kept = _shared(db_session)

    assert len(kept) == MAX_PER_PLACE
    on_disk = {p for p in storage.files if p.startswith("shared-previews/")}
    assert on_disk == {row.storage_path for row in kept} | {row.thumb_path for row in kept}
    assert len([p for p in storage.deleted if p.startswith("shared-previews/")]) == 4


def test_previews_older_than_the_limit_are_hidden_and_cleared_on_the_next_addition(db_session):
    storage = Storage()
    stale = _old_row(db_session, "stale", age_days=100)
    fresh = _old_row(db_session, "fresh", age_days=5)
    stale_id, stale_path, fresh_id = stale.id, stale.storage_path, fresh.id
    storage.files[stale_path] = (b"x", "image/webp")

    assert [r.id for r in list_shared(db_session, storage, "viewer", PLACE)] == [fresh_id]
    assert [c.count for c in counts_for(db_session, "viewer", [PLACE])] == [1]

    _make(db_session, storage, "user-a")

    assert stale_id not in {row.id for row in _shared(db_session)}
    assert stale_path in storage.deleted


def test_a_failure_while_sharing_never_loses_the_persons_own_preview(db_session):
    storage = Storage(fail_on="-thumb")

    result = _make(db_session, storage, "user-a")

    assert result.saved is True and result.image_url
    assert _shared(db_session) == []
    assert [p for p in storage.files if p.startswith("shared-previews/")] == []  # no orphan


def test_thumbnails_are_small_versions_of_the_picture():
    noise = random.Random(3).randbytes(1024 * 1024 * 3)
    out = io.BytesIO()
    Image.frombytes("RGB", (1024, 1024), noise).save(out, format="PNG")
    full = to_webp(out.getvalue())

    thumb = make_thumbnail(full)

    with Image.open(io.BytesIO(thumb)) as image:
        assert image.format == "WEBP"
        assert max(image.size) <= 384
    assert len(thumb) < len(full) / 4


# --- looking at a place's collection ------------------------------------------------


def test_a_places_collection_is_newest_first_and_leaves_out_the_viewers_own_skies(db_session):
    storage = Storage()
    _make(db_session, storage, "user-a", sky="sky a")
    _make(db_session, storage, "user-b", sky="sky b")
    _make(db_session, storage, "user-c", sky="sky c")

    for_a = list_shared(db_session, storage, "user-a", PLACE)
    for_stranger = list_shared(db_session, storage, "stranger", PLACE)

    assert len(for_stranger) == 3
    assert [r.created_at for r in for_stranger] == sorted(
        (r.created_at for r in for_stranger), reverse=True
    )
    assert len(for_a) == 2  # user-a already has their own in their gallery
    record = for_stranger[0]
    assert record.place_name == "Top of the Rock"
    assert record.image_url.startswith("https://signed.example/shared-previews/")
    assert record.thumb_url.endswith("-thumb.webp")


def test_counts_show_how_many_by_others_and_whether_the_place_is_popular(db_session):
    for number in range(POPULAR_AT):
        _old_row(db_session, f"h{number}", age_days=1)
    # One person's gallery already holds three of those skies.
    for number in range(3):
        db_session.add(
            GeneratedPreview(
                user_id="user-a",
                prompt_hash=f"h{number}",
                prompt="p",
                location_name="Top of the Rock",
                location_type="",
                event="sunset",
                storage_path=f"previews/user-a/{number}.webp",
            )
        )
    db_session.commit()

    [as_a] = counts_for(db_session, "user-a", [PLACE, "curated:coney-island-beach"])
    [as_stranger] = counts_for(db_session, "stranger", [PLACE])

    assert (as_a.place_id, as_a.count, as_a.popular) == (PLACE, POPULAR_AT - 3, True)
    assert (as_stranger.count, as_stranger.popular) == (POPULAR_AT, True)  # others omitted


def test_a_place_below_the_popular_mark_is_not_labelled(db_session):
    for number in range(POPULAR_AT - 1):
        _old_row(db_session, f"h{number}", age_days=1)

    [only] = counts_for(db_session, "stranger", [PLACE])

    assert only.popular is False and only.count == POPULAR_AT - 1


def test_counts_only_look_at_a_screenful_of_places(db_session):
    _old_row(db_session, "h1", age_days=1, place_id="curated:late-in-the-list")
    ids = [f"curated:place-{n}" for n in range(30)] + ["curated:late-in-the-list"]

    assert counts_for(db_session, "stranger", ids) == []


# --- the endpoints ------------------------------------------------------------------


def test_the_collection_endpoint_returns_previews_without_anything_about_their_makers(
    client, db_session
):
    storage = Storage()
    _make(db_session, storage, "user-a")
    app.dependency_overrides[get_default_storage] = lambda: storage

    response = client.get("/shared-previews", params={"place_id": PLACE})

    assert response.status_code == 200
    [record] = response.json()
    assert set(record) == {
        "id",
        "image_url",
        "thumb_url",
        "place_name",
        "event",
        "event_date",
        "disclaimer",
        "created_at",
    }
    assert record["place_name"] == "Top of the Rock"
    assert record["event_date"] == "2026-12-01"


def test_the_counts_endpoint_lists_places_with_previews_and_ignores_junk_ids(client, db_session):
    _old_row(db_session, "h1", age_days=1)

    response = client.get(
        "/shared-previews/counts",
        params=[("place_ids", PLACE), ("place_ids", "x" * 500), ("place_ids", "curated:none")],
    )

    assert response.status_code == 200
    assert response.json() == [{"place_id": PLACE, "count": 1, "popular": False}]


def test_the_collection_endpoint_is_empty_when_no_storage_is_set_up(client):
    app.dependency_overrides[get_default_storage] = lambda: None

    assert client.get("/shared-previews", params={"place_id": PLACE}).json() == []


@pytest.mark.parametrize("path", ["/shared-previews?place_id=x", "/shared-previews/counts"])
def test_the_collection_endpoints_need_a_sign_in(client, path):
    app.dependency_overrides.pop(get_current_user_id, None)

    assert client.get(path).status_code == 401


# --- leaving ----------------------------------------------------------------------------


def test_deleting_an_account_removes_their_own_previews_but_the_shared_copy_stays(db_session):
    storage = Storage()
    _make(db_session, storage, "leaving-user")
    [shared] = _shared(db_session)

    delete_account(db_session, "leaving-user", storage, delete_sign_in=lambda user: None)

    assert db_session.query(GeneratedPreview).filter_by(user_id="leaving-user").count() == 0
    assert [row.id for row in _shared(db_session)] == [shared.id]
    assert shared.storage_path in storage.files and shared.thumb_path in storage.files
    assert all("shared-previews" not in prefix for prefix in storage.prefixes)
