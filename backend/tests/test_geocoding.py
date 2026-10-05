import httpx
import pytest

import app.api.geocode as geocode_api
from app.schemas.geocode import GeocodeResult
from app.services import geocoding
from app.services.geocoding import (
    DAILY_LIMIT_PER_USER,
    GeocodeLimitExceeded,
    GeocodingUnavailable,
    ensure_within_daily_limit,
    geocode,
)


class FakeCache:
    def __init__(self):
        self.store: dict[str, str] = {}
        self.counters: dict[str, int] = {}

    def get(self, key):
        return self.store.get(key)

    def set(self, key, value, ttl_seconds):
        self.store[key] = value

    def incr(self, key, ttl_seconds):
        self.counters[key] = self.counters.get(key, 0) + 1
        return self.counters[key]


class BrokenCache:
    def get(self, key):
        raise ConnectionError("redis down")

    def set(self, key, value, ttl_seconds):
        raise ConnectionError("redis down")

    def incr(self, key, ttl_seconds):
        raise ConnectionError("redis down")


@pytest.fixture(autouse=True)
def api_key(monkeypatch):
    monkeypatch.setattr(
        geocoding, "get_settings", lambda: type("S", (), {"geoapify_api_key": "test-key"})()
    )


PAYLOAD = {
    "results": [
        {"formatted": "Brooklyn Bridge Park, Brooklyn, NY, USA", "lat": 40.7003, "lon": -73.9967},
        {"name": "Brooklyn", "lat": 40.65, "lon": -73.95},
        {"formatted": "Broken", "lat": "nope", "lon": -73.0},
    ]
}


def _client(payload=None, status=200, calls=None):
    def handler(request: httpx.Request) -> httpx.Response:
        if calls is not None:
            calls.append(request)
        return httpx.Response(status, json=payload if payload is not None else PAYLOAD)

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_parses_results_and_skips_malformed_entries():
    results = geocode("brooklyn", client=_client(), cache=FakeCache())

    assert [r.label for r in results] == [
        "Brooklyn Bridge Park, Brooklyn, NY, USA",
        "Brooklyn",
    ]
    assert results[0].lat == 40.7003


def test_second_search_is_served_from_cache():
    cache, calls = FakeCache(), []

    geocode("Brooklyn  Bridge", client=_client(calls=calls), cache=cache)
    again = geocode("brooklyn bridge", client=_client(calls=calls), cache=cache)

    assert len(calls) == 1
    assert again[0].label.startswith("Brooklyn Bridge Park")


def test_empty_results_are_not_cached():
    cache, calls = FakeCache(), []

    assert geocode("zzzz", client=_client({"results": []}, calls=calls), cache=cache) == []
    assert cache.store == {}


def test_provider_failure_raises_unavailable():
    with pytest.raises(GeocodingUnavailable):
        geocode("brooklyn", client=_client(status=500), cache=FakeCache())


def test_missing_api_key_raises_unavailable(monkeypatch):
    monkeypatch.setattr(
        geocoding, "get_settings", lambda: type("S", (), {"geoapify_api_key": ""})()
    )

    with pytest.raises(GeocodingUnavailable):
        geocode("brooklyn", client=_client(), cache=FakeCache())


def test_broken_cache_degrades_to_a_live_lookup():
    results = geocode("brooklyn", client=_client(), cache=BrokenCache())

    assert len(results) == 2


def test_failure_message_never_leaks_the_api_key():
    with pytest.raises(GeocodingUnavailable) as excinfo:
        geocode("brooklyn", client=_client(status=500), cache=FakeCache())

    assert "test-key" not in str(excinfo.value)


def test_daily_limit_blocks_after_the_allowance():
    cache = FakeCache()
    for _ in range(DAILY_LIMIT_PER_USER):
        ensure_within_daily_limit("u1", cache)

    with pytest.raises(GeocodeLimitExceeded):
        ensure_within_daily_limit("u1", cache)
    ensure_within_daily_limit("u2", cache)  # other users unaffected


def test_daily_limit_fails_open_when_redis_is_down():
    ensure_within_daily_limit("u1", BrokenCache())


def test_endpoint_returns_results(client, monkeypatch):
    monkeypatch.setattr(geocode_api, "ensure_within_daily_limit", lambda user_id: None)
    monkeypatch.setattr(
        geocode_api, "geocode", lambda q: [GeocodeResult(label="Somewhere", lat=1.0, lon=2.0)]
    )

    response = client.get("/geocode", params={"q": "somewhere"})

    assert response.status_code == 200
    assert response.json() == [{"label": "Somewhere", "lat": 1.0, "lon": 2.0}]


def test_endpoint_maps_provider_failure_to_503(client, monkeypatch):
    monkeypatch.setattr(geocode_api, "ensure_within_daily_limit", lambda user_id: None)

    def boom(q):
        raise GeocodingUnavailable("down")

    monkeypatch.setattr(geocode_api, "geocode", boom)

    assert client.get("/geocode", params={"q": "somewhere"}).status_code == 503


def test_endpoint_maps_limit_to_429(client, monkeypatch):
    def over(user_id):
        raise GeocodeLimitExceeded("too many")

    monkeypatch.setattr(geocode_api, "ensure_within_daily_limit", over)

    response = client.get("/geocode", params={"q": "somewhere"})

    assert response.status_code == 429
    assert response.json()["detail"] == "too many"


def test_endpoint_rejects_too_short_queries(client):
    assert client.get("/geocode", params={"q": "a"}).status_code == 422
