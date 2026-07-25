from datetime import date

import httpx

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


def _mock_client() -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["latitude"] == "40.7128"
        assert request.url.params["longitude"] == "-74.006"
        return httpx.Response(200, json=SAMPLE_RESPONSE)

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_fetch_hourly_forecast_parses_response_into_schema():
    forecast = fetch_hourly_forecast(
        40.7128, -74.0060, date(2026, 7, 25), client=_mock_client()
    )

    assert len(forecast.hourly) == 3
    first = forecast.hourly[0]
    assert first.cloud_cover_low == 10
    assert first.cloud_cover_mid == 5
    assert first.cloud_cover_high == 40
    assert first.weather_code == 1


def test_fetch_hourly_forecast_raises_on_http_error():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    client = httpx.Client(transport=httpx.MockTransport(handler))

    try:
        fetch_hourly_forecast(40.7128, -74.0060, date(2026, 7, 25), client=client)
        raise AssertionError("expected HTTPStatusError")
    except httpx.HTTPStatusError:
        pass
