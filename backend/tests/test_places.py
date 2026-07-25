import httpx

from app.schemas.location import LocationSource, LocationType
from app.services.places import find_candidate_locations

# Far from every curated fallback entry (all in NYC), so generic OSM-parsing
# tests aren't accidentally affected by curated data.
RURAL_LAT, RURAL_LON = 41.5, -75.5

TOP_OF_THE_ROCK = (40.7590, -73.9787)


class FakeCache:
    def __init__(self):
        self._store: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self._store.get(key)

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        self._store[key] = value


def _client_returning(payload: dict, call_counter: list[int] | None = None) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        if call_counter is not None:
            call_counter.append(1)
        return httpx.Response(200, json=payload)

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_parses_osm_elements_filters_unnamed_and_unmatched():
    payload = {
        "elements": [
            {
                "type": "node",
                "id": 1,
                "lat": RURAL_LAT + 0.01,
                "lon": RURAL_LON,
                "tags": {"name": "Test Park", "leisure": "park"},
            },
            {
                "type": "way",
                "id": 2,
                "center": {"lat": RURAL_LAT, "lon": RURAL_LON + 0.01},
                "tags": {"name": "Test Beach", "natural": "beach"},
            },
            {
                "type": "node",
                "id": 3,
                "lat": RURAL_LAT,
                "lon": RURAL_LON,
                "tags": {"leisure": "park"},  # no name -> excluded
            },
            {
                "type": "node",
                "id": 4,
                "lat": RURAL_LAT,
                "lon": RURAL_LON,
                "tags": {"name": "Corner Shop", "shop": "convenience"},  # unmatched tag -> excluded
            },
        ]
    }
    client = _client_returning(payload)

    records = find_candidate_locations(
        RURAL_LAT,
        RURAL_LON,
        radius_km=5.0,
        place_types=[LocationType.PARK, LocationType.BEACH],
        client=client,
        cache=FakeCache(),
    )

    names = {r.name for r in records}
    assert names == {"Test Park", "Test Beach"}
    assert all(r.source == LocationSource.OSM for r in records)


def test_results_are_sorted_by_distance():
    payload = {
        "elements": [
            {
                "type": "node",
                "id": 1,
                "lat": RURAL_LAT + 0.05,
                "lon": RURAL_LON,
                "tags": {"name": "Farther Park", "leisure": "park"},
            },
            {
                "type": "node",
                "id": 2,
                "lat": RURAL_LAT + 0.01,
                "lon": RURAL_LON,
                "tags": {"name": "Closer Park", "leisure": "park"},
            },
        ]
    }
    client = _client_returning(payload)

    records = find_candidate_locations(
        RURAL_LAT,
        RURAL_LON,
        radius_km=10.0,
        place_types=[LocationType.PARK],
        client=client,
        cache=FakeCache(),
    )

    assert [r.name for r in records] == ["Closer Park", "Farther Park"]


def test_curated_fallback_fills_in_when_osm_has_no_results():
    client = _client_returning({"elements": []})
    lat, lon = TOP_OF_THE_ROCK

    records = find_candidate_locations(
        lat,
        lon,
        radius_km=1.0,
        place_types=[LocationType.ELEVATED_VIEWPOINT],
        client=client,
        cache=FakeCache(),
    )

    assert len(records) == 1
    assert records[0].name == "Top of the Rock"
    assert records[0].source == LocationSource.CURATED


def test_curated_entry_is_deduped_when_osm_already_has_it():
    lat, lon = TOP_OF_THE_ROCK
    payload = {
        "elements": [
            {
                "type": "node",
                "id": 99,
                "lat": lat,
                "lon": lon,
                "tags": {"name": "Top of the Rock", "tourism": "viewpoint"},
            }
        ]
    }
    client = _client_returning(payload)

    records = find_candidate_locations(
        lat,
        lon,
        radius_km=1.0,
        place_types=[LocationType.ELEVATED_VIEWPOINT],
        client=client,
        cache=FakeCache(),
    )

    assert len(records) == 1
    assert records[0].source == LocationSource.OSM


def test_second_call_with_same_params_hits_cache_not_overpass():
    payload = {
        "elements": [
            {
                "type": "node",
                "id": 1,
                "lat": RURAL_LAT,
                "lon": RURAL_LON,
                "tags": {"name": "Test Park", "leisure": "park"},
            }
        ]
    }
    calls: list[int] = []
    cache = FakeCache()

    for _ in range(2):
        client = _client_returning(payload, call_counter=calls)
        find_candidate_locations(
            RURAL_LAT,
            RURAL_LON,
            radius_km=5.0,
            place_types=[LocationType.PARK],
            client=client,
            cache=cache,
        )

    assert len(calls) == 1
