"""Approximate bounding boxes for the Geofabrik US regions the loader knows.

Used only to answer "is this point inside an area we've loaded?", so the
boxes are deliberately simple (south, west, north, east) rather than exact
borders. Neighbouring states overlap a little at the edges; that just means a
search right on a border may be treated as covered when only one side is.
"""

# slug -> (south, west, north, east); slugs match scripts/load_osm_places.py
REGION_BOUNDS: dict[str, tuple[float, float, float, float]] = {
    "alabama": (30.14, -88.48, 35.01, -84.89),
    "alaska": (51.2, -179.2, 71.5, -129.9),
    "arizona": (31.33, -114.82, 37.0, -109.04),
    "arkansas": (33.0, -94.62, 36.5, -89.64),
    "california": (32.5, -124.48, 42.01, -114.13),
    "colorado": (36.99, -109.06, 41.0, -102.04),
    "connecticut": (40.98, -73.73, 42.05, -71.79),
    "delaware": (38.45, -75.79, 39.84, -75.05),
    "district-of-columbia": (38.79, -77.12, 38.995, -76.91),
    "florida": (24.4, -87.64, 31.0, -79.97),
    "georgia": (30.36, -85.61, 35.0, -80.84),
    "hawaii": (18.9, -160.25, 22.24, -154.8),
    "idaho": (41.99, -117.24, 49.0, -111.04),
    "illinois": (36.97, -91.51, 42.51, -87.02),
    "indiana": (37.77, -88.1, 41.76, -84.78),
    "iowa": (40.38, -96.64, 43.5, -90.14),
    "kansas": (36.99, -102.05, 40.0, -94.59),
    "kentucky": (36.5, -89.57, 39.15, -81.96),
    "louisiana": (28.93, -94.04, 33.02, -88.82),
    "maine": (43.06, -71.08, 47.46, -66.95),
    "maryland": (37.91, -79.49, 39.72, -75.05),
    "massachusetts": (41.24, -73.51, 42.89, -69.93),
    "michigan": (41.7, -90.42, 48.31, -82.12),
    "minnesota": (43.5, -97.24, 49.38, -89.49),
    "mississippi": (30.17, -91.66, 35.0, -88.1),
    "missouri": (35.99, -95.77, 40.61, -89.1),
    "montana": (44.36, -116.05, 49.0, -104.04),
    "nebraska": (40.0, -104.05, 43.0, -95.31),
    "nevada": (35.0, -120.0, 42.0, -114.04),
    "new-hampshire": (42.7, -72.56, 45.31, -70.7),
    "new-jersey": (38.93, -75.56, 41.36, -73.89),
    "new-mexico": (31.33, -109.05, 37.0, -103.0),
    "new-york": (40.49, -79.77, 45.02, -71.85),
    "north-carolina": (33.84, -84.32, 36.59, -75.46),
    "north-dakota": (45.94, -104.05, 49.0, -96.55),
    "ohio": (38.4, -84.82, 41.98, -80.52),
    "oklahoma": (33.62, -103.0, 37.0, -94.43),
    "oregon": (41.99, -124.57, 46.29, -116.46),
    "pennsylvania": (39.72, -80.52, 42.27, -74.69),
    "puerto-rico": (17.88, -67.95, 18.52, -65.22),
    "rhode-island": (41.15, -71.86, 42.02, -71.12),
    "south-carolina": (32.03, -83.35, 35.22, -78.54),
    "south-dakota": (42.48, -104.06, 45.95, -96.44),
    "tennessee": (34.98, -90.31, 36.68, -81.65),
    "texas": (25.84, -106.65, 36.5, -93.51),
    "utah": (36.99, -114.05, 42.0, -109.04),
    "vermont": (42.73, -73.44, 45.02, -71.46),
    "virginia": (36.54, -83.68, 39.47, -75.24),
    "washington": (45.54, -124.85, 49.0, -116.92),
    "west-virginia": (37.2, -82.64, 40.64, -77.72),
    "wisconsin": (42.49, -92.89, 47.31, -86.25),
    "wyoming": (41.0, -111.06, 45.01, -104.05),
}

_DISPLAY_NAMES = {
    "district-of-columbia": "Washington, DC",
}


def region_name(slug: str) -> str:
    return _DISPLAY_NAMES.get(slug) or slug.replace("-", " ").title()
