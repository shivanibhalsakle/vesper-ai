from datetime import datetime, timedelta, timezone

import httpx
import pytest
import redis

from app.schemas.location import LocationSource, LocationType
from app.services.place_store import PostgresPlaceStore, StoredPlaces
from app.services.places import (
    CACHE_TTL_SECONDS,
    PlaceDataUnavailable,
    _cache_key,
    find_candidate_locations,
)

# Far from every curated fallback entry (all in NYC), so generic OSM-parsing
# tests aren't accidentally affected by curated data.
RURAL_LAT, RURAL_LON = 41.5, -75.5

TOP_OF_THE_ROCK = (40.7590, -73.9787)


@pytest.fixture(autouse=True)
def no_retry_sleep(monkeypatch):
    monkeypatch.setattr("app.services.places.time.sleep", lambda seconds: None)


class FakeCache:
    def __init__(self):
        self._store: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self._store.get(key)

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        self._store[key] = value


class BrokenCache:
    def get(self, key: str) -> str | None:
        raise redis.ConnectionError("redis down")

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        raise redis.ConnectionError("redis down")


class FakeStore:
    def __init__(self):
        self.entries: dict[str, StoredPlaces] = {}
        self.writes = 0

    def get(self, key: str) -> StoredPlaces | None:
        return self.entries.get(key)

    def set(self, key: str, payload: list[dict]) -> None:
        self.writes += 1
        self.entries[key] = StoredPlaces(payload=payload, fetched_at=_now())


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _client_returning(payload: dict, call_counter: list[int] | None = None) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        if call_counter is not None:
            call_counter.append(1)
        return httpx.Response(200, json=payload)

    return httpx.Client(transport=httpx.MockTransport(handler))


def _client_raising(status_code: int) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code)

    return httpx.Client(transport=httpx.MockTransport(handler))


class FakeIndex:
    """Stands in for our loaded osm_places table; empty unless given results."""

    def __init__(self, results: list[dict] | None = None):
        self.results = results or []
        self.searches = 0

    def search(self, lat, lon, radius_km, place_types):
        self.searches += 1
        return self.results


def _find(lat, lon, radius_km, place_types, client, cache=None, store=None, index=None):
    return find_candidate_locations(
        lat,
        lon,
        radius_km=radius_km,
        place_types=place_types,
        client=client,
        cache=cache if cache is not None else FakeCache(),
        store=store if store is not None else FakeStore(),
        index=index if index is not None else FakeIndex(),
    )


def _park_element(element_id: int, name: str, dlat: float = 0.0) -> dict:
    return {
        "type": "node",
        "id": element_id,
        "lat": RURAL_LAT + dlat,
        "lon": RURAL_LON,
        "tags": {"name": name, "leisure": "park"},
    }


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

    records = _find(
        RURAL_LAT,
        RURAL_LON,
        5.0,
        [LocationType.PARK, LocationType.BEACH],
        _client_returning(payload),
    )

    names = {r.name for r in records}
    assert names == {"Test Park", "Test Beach"}
    assert all(r.source == LocationSource.OSM for r in records)


def test_results_are_sorted_by_distance():
    payload = {
        "elements": [
            _park_element(1, "Farther Park", dlat=0.05),
            _park_element(2, "Closer Park", dlat=0.01),
        ]
    }

    records = _find(RURAL_LAT, RURAL_LON, 10.0, [LocationType.PARK], _client_returning(payload))

    assert [r.name for r in records] == ["Closer Park", "Farther Park"]


def test_curated_fallback_fills_in_when_osm_has_no_results():
    lat, lon = TOP_OF_THE_ROCK

    records = _find(
        lat, lon, 1.0, [LocationType.ELEVATED_VIEWPOINT], _client_returning({"elements": []})
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

    records = _find(lat, lon, 1.0, [LocationType.ELEVATED_VIEWPOINT], _client_returning(payload))

    assert len(records) == 1
    assert records[0].source == LocationSource.OSM


def test_overpass_failure_falls_back_to_curated_without_raising():
    lat, lon = TOP_OF_THE_ROCK

    records = _find(lat, lon, 1.0, [LocationType.ELEVATED_VIEWPOINT], _client_raising(504))

    assert len(records) == 1
    assert records[0].name == "Top of the Rock"
    assert records[0].source == LocationSource.CURATED


def test_overpass_failure_with_nothing_to_fall_back_on_raises_unavailable():
    # An outage must be distinguishable from "this area has no places".
    with pytest.raises(PlaceDataUnavailable):
        _find(RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], _client_raising(504))


def test_overpass_failure_is_not_cached_or_stored():
    lat, lon = TOP_OF_THE_ROCK
    cache, store = FakeCache(), FakeStore()

    _find(lat, lon, 1.0, [LocationType.ELEVATED_VIEWPOINT], _client_raising(504), cache, store)

    assert cache._store == {}
    assert store.writes == 0


def test_retries_across_mirrors_until_one_succeeds():
    hosts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        hosts.append(request.url.host)
        if len(hosts) == 1:
            return httpx.Response(503)
        return httpx.Response(200, json={"elements": [_park_element(1, "Mirror Park")]})

    client = httpx.Client(transport=httpx.MockTransport(handler))

    records = _find(RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], client)

    assert [r.name for r in records] == ["Mirror Park"]
    assert len(hosts) == 2
    assert hosts[0] != hosts[1]


def test_http_200_with_runtime_error_remark_is_a_failure_not_an_empty_result():
    # Overpass reports overload/timeouts as 200 + a remark + no elements.
    cache, store = FakeCache(), FakeStore()
    client = _client_returning(
        {"elements": [], "remark": 'runtime error: Query timed out in "query" at line 3'}
    )

    with pytest.raises(PlaceDataUnavailable):
        _find(RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], client, cache, store)

    assert cache._store == {}
    assert store.writes == 0


def test_html_error_page_with_200_status_is_a_failure():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="<html><body>Error</body></html>")

    client = httpx.Client(transport=httpx.MockTransport(handler))

    with pytest.raises(PlaceDataUnavailable):
        _find(RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], client)


def test_second_call_with_same_params_hits_cache_not_overpass():
    payload = {"elements": [_park_element(1, "Test Park")]}
    calls: list[int] = []
    cache, store = FakeCache(), FakeStore()

    for _ in range(2):
        _find(
            RURAL_LAT,
            RURAL_LON,
            5.0,
            [LocationType.PARK],
            _client_returning(payload, call_counter=calls),
            cache,
            store,
        )

    assert len(calls) == 1


def test_different_place_type_filters_share_one_overpass_fetch():
    payload = {
        "elements": [
            _park_element(1, "Test Park"),
            {
                "type": "node",
                "id": 2,
                "lat": RURAL_LAT,
                "lon": RURAL_LON,
                "tags": {"name": "Test Beach", "natural": "beach"},
            },
        ]
    }
    calls: list[int] = []
    cache, store = FakeCache(), FakeStore()

    parks = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK],
        _client_returning(payload, calls), cache, store,
    )
    beaches = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.BEACH],
        _client_returning(payload, calls), cache, store,
    )

    assert len(calls) == 1
    assert [r.name for r in parks] == ["Test Park"]
    assert [r.name for r in beaches] == ["Test Beach"]


def test_results_beyond_requested_radius_are_filtered_out():
    # ~8.9km north: inside the 10km cache bucket, outside a 6km request.
    payload = {"elements": [_park_element(1, "Far Park", dlat=0.08)]}
    calls: list[int] = []
    cache, store = FakeCache(), FakeStore()

    near = _find(
        RURAL_LAT, RURAL_LON, 6.0, [LocationType.PARK],
        _client_returning(payload, calls), cache, store,
    )
    wide = _find(
        RURAL_LAT, RURAL_LON, 10.0, [LocationType.PARK],
        _client_returning(payload, calls), cache, store,
    )

    assert near == []
    assert [r.name for r in wide] == ["Far Park"]
    assert len(calls) == 1  # both radii share the 10km bucket


def test_fresh_stored_entry_avoids_overpass_and_warms_the_cache():
    key = _cache_key(RURAL_LAT, RURAL_LON, 5.0)
    store, cache = FakeStore(), FakeCache()
    store.entries[key] = StoredPlaces(
        payload=[
            {"id": "osm:node/7", "name": "Stored Park", "types": ["park"],
             "lat": RURAL_LAT, "lon": RURAL_LON}
        ],
        fetched_at=_now() - timedelta(days=1),
    )
    calls: list[int] = []

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK],
        _client_returning({"elements": []}, calls), cache, store,
    )

    assert [r.name for r in records] == ["Stored Park"]
    assert calls == []
    assert key in cache._store


def test_expired_stored_entry_is_refreshed_when_overpass_is_up():
    key = _cache_key(RURAL_LAT, RURAL_LON, 5.0)
    store = FakeStore()
    store.entries[key] = StoredPlaces(
        payload=[
            {"id": "osm:node/7", "name": "Old Park", "types": ["park"],
             "lat": RURAL_LAT, "lon": RURAL_LON}
        ],
        fetched_at=_now() - timedelta(seconds=CACHE_TTL_SECONDS + 3600),
    )

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK],
        _client_returning({"elements": [_park_element(1, "New Park")]}), FakeCache(), store,
    )

    assert [r.name for r in records] == ["New Park"]
    assert store.writes == 1


def test_expired_stored_entry_is_served_when_overpass_is_down():
    key = _cache_key(RURAL_LAT, RURAL_LON, 5.0)
    store = FakeStore()
    store.entries[key] = StoredPlaces(
        payload=[
            {"id": "osm:node/7", "name": "Old Park", "types": ["park"],
             "lat": RURAL_LAT, "lon": RURAL_LON}
        ],
        fetched_at=_now() - timedelta(seconds=CACHE_TTL_SECONDS + 3600),
    )

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], _client_raising(504), FakeCache(), store
    )

    assert [r.name for r in records] == ["Old Park"]


def test_redis_outage_falls_back_to_a_live_fetch():
    payload = {"elements": [_park_element(1, "Test Park")]}

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK],
        _client_returning(payload), BrokenCache(), FakeStore(),
    )

    assert [r.name for r in records] == ["Test Park"]


def test_postgres_store_round_trip_and_upsert(db_session):
    store = PostgresPlaceStore(session_factory=lambda: db_session)

    assert store.get("places:v2:test") is None

    store.set("places:v2:test", [{"id": "x"}])
    stored = store.get("places:v2:test")
    assert stored is not None
    assert stored.payload == [{"id": "x"}]

    store.set("places:v2:test", [{"id": "y"}])
    assert store.get("places:v2:test").payload == [{"id": "y"}]


def _indexed(place_id: str, name: str, types: list[str], dlat: float = 0.0) -> dict:
    return {
        "id": place_id,
        "name": name,
        "types": types,
        "lat": RURAL_LAT + dlat,
        "lon": RURAL_LON,
    }


def test_loaded_places_are_served_without_touching_overpass():
    index = FakeIndex([_indexed("osm:node/1", "Loaded Park", ["park"])])
    calls: list[int] = []

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK],
        _client_returning({"elements": []}, calls), index=index,
    )

    assert [r.name for r in records] == ["Loaded Park"]
    assert records[0].source == LocationSource.OSM
    assert calls == []


def test_loaded_places_work_even_when_overpass_is_down():
    index = FakeIndex([_indexed("osm:node/1", "Loaded Park", ["park"])])

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], _client_raising(504), index=index
    )

    assert [r.name for r in records] == ["Loaded Park"]


def test_loaded_places_are_filtered_by_type_and_radius():
    index = FakeIndex(
        [
            _indexed("osm:node/1", "Park And Beach", ["park", "beach"], dlat=0.01),
            _indexed("osm:node/2", "Only A Park", ["park"], dlat=0.01),
            _indexed("osm:node/3", "Too Far Beach", ["beach"], dlat=0.5),
        ]
    )

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.BEACH], _client_raising(504), index=index
    )

    assert [r.name for r in records] == ["Park And Beach"]
    assert records[0].type == LocationType.BEACH


def test_loaded_places_are_merged_with_curated_ones():
    lat, lon = TOP_OF_THE_ROCK
    index = FakeIndex(
        [
            {
                "id": "osm:node/9",
                "name": "Some Rooftop",
                "types": ["elevated_viewpoint"],
                "lat": lat + 0.001,
                "lon": lon,
            }
        ]
    )

    records = _find(
        lat, lon, 1.0, [LocationType.ELEVATED_VIEWPOINT], _client_raising(504), index=index
    )

    assert {r.name for r in records} == {"Some Rooftop", "Top of the Rock"}


def test_empty_index_falls_through_to_the_overpass_path():
    index = FakeIndex()
    payload = {"elements": [_park_element(1, "Overpass Park")]}

    records = _find(
        RURAL_LAT, RURAL_LON, 5.0, [LocationType.PARK], _client_returning(payload), index=index
    )

    assert index.searches == 1
    assert [r.name for r in records] == ["Overpass Park"]
