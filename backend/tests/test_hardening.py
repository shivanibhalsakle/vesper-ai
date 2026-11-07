import pytest
from sqlalchemy.exc import OperationalError

from app.db.session import engine, get_db
from app.main import app, docs_settings

SESSION_BODY = {
    "lat": 40.7,
    "lon": -74.0,
    "event": "sunset",
    "date": "2026-11-20",
    "place_types": ["park"],
}
TRIP_BODY = {
    "lat": 40.7,
    "lon": -74.0,
    "event": "sunset",
    "start_date": "2026-11-20",
    "end_date": "2026-11-22",
    "place_types": ["park"],
}
SIMULATION_BODY = {
    "location_name": "Central Park",
    "event": "sunset",
    "cloud_cover_summary": "mostly clear skies",
    "visibility_likelihood": 0.8,
    "color_probabilities": {"pink": 0.1, "purple": 0.1, "orange": 0.5, "red": 0.1, "golden": 0.6},
}


@pytest.mark.parametrize("path, body", [("/session", SESSION_BODY), ("/trip-window", TRIP_BODY)])
@pytest.mark.parametrize(
    "changes",
    [{"lat": 95}, {"lat": -90.5}, {"lon": 999}, {"lon": -180.5}, {"tz_name": "x" * 65}],
)
def test_out_of_range_location_is_rejected_before_any_lookup(client, monkeypatch, path, body, changes):
    def must_not_run(*_args, **_kwargs):
        raise AssertionError("place lookup ran for an invalid request")

    monkeypatch.setattr("app.api.session.find_candidate_locations", must_not_run)
    monkeypatch.setattr("app.api.trip_window.find_best_day_and_location", must_not_run)

    response = client.post(path, json={**body, **changes})

    assert response.status_code == 422


@pytest.mark.parametrize(
    "changes",
    [
        {"location_name": ""},
        {"location_name": "x" * 121},
        {"cloud_cover_summary": "x" * 81},
    ],
)
def test_preview_request_text_is_length_limited(client, changes):
    response = client.post("/simulate", json={**SIMULATION_BODY, **changes})

    assert response.status_code == 422


def test_preview_request_at_the_limits_is_accepted_by_validation(client):
    # Past validation the request reaches the (unconfigured) provider path, so
    # anything but a 422 means the lengths themselves were fine.
    response = client.post(
        "/simulate",
        json={**SIMULATION_BODY, "location_name": "x" * 120, "cloud_cover_summary": "y" * 80},
    )

    assert response.status_code != 422


def test_api_docs_are_off_in_production_only():
    assert docs_settings("production") == {"docs_url": None, "redoc_url": None, "openapi_url": None}
    assert docs_settings("development") == {}


def test_health_stays_database_free(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_ready_check_passes_with_a_working_database(client):
    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_check_reports_a_database_outage(client):
    class BrokenSession:
        def execute(self, statement):
            raise OperationalError("SELECT 1", {}, Exception("db down"))

    app.dependency_overrides[get_db] = lambda: BrokenSession()

    response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.json()["detail"] == "Database unavailable"


def test_database_connections_are_checked_before_use():
    assert engine.pool._pre_ping is True
