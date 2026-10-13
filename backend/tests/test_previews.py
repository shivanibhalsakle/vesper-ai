import base64
import io
import random

import pytest
from fastapi.testclient import TestClient
from PIL import Image

import app.services.previews as previews_module
from app.core.auth import get_current_user_id
from app.main import app
from app.models.generated_preview import GeneratedPreview
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import SimulationRequest
from app.services.image_limits import DAILY_LIMIT_PER_USER, ImageLimitExceeded
from app.services.preview_storage import (
    decode_data_uri,
    get_default_storage,
    shrink_data_uri,
    to_webp,
)
from app.services.simulation import ImageGenProvider, generate_simulation
from tests.conftest import TEST_USER_ID

USER = "user-1"


class FakeStorage:
    def __init__(self):
        self.files: dict[str, tuple[bytes, str]] = {}
        self.deleted: list[str] = []
        self.fail_upload = False

    def upload(self, path, data, content_type):
        if self.fail_upload:
            raise ConnectionError("storage down")
        self.files[path] = (data, content_type)

    def signed_url(self, path):
        return f"https://signed.example/{path}"

    def delete(self, path):
        self.deleted.append(path)
        self.files.pop(path, None)


class InMemoryCache:
    def __init__(self):
        self.store: dict[str, str] = {}

    def get(self, key):
        return self.store.get(key)

    def set(self, key, value, ttl_seconds):
        self.store[key] = value


def _png_data_uri(size: int = 64) -> str:
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for x in range(size):
        for y in range(size):
            pixels[x, y] = (x * 4 % 256, y * 4 % 256, (x + y) * 2 % 256)
    out = io.BytesIO()
    image.save(out, format="PNG")
    return "data:image/png;base64," + base64.b64encode(out.getvalue()).decode()


class PngProvider(ImageGenProvider):
    def __init__(self):
        self.calls = 0

    def generate_image(self, prompt: str) -> str:
        self.calls += 1
        return _png_data_uri()


def _request(name: str = "Brooklyn Bridge Park") -> SimulationRequest:
    return SimulationRequest(
        location_name=name,
        location_type=LocationType.WATERFRONT,
        event=SunEvent.SUNSET,
        cloud_cover_summary="partly cloudy",
        visibility_likelihood=0.9,
        color_probabilities=ColorProbabilities(pink=0.6, purple=0.2, orange=0.8, red=0.1, golden=0.85),
    )


def _generate(db, storage, provider=None, cache=None, name="Brooklyn Bridge Park", user=USER):
    return generate_simulation(
        _request(name),
        user,
        db,
        provider=provider or PngProvider(),
        cache=cache if cache is not None else InMemoryCache(),
        storage=storage,
    )


# --- image handling ---


def test_to_webp_shrinks_a_png_and_never_recompresses_webp():
    # Photo-like noise (a repeating pattern would make the PNG tiny); real
    # generated skies are large, detailed PNGs.
    noise = random.Random(7).randbytes(256 * 256 * 3)
    out = io.BytesIO()
    Image.frombytes("RGB", (256, 256), noise).save(out, format="PNG")
    png = out.getvalue()
    webp = to_webp(png)

    assert webp[:4] == b"RIFF" and webp[8:12] == b"WEBP"
    assert len(webp) < len(png)
    assert to_webp(webp) == webp


def test_shrink_data_uri_leaves_hosted_urls_and_junk_alone():
    assert shrink_data_uri("https://example.com/x.png") == "https://example.com/x.png"
    junk = "data:image/png;base64,bm90IGFuIGltYWdl"  # "not an image"
    assert shrink_data_uri(junk) == junk
    assert shrink_data_uri(_png_data_uri()).startswith("data:image/webp;base64,")


# --- saving ---


def test_generated_image_is_saved_as_webp_and_shown_from_storage(db_session):
    storage = FakeStorage()

    result = _generate(db_session, storage)

    assert result.saved is True
    assert result.preview_id is not None
    assert result.image_url.startswith(f"https://signed.example/previews/{USER}/")
    assert result.remaining_today == DAILY_LIMIT_PER_USER - 1

    (path,) = storage.files
    data, content_type = storage.files[path]
    assert content_type == "image/webp"
    assert data[8:12] == b"WEBP"

    row = db_session.query(GeneratedPreview).one()
    assert row.user_id == USER
    assert row.location_name == "Brooklyn Bridge Park"
    assert row.location_type == "waterfront"
    assert row.event == "sunset"
    assert row.storage_path == path


def test_without_storage_the_image_still_comes_back_but_is_not_saved(db_session):
    result = _generate(db_session, None)

    assert result.saved is False
    assert result.preview_id is None
    assert result.image_url.startswith("data:image/webp;base64,")  # shrunk, not the raw PNG
    assert db_session.query(GeneratedPreview).count() == 0


def test_a_storage_failure_does_not_lose_the_image(db_session):
    storage = FakeStorage()
    storage.fail_upload = True

    result = _generate(db_session, storage)

    assert result.provider_status == "generated"
    assert result.saved is False
    assert result.image_url.startswith("data:image/webp;base64,")
    assert db_session.query(GeneratedPreview).count() == 0


def test_a_hosted_url_from_the_provider_is_not_saved(db_session):
    class UrlProvider(ImageGenProvider):
        def generate_image(self, prompt):
            return "https://example.com/generated.png"

    result = _generate(db_session, FakeStorage(), provider=UrlProvider())

    assert result.image_url == "https://example.com/generated.png"
    assert result.saved is False


def test_repeating_a_saved_sky_shows_it_again_without_generating_or_charging(db_session):
    storage = FakeStorage()
    provider = PngProvider()
    first = _generate(db_session, storage, provider=provider)

    second = _generate(db_session, storage, provider=provider, cache=InMemoryCache())

    assert provider.calls == 1
    assert second.preview_id == first.preview_id
    assert second.image_url == first.image_url
    assert second.remaining_today == DAILY_LIMIT_PER_USER - 1
    assert db_session.query(GeneratedPreview).count() == 1


def test_a_saved_sky_can_be_reopened_even_with_no_allowance_left(db_session):
    storage = FakeStorage()
    provider = PngProvider()
    saved = _generate(db_session, storage, provider=provider, name="Saved one")
    for i in range(DAILY_LIMIT_PER_USER - 1):
        _generate(db_session, storage, provider=provider, name=f"Other {i}")

    with pytest.raises(ImageLimitExceeded):
        _generate(db_session, storage, provider=provider, name="Brand new")

    again = _generate(db_session, storage, provider=provider, name="Saved one")
    assert again.preview_id == saved.preview_id


def test_a_sky_cached_for_someone_else_is_free_but_lands_in_this_users_gallery(db_session):
    storage = FakeStorage()
    provider = PngProvider()
    cache = InMemoryCache()
    _generate(db_session, storage, provider=provider, cache=cache, user="someone-else")

    mine = _generate(db_session, storage, provider=provider, cache=cache, user=USER)

    assert provider.calls == 1
    assert mine.saved is True
    assert mine.remaining_today == DAILY_LIMIT_PER_USER  # nothing charged to me
    assert db_session.query(GeneratedPreview).filter_by(user_id=USER).count() == 1


def test_only_the_latest_previews_are_kept(db_session, monkeypatch):
    monkeypatch.setattr(previews_module, "MAX_PREVIEWS_PER_USER", 3)
    storage = FakeStorage()
    provider = PngProvider()
    results = [
        _generate(db_session, storage, provider=provider, name=f"Spot {i}")
        for i in range(DAILY_LIMIT_PER_USER)
    ]

    rows = (
        db_session.query(GeneratedPreview)
        .filter_by(user_id=USER)
        .order_by(GeneratedPreview.created_at.desc())
        .all()
    )
    assert [row.location_name for row in rows] == ["Spot 4", "Spot 3", "Spot 2"]
    assert len(storage.files) == 3
    assert len(storage.deleted) == 2
    assert results[-1].saved is True


# --- endpoints ---


@pytest.fixture()
def api(client, db_session):
    storage = FakeStorage()
    app.dependency_overrides[get_default_storage] = lambda: storage
    yield client, storage


def test_remaining_endpoint_reports_the_allowance(api):
    client, _ = api

    body = client.get("/simulate/remaining").json()

    assert body == {"remaining_today": DAILY_LIMIT_PER_USER, "daily_limit": DAILY_LIMIT_PER_USER}


def test_previews_are_listed_newest_first_with_links(api, db_session):
    client, storage = api
    provider = PngProvider()
    _generate(db_session, storage, provider=provider, name="First", user=TEST_USER_ID)
    _generate(db_session, storage, provider=provider, name="Second", user=TEST_USER_ID)
    _generate(db_session, storage, provider=provider, name="Not mine", user="someone-else")

    response = client.get("/me/previews")

    assert response.status_code == 200
    body = response.json()
    assert [p["location_name"] for p in body] == ["Second", "First"]
    assert body[0]["image_url"].startswith("https://signed.example/previews/test-user/")
    assert body[0]["event"] == "sunset"
    assert body[0]["location_type"] == "waterfront"
    assert "AI-generated" in body[0]["disclaimer"]


def test_deleting_a_preview_removes_the_row_and_the_file(api, db_session):
    client, storage = api
    result = _generate(db_session, storage, name="Gone", user=TEST_USER_ID)

    response = client.delete(f"/me/previews/{result.preview_id}")

    assert response.status_code == 204
    assert client.get("/me/previews").json() == []
    assert storage.files == {}
    assert client.delete(f"/me/previews/{result.preview_id}").status_code == 404


def test_cannot_delete_someone_elses_preview(api, db_session):
    client, storage = api
    theirs = _generate(db_session, storage, name="Theirs", user="someone-else")

    response = client.delete(f"/me/previews/{theirs.preview_id}")

    assert response.status_code == 404
    assert len(storage.files) == 1


def test_gallery_and_remaining_require_sign_in():
    anonymous = TestClient(app)
    app.dependency_overrides.pop(get_current_user_id, None)

    assert anonymous.get("/me/previews").status_code == 401
    assert anonymous.get("/simulate/remaining").status_code == 401
    assert anonymous.delete("/me/previews/abc").status_code == 401


def test_gallery_is_empty_when_storage_is_not_configured(client):
    app.dependency_overrides[get_default_storage] = lambda: None

    assert client.get("/me/previews").json() == []
