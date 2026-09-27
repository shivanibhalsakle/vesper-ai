from datetime import date

import httpx
import redis

from app.services.weather import fetch_hourly_forecast

SAMPLE_RESPONSE = {
    "hourly": {
        "time": ["2026-07-25T19:00", "2026-07-25T20:00", "2026-07-25T21:00"],
        "cloud_cover_low": [10, 20, 30],
        "cloud_cover_mid": [5, 15, 25],
        "cloud_cover_high": [40, 50, 60],
        "visibility": [24000, 20000, 18000],
        "uv_index": [0.5, 0.1, 0.0],
        "precipitation_probability": [0, 5, 10],
        "weather_code": [1, 2, 3],
    }
}


class InMemoryCache:
    def __init__(self):
        self.store: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self.store.get(key)

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        self.store[key] = value


class BrokenCache:
    def get(self, key: str) -> str | None:
        raise redis.ConnectionError("redis down")

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        raise redis.ConnectionError("redis down")


def _counting_client(requests: list) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json=SAMPLE_RESPONSE)

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_fetch_hourly_forecast_parses_response_into_schema():
    requests: list[httpx.Request] = []

    forecast = fetch_hourly_forecast(
        40.7128,
        -74.0060,
        date(2026, 7, 25),
        client=_counting_client(requests),
        cache=InMemoryCache(),
    )

    assert len(forecast.hourly) == 3
    first = forecast.hourly[0]
    assert first.cloud_cover_low == 10
    assert first.cloud_cover_mid == 5
    assert first.cloud_cover_high == 40
    assert first.weather_code == 1


def test_fetch_hourly_forecast_requests_rounded_grid_coordinates():
    requests: list[httpx.Request] = []

    fetch_hourly_forecast(
        40.7128,
        -74.0060,
        date(2026, 7, 25),
        client=_counting_client(requests),
        cache=InMemoryCache(),
    )

    assert requests[0].url.params["latitude"] == "40.71"
    assert requests[0].url.params["longitude"] == "-74.01"


def test_fetch_hourly_forecast_raises_on_http_error():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    client = httpx.Client(transport=httpx.MockTransport(handler))

    try:
        fetch_hourly_forecast(
            40.7128, -74.0060, date(2026, 7, 25), client=client, cache=InMemoryCache()
        )
        raise AssertionError("expected HTTPStatusError")
    except httpx.HTTPStatusError:
        pass


def test_second_call_for_same_grid_cell_is_served_from_cache():
    requests: list[httpx.Request] = []
    cache = InMemoryCache()
    client = _counting_client(requests)

    first = fetch_hourly_forecast(
        40.7128, -74.0060, date(2026, 7, 25), client=client, cache=cache
    )
    # A slightly different point in the same ~1km cell.
    second = fetch_hourly_forecast(
        40.7131, -74.0058, date(2026, 7, 25), client=client, cache=cache
    )

    assert len(requests) == 1
    assert second == first


def test_different_date_or_cell_is_not_a_cache_hit():
    requests: list[httpx.Request] = []
    cache = InMemoryCache()
    client = _counting_client(requests)

    fetch_hourly_forecast(40.7128, -74.0060, date(2026, 7, 25), client=client, cache=cache)
    fetch_hourly_forecast(40.7128, -74.0060, date(2026, 7, 26), client=client, cache=cache)
    fetch_hourly_forecast(40.9000, -74.0060, date(2026, 7, 25), client=client, cache=cache)

    assert len(requests) == 3


def test_failed_fetch_is_not_cached():
    cache = InMemoryCache()

    def failing(request: httpx.Request) -> httpx.Response:
        return httpx.Response(429)

    try:
        fetch_hourly_forecast(
            40.7128,
            -74.0060,
            date(2026, 7, 25),
            client=httpx.Client(transport=httpx.MockTransport(failing)),
            cache=cache,
        )
    except httpx.HTTPStatusError:
        pass

    assert cache.store == {}


def test_retries_on_429_and_succeeds(monkeypatch):
    monkeypatch.setattr("app.services.weather.time.sleep", lambda seconds: None)
    attempts = {"count": 0}

    def flaky(request: httpx.Request) -> httpx.Response:
        attempts["count"] += 1
        if attempts["count"] < 3:
            return httpx.Response(429)
        return httpx.Response(200, json=SAMPLE_RESPONSE)

    forecast = fetch_hourly_forecast(
        40.7128,
        -74.0060,
        date(2026, 7, 25),
        client=httpx.Client(transport=httpx.MockTransport(flaky)),
        cache=InMemoryCache(),
    )

    assert attempts["count"] == 3
    assert len(forecast.hourly) == 3


def test_gives_up_after_max_attempts_on_persistent_429(monkeypatch):
    monkeypatch.setattr("app.services.weather.time.sleep", lambda seconds: None)
    attempts = {"count": 0}

    def always_fails(request: httpx.Request) -> httpx.Response:
        attempts["count"] += 1
        return httpx.Response(429)

    try:
        fetch_hourly_forecast(
            40.7128,
            -74.0060,
            date(2026, 7, 25),
            client=httpx.Client(transport=httpx.MockTransport(always_fails)),
            cache=InMemoryCache(),
        )
        raise AssertionError("expected HTTPStatusError")
    except httpx.HTTPStatusError:
        pass

    assert attempts["count"] == 3


def test_does_not_retry_on_a_non_retryable_status(monkeypatch):
    monkeypatch.setattr("app.services.weather.time.sleep", lambda seconds: None)
    attempts = {"count": 0}

    def bad_request(request: httpx.Request) -> httpx.Response:
        attempts["count"] += 1
        return httpx.Response(400)

    try:
        fetch_hourly_forecast(
            40.7128,
            -74.0060,
            date(2026, 7, 25),
            client=httpx.Client(transport=httpx.MockTransport(bad_request)),
            cache=InMemoryCache(),
        )
        raise AssertionError("expected HTTPStatusError")
    except httpx.HTTPStatusError:
        pass

    assert attempts["count"] == 1


def test_retries_on_connection_error(monkeypatch):
    monkeypatch.setattr("app.services.weather.time.sleep", lambda seconds: None)
    attempts = {"count": 0}

    def flaky_connection(request: httpx.Request) -> httpx.Response:
        attempts["count"] += 1
        if attempts["count"] < 2:
            raise httpx.ConnectError("connection refused", request=request)
        return httpx.Response(200, json=SAMPLE_RESPONSE)

    forecast = fetch_hourly_forecast(
        40.7128,
        -74.0060,
        date(2026, 7, 25),
        client=httpx.Client(transport=httpx.MockTransport(flaky_connection)),
        cache=InMemoryCache(),
    )

    assert attempts["count"] == 2
    assert len(forecast.hourly) == 3


def test_cache_outage_falls_back_to_a_live_fetch():
    requests: list[httpx.Request] = []

    forecast = fetch_hourly_forecast(
        40.7128,
        -74.0060,
        date(2026, 7, 25),
        client=_counting_client(requests),
        cache=BrokenCache(),
    )

    assert len(requests) == 1
    assert len(forecast.hourly) == 3
