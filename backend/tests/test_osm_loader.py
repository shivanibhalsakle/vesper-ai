from app.models.osm_place import OsmPlace
from app.schemas.location import LocationType
from app.services.osm_loader import (
    database_size_mb,
    mask_for_tags,
    record_region,
    region_loaded,
    upsert_places,
)
from app.services.place_index import mask_to_types, types_to_mask


def test_mask_for_tags_maps_osm_tags_to_place_types():
    assert mask_to_types(mask_for_tags({"leisure": "park"})) == [LocationType.PARK]
    assert mask_to_types(mask_for_tags({"natural": "beach"})) == [LocationType.BEACH]
    assert mask_to_types(mask_for_tags({"tourism": "viewpoint"})) == [
        LocationType.ELEVATED_VIEWPOINT
    ]


def test_mask_for_tags_combines_types_and_ignores_unrelated_tags():
    both = mask_for_tags({"leisure": "park", "natural": "water", "name": "X"})

    assert set(mask_to_types(both)) == {LocationType.PARK, LocationType.WATERFRONT}
    assert mask_for_tags({"shop": "convenience"}) == 0


def _row(place_id="osm:node/test-1", name="Test Park", lat=30.0, lon=-40.0):
    return {
        "id": place_id,
        "name": name,
        "type_mask": types_to_mask([LocationType.PARK]),
        "lat": lat,
        "lon": lon,
    }


def test_upsert_inserts_new_rows(db_session):
    upsert_places(db_session, [_row("osm:node/test-1"), _row("osm:way/test-2", name="Other")])

    assert db_session.get(OsmPlace, "osm:node/test-1").name == "Test Park"
    assert db_session.get(OsmPlace, "osm:way/test-2").name == "Other"


def test_upsert_updates_an_existing_row_instead_of_failing(db_session):
    upsert_places(db_session, [_row(name="Old Name", lat=30.0)])
    upsert_places(db_session, [_row(name="New Name", lat=30.5)])

    place = db_session.get(OsmPlace, "osm:node/test-1")
    assert place.name == "New Name"
    assert place.lat == 30.5


def test_upsert_tolerates_a_duplicate_id_within_one_batch(db_session):
    upsert_places(db_session, [_row(name="First"), _row(name="Second")])

    assert db_session.get(OsmPlace, "osm:node/test-1").name == "Second"


def test_region_tracking(db_session):
    assert region_loaded(db_session, "test-region") is False

    record_region(db_session, "test-region", 123)

    assert region_loaded(db_session, "test-region") is True


def test_database_size_is_reported_in_megabytes(db_session):
    assert database_size_mb(db_session) > 0
