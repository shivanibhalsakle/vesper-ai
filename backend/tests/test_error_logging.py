import logging

import httpx
import pytest

import app.api.best_date as best_date_api
import app.api.places as places_api
import app.api.session as session_api
import app.api.sky as sky_api
from app.core.diagnostics import describe_error, describe_place_error
from app.services.places import PlaceDataUnavailable


def _http_429() -> httpx.HTTPStatusError:
    request = httpx.Request("GET", "https://api.open-meteo.com/v1/forecast?latitude=40.7&longitude=-74.0")
    response = httpx.Response(429, request=request)
    return httpx.HTTPStatusError("Too Many Requests", request=request, response=response)


def test_describe_error_gives_type_and_status_and_nothing_else():
    assert describe_error(_http_429()) == "HTTPStatusError (HTTP 429)"
    assert describe_error(httpx.ConnectTimeout("slow")) == "ConnectTimeout"
    assert describe_error(None) == "none"


def test_describe_place_error_includes_the_cause():
    try:
        try:
            raise httpx.ReadTimeout("slow")
        except httpx.ReadTimeout as cause:
            raise PlaceDataUnavailable("All Overpass attempts failed") from cause
    except PlaceDataUnavailable as exc:
        assert describe_place_error(exc) == "All Overpass attempts failed; cause: ReadTimeout"


def test_sky_failure_is_logged_without_the_url_or_coordinates(client, monkeypatch, caplog):
    def fail(_request):
        raise _http_429()

    monkeypatch.setattr(sky_api, "sky_at", fail)

    with caplog.at_level(logging.WARNING):
        response = client.post(
            "/sky",
            json={"lat": 40.7, "lon": -74.0, "event": "sunset", "date": "2026-10-20"},
        )

    assert response.status_code == 503
    assert "Weather data is temporarily unavailable" in response.json()["detail"]
    assert "Weather provider failed: HTTPStatusError (HTTP 429)" in caplog.text
    assert "open-meteo" not in caplog.text
    assert "40.7" not in caplog.text


def test_place_failure_is_logged_with_its_cause(client, monkeypatch, caplog):
    def fail(*_args, **_kwargs):
        try:
            raise httpx.ConnectError("no route")
        except httpx.ConnectError as cause:
            raise PlaceDataUnavailable("All Overpass attempts failed") from cause

    monkeypatch.setattr(places_api, "find_candidate_locations", fail)

    with caplog.at_level(logging.WARNING):
        response = client.get("/places/nearby", params={"lat": 40.7, "lon": -74.0})

    assert response.status_code == 503
    assert "Place data is temporarily unavailable" in response.json()["detail"]
    assert (
        "Place data unavailable: All Overpass attempts failed; cause: ConnectError"
        in caplog.text
    )


@pytest.mark.parametrize("module", [session_api, best_date_api])
def test_the_other_endpoints_log_too(module):
    # Each handler that can return one of these 503s carries a logger and the
    # helpers (the behaviour itself is covered above for sky and places).
    assert isinstance(module.logger, logging.Logger)
    assert module.describe_error is describe_error
    assert module.describe_place_error is describe_place_error
