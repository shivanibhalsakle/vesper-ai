from sqlalchemy.exc import OperationalError

from app.models.osm_place import OsmPlace
from app.schemas.location import LocationType
from app.services.place_index import (
    PostgresPlaceIndex,
    mask_to_types,
    types_to_mask,
)

# Mid-Atlantic: no real OSM places here, even once real data is loaded locally.
LAT, LON = 30.0, -40.0


def _add(db_session, place_id, name, types, dlat=0.0, dlon=0.0):
    db_session.add(
        OsmPlace(
            id=place_id,
            name=name,
            type_mask=types_to_mask(types),
            lat=LAT + dlat,
            lon=LON + dlon,
        )
    )


def _index(db_session) -> PostgresPlaceIndex:
    return PostgresPlaceIndex(session_factory=lambda: db_session)


def test_type_mask_round_trips():
    types = [LocationType.PARK, LocationType.ELEVATED_VIEWPOINT]

    assert set(mask_to_types(types_to_mask(types))) == set(types)
    assert types_to_mask([]) == 0


def test_search_returns_nearest_first_with_decoded_types(db_session):
    _add(db_session, "osm:node/test-2", "Farther Park", [LocationType.PARK], dlat=0.04)
    _add(db_session, "osm:node/test-1", "Closer Park", [LocationType.PARK, LocationType.BEACH], dlat=0.01)
    db_session.commit()

    results = _index(db_session).search(LAT, LON, 10.0, [LocationType.PARK])

    assert [r["name"] for r in results] == ["Closer Park", "Farther Park"]
    assert set(results[0]["types"]) == {"park", "beach"}
    assert results[0]["id"] == "osm:node/test-1"


def test_search_filters_by_requested_types(db_session):
    _add(db_session, "osm:node/test-1", "A Park", [LocationType.PARK])
    _add(db_session, "osm:node/test-2", "A Beach", [LocationType.BEACH])
    db_session.commit()

    results = _index(db_session).search(LAT, LON, 10.0, [LocationType.BEACH])

    assert [r["name"] for r in results] == ["A Beach"]


def test_search_excludes_places_outside_the_search_box(db_session):
    _add(db_session, "osm:node/test-1", "Nearby", [LocationType.PARK], dlat=0.02)
    _add(db_session, "osm:node/test-2", "Too Far", [LocationType.PARK], dlat=0.5)  # ~55km
    db_session.commit()

    results = _index(db_session).search(LAT, LON, 10.0, [LocationType.PARK])

    assert [r["name"] for r in results] == ["Nearby"]


def test_search_with_no_matches_returns_empty_list(db_session):
    assert _index(db_session).search(LAT, LON, 10.0, [LocationType.PARK]) == []


def test_database_failure_is_treated_as_no_results():
    class BrokenSession:
        def scalars(self, statement):
            raise OperationalError("SELECT", {}, Exception("db down"))

        def close(self):
            pass

    index = PostgresPlaceIndex(session_factory=BrokenSession)

    assert index.search(LAT, LON, 10.0, [LocationType.PARK]) == []
