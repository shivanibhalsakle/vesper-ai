from app.schemas.location import LocationType

# Manual fallback for regions where OSM tagging is sparse or inconsistent.
# Start small (NYC, our test region) and grow as new regions are onboarded.
CURATED_LOCATIONS: list[dict] = [
    {
        "id": "curated:brooklyn-heights-promenade",
        "name": "Brooklyn Heights Promenade",
        "type": LocationType.PROMENADE,
        "lat": 40.6963,
        "lon": -73.9967,
    },
    {
        "id": "curated:top-of-the-rock",
        "name": "Top of the Rock",
        "type": LocationType.ELEVATED_VIEWPOINT,
        "lat": 40.7590,
        "lon": -73.9787,
    },
    {
        "id": "curated:coney-island-beach",
        "name": "Coney Island Beach",
        "type": LocationType.BEACH,
        "lat": 40.5755,
        "lon": -73.9707,
    },
    {
        "id": "curated:central-park-great-lawn",
        "name": "Central Park Great Lawn",
        "type": LocationType.PARK,
        "lat": 40.7813,
        "lon": -73.9646,
    },
    {
        "id": "curated:brooklyn-bridge-park",
        "name": "Brooklyn Bridge Park",
        "type": LocationType.WATERFRONT,
        "lat": 40.7003,
        "lon": -73.9967,
    },
]
