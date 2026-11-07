import httpx
import pytest
from sqlalchemy.exc import OperationalError

import app.api.places as places_api
import app.api.session as session_api
import app.services.coverage as coverage_module
from app.core.auth import get_current_user_id
from app.core.config import get_settings
from app.main import app
from app.schemas.location import LocationType
from app.services.coverage import (
    PostgresCoverage,
    outside_coverage_message,
    region_containing,
)
from app.services.places import OutsideCoverage, find_candidate_locations

MANHATTAN = (40.7590, -73.9787)  # also the spot of a curated entry
COLUMBUS_OHIO = (39.96, -83.0)
RURAL_NEW_YORK = (41.5, -75.5)  # far from every curated entry

ALL_TYPES = list(LocationType)


@pytest.fixture(autouse=True)
def fresh_cache():
    coverage_module.reset_cache()
    yield
    coverage_module.reset_cache()


class FakeCoverage:
    def __init__(self, answer):
        self.answer = answer

    def covers(self, lat, lon):
        return self.answer


class EmptyIndex:
    def search(self, lat, lon, radius_km, place_types):
        return []


class FakeCache:
    def get(self, key):
        return None

    def set(self, key, value, ttl_seconds):
        pass


class FakeStore:
    def get(self, key):
        return None

    def set(self, key, payload):
        pass


def _find(lat, lon, coverage, client=None, radius_km=10):
    return find_candidate_locations(
        lat,
        lon,
        radius_km=radius_km,
        place_types=ALL_TYPES,
        client=client,
        cache=FakeCache(),
        store=FakeStore(),
        index=EmptyIndex(),
        coverage=coverage,
    )


def _overpass_client(calls: list[int], elements: list[dict] | None = None) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(1)
        return httpx.Response(200, json={"elements": elements or []})

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_region_containing_matches_loaded_regions_only():
    assert region_containing(["new-york"], *MANHATTAN) == "new-york"
    assert region_containing(["new-york"], *COLUMBUS_OHIO) is None
    assert region_containing(["new-york", "ohio"], *COLUMBUS_OHIO) == "ohio"
    assert region_containing(["somewhere-unknown"], *MANHATTAN) is None


def test_coverage_is_true_false_or_unknown():
    assert PostgresCoverage(lambda: ["new-york"]).covers(*MANHATTAN) is True
    assert PostgresCoverage(lambda: ["new-york"]).covers(*COLUMBUS_OHIO) is False
    # Nothing loaded (or the lookup failed): never claim a place is uncovered.
    assert PostgresCoverage(lambda: []).covers(*MANHATTAN) is None


def test_loaded_regions_are_cached_and_a_failed_lookup_is_not(monkeypatch):
    answers = iter([None, ["texas"], ["texas", "ohio"]])
    calls = []

    def load():
        calls.append(1)
        return next(answers)

    monkeypatch.setattr(coverage_module, "_load_from_db", load)

    assert coverage_module.loaded_regions() == []  # lookup failed
    assert coverage_module.loaded_regions() == ["texas"]  # failure wasn't remembered
    assert coverage_module.loaded_regions() == ["texas"]  # now served from the cache
    assert len(calls) == 2


def test_database_failure_loading_regions_is_not_fatal():
    class BrokenSession:
        def scalars(self, statement):
            raise OperationalError("SELECT", {}, Exception("db down"))

        def close(self):
            pass

    assert coverage_module._load_from_db(session_factory=BrokenSession) is None


def test_covered_area_with_no_places_answers_empty_without_calling_overpass():
    calls = []

    spots = _find(*RURAL_NEW_YORK, FakeCoverage(True), client=_overpass_client(calls))

    assert spots == []
    assert calls == []


def test_outside_coverage_is_refused_without_calling_overpass():
    calls = []

    with pytest.raises(OutsideCoverage):
        _find(*COLUMBUS_OHIO, FakeCoverage(False), client=_overpass_client(calls))

    assert calls == []


def test_outside_coverage_still_serves_curated_spots_nearby():
    spots = _find(*MANHATTAN, FakeCoverage(False))

    assert spots
    assert all(spot.source.value == "curated" for spot in spots)


def test_outside_coverage_can_be_allowed_to_try_overpass(monkeypatch):
    settings = get_settings().model_copy(update={"overpass_outside_coverage": True})
    monkeypatch.setattr("app.services.places.get_settings", lambda: settings)
    calls = []
    park = {
        "type": "node",
        "id": 7,
        "lat": COLUMBUS_OHIO[0],
        "lon": COLUMBUS_OHIO[1],
        "tags": {"name": "Goodale Park", "leisure": "park"},
    }

    spots = _find(*COLUMBUS_OHIO, FakeCoverage(False), client=_overpass_client(calls, [park]))

    assert [spot.name for spot in spots] == ["Goodale Park"]
    assert calls


def test_unknown_coverage_keeps_the_old_overpass_behaviour():
    calls = []
    park = {
        "type": "node",
        "id": 8,
        "lat": RURAL_NEW_YORK[0],
        "lon": RURAL_NEW_YORK[1],
        "tags": {"name": "Quiet Park", "leisure": "park"},
    }

    spots = _find(*RURAL_NEW_YORK, FakeCoverage(None), client=_overpass_client(calls, [park]))

    assert [spot.name for spot in spots] == ["Quiet Park"]
    assert calls


def test_message_uses_display_names(monkeypatch):
    monkeypatch.setattr(
        coverage_module, "loaded_regions", lambda: ["texas", "district-of-columbia", "new-york"]
    )

    assert outside_coverage_message() == (
        "Vesper doesn't cover this area yet. "
        "It currently covers New York, Texas, Washington, DC, with more on the way."
    )


def test_message_sorts_names_and_summarises_long_lists(monkeypatch):
    monkeypatch.setattr(coverage_module, "loaded_regions", lambda: ["texas", "new-york", "alabama"])
    assert "Alabama, New York, Texas" in outside_coverage_message()

    many = [
        "alabama", "arizona", "arkansas", "california", "colorado", "connecticut",
        "delaware", "florida", "georgia", "hawaii", "idaho",
    ]  # fmt: skip
    monkeypatch.setattr(coverage_module, "loaded_regions", lambda: many)
    message = outside_coverage_message()
    assert "11 US states and regions" in message
    assert "Alabama" not in message


def test_message_without_any_regions_still_reads_well(monkeypatch):
    monkeypatch.setattr(coverage_module, "loaded_regions", lambda: [])
    assert outside_coverage_message() == (
        "Vesper doesn't cover this area yet. More places are on the way."
    )


def test_coverage_endpoint_lists_regions_with_bounds(client, monkeypatch):
    monkeypatch.setattr(
        coverage_module, "loaded_regions", lambda: ["texas", "district-of-columbia"]
    )

    response = client.get("/coverage")

    assert response.status_code == 200
    regions = response.json()["regions"]
    assert [r["name"] for r in regions] == ["Texas", "Washington, DC"]
    texas = regions[0]
    assert texas["slug"] == "texas"
    assert texas["south"] < texas["north"] and texas["west"] < texas["east"]


def test_coverage_endpoint_needs_no_sign_in(client):
    app.dependency_overrides.pop(get_current_user_id, None)

    assert client.get("/coverage").status_code == 200


@pytest.mark.parametrize(
    ("method", "path", "payload"),
    [
        ("get", "/places/nearby", {"params": {"lat": 39.96, "lon": -83.0}}),
        (
            "post",
            "/session",
            {
                "json": {
                    "lat": 39.96,
                    "lon": -83.0,
                    "event": "sunset",
                    "date": "2026-11-20",
                    "place_types": ["park"],
                }
            },
        ),
    ],
)
def test_endpoints_tell_the_user_where_vesper_works(client, monkeypatch, method, path, payload):
    def refuse(*_args, **_kwargs):
        raise OutsideCoverage("outside")

    monkeypatch.setattr(places_api, "find_candidate_locations", refuse)
    monkeypatch.setattr(session_api, "find_candidate_locations", refuse)
    monkeypatch.setattr(coverage_module, "loaded_regions", lambda: ["new-york", "texas"])

    response = getattr(client, method)(path, **payload)

    assert response.status_code == 422
    assert response.json()["detail"] == (
        "Vesper doesn't cover this area yet. "
        "It currently covers New York, Texas, with more on the way."
    )
