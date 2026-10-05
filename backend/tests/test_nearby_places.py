from fastapi.testclient import TestClient

import app.api.places as places_api
from app.main import app
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.services.places import PlaceDataUnavailable


def _spot(index: int, type_: LocationType = LocationType.PARK) -> LocationRecord:
    return LocationRecord(
        id=f"osm-{index}",
        name=f"Spot {index}",
        type=type_,
        lat=40.7,
        lon=-73.9,
        source=LocationSource.OSM,
        distance_km=float(index),
    )


def test_returns_spots_nearest_first(client, monkeypatch):
    monkeypatch.setattr(
        places_api, "find_candidate_locations", lambda lat, lon, radius, types: [_spot(1), _spot(2)]
    )

    response = client.get("/places/nearby", params={"lat": 40.7, "lon": -73.9})

    assert response.status_code == 200
    assert [s["name"] for s in response.json()] == ["Spot 1", "Spot 2"]


def test_no_type_filter_means_all_types(client, monkeypatch):
    seen = {}

    def fake(lat, lon, radius, types):
        seen["types"] = types
        return []

    monkeypatch.setattr(places_api, "find_candidate_locations", fake)
    client.get("/places/nearby", params={"lat": 40.7, "lon": -73.9})

    assert set(seen["types"]) == set(LocationType)


def test_type_filter_and_radius_are_passed_through(client, monkeypatch):
    seen = {}

    def fake(lat, lon, radius, types):
        seen.update(radius=radius, types=types)
        return []

    monkeypatch.setattr(places_api, "find_candidate_locations", fake)
    client.get(
        "/places/nearby",
        params={"lat": 40.7, "lon": -73.9, "radius_km": 25, "place_types": ["beach", "park"]},
    )

    assert seen["radius"] == 25
    assert seen["types"] == [LocationType.BEACH, LocationType.PARK]


def test_results_are_capped(client, monkeypatch):
    monkeypatch.setattr(
        places_api,
        "find_candidate_locations",
        lambda *args: [_spot(i) for i in range(places_api.MAX_SPOTS + 20)],
    )

    response = client.get("/places/nearby", params={"lat": 40.7, "lon": -73.9})

    assert len(response.json()) == places_api.MAX_SPOTS


def test_place_data_outage_is_a_503(client, monkeypatch):
    def boom(*args):
        raise PlaceDataUnavailable("down")

    monkeypatch.setattr(places_api, "find_candidate_locations", boom)

    response = client.get("/places/nearby", params={"lat": 40.7, "lon": -73.9})

    assert response.status_code == 503


def test_rejects_invalid_coordinates_and_radius(client):
    assert client.get("/places/nearby", params={"lat": 100, "lon": 0}).status_code == 422
    assert (
        client.get("/places/nearby", params={"lat": 0, "lon": 0, "radius_km": 500}).status_code
        == 422
    )


def test_requires_authentication():
    response = TestClient(app).get("/places/nearby", params={"lat": 40.7, "lon": -73.9})

    assert response.status_code == 401
