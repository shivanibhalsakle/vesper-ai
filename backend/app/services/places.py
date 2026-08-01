import json
import math

import httpx

from app.data.curated_locations import CURATED_LOCATIONS
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.services.cache import Cache, RedisCache

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
CACHE_TTL_SECONDS = 60 * 60 * 24 * 30  # 30 days — OSM place tagging changes rarely

# Overpass's public instance rejects requests with a generic/default User-Agent
# (406 Not Acceptable), and its query queue can take longer than httpx's 5s
# default timeout — both were confirmed against the live API during Phase 3.
REQUEST_HEADERS = {"User-Agent": "sunset-discovery-app/0.1 (dev)"}
REQUEST_TIMEOUT_SECONDS = 30.0

# Heuristic OSM tag mapping per place type. Not exhaustive (OSM tagging is
# inconsistent across regions) — the curated fallback list exists precisely
# to cover gaps this mapping misses.
TAG_QUERIES: dict[LocationType, list[tuple[str, str]]] = {
    LocationType.BEACH: [("natural", "beach")],
    LocationType.PARK: [("leisure", "park")],
    LocationType.WATERFRONT: [("natural", "water")],
    LocationType.PROMENADE: [("leisure", "promenade")],
    LocationType.ELEVATED_VIEWPOINT: [("tourism", "viewpoint")],
}


def find_candidate_locations(
    lat: float,
    lon: float,
    radius_km: float,
    place_types: list[LocationType],
    client: httpx.Client | None = None,
    cache: Cache | None = None,
) -> list[LocationRecord]:
    cache = cache if cache is not None else RedisCache()
    cache_key = _cache_key(lat, lon, radius_km, place_types)

    cached = cache.get(cache_key)
    if cached is not None:
        raw_osm = json.loads(cached)
    else:
        try:
            payload = _query_overpass(lat, lon, radius_km, place_types, client)
            raw_osm = _parse_overpass_response(payload, place_types)
            cache.set(cache_key, json.dumps(raw_osm), CACHE_TTL_SECONDS)
        except httpx.HTTPError:
            # Overpass's public instance is flaky (timeouts/5xx under load).
            # Don't cache the failure — fall through with no OSM results so
            # the curated dataset below still has a chance to serve this
            # request, and the next request retries Overpass fresh.
            raw_osm = []

    osm_records = [
        LocationRecord(
            id=entry["id"],
            name=entry["name"],
            type=entry["type"],
            lat=entry["lat"],
            lon=entry["lon"],
            source=LocationSource.OSM,
            distance_km=round(_haversine_km(lat, lon, entry["lat"], entry["lon"]), 2),
        )
        for entry in raw_osm
    ]
    curated_records = _curated_candidates(lat, lon, radius_km, place_types)
    merged = _merge_and_dedupe(osm_records, curated_records)
    merged.sort(key=lambda r: r.distance_km)
    return merged


def _cache_key(lat: float, lon: float, radius_km: float, place_types: list[LocationType]) -> str:
    # Round to ~1.1km grid cells so nearby queries share a cache entry;
    # distance is always recomputed against the real query point below,
    # so this rounding only affects cache hit rate, not accuracy.
    grid_lat = round(lat, 2)
    grid_lon = round(lon, 2)
    types_key = ",".join(sorted(t.value for t in place_types))
    return f"places:{grid_lat}:{grid_lon}:{radius_km}:{types_key}"


def _query_overpass(
    lat: float,
    lon: float,
    radius_km: float,
    place_types: list[LocationType],
    client: httpx.Client | None,
) -> dict:
    owns_client = client is None
    client = client or httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS)
    try:
        query = _build_overpass_query(lat, lon, radius_km, place_types)
        response = client.post(OVERPASS_URL, data={"data": query}, headers=REQUEST_HEADERS)
        response.raise_for_status()
        return response.json()
    finally:
        if owns_client:
            client.close()


def _build_overpass_query(
    lat: float, lon: float, radius_km: float, place_types: list[LocationType]
) -> str:
    radius_m = int(radius_km * 1000)
    clauses = []
    for place_type in place_types:
        for key, value in TAG_QUERIES[place_type]:
            clauses.append(f'node["{key}"="{value}"](around:{radius_m},{lat},{lon});')
            clauses.append(f'way["{key}"="{value}"](around:{radius_m},{lat},{lon});')
    body = "\n  ".join(clauses)
    return f"[out:json][timeout:25];\n(\n  {body}\n);\nout center tags;"


def _parse_overpass_response(payload: dict, place_types: list[LocationType]) -> list[dict]:
    records = []
    for element in payload.get("elements", []):
        tags = element.get("tags", {})
        name = tags.get("name")
        if not name:
            continue

        if element["type"] == "node":
            elat, elon = element.get("lat"), element.get("lon")
        else:
            center = element.get("center")
            if not center:
                continue
            elat, elon = center["lat"], center["lon"]

        location_type = _match_type(tags, place_types)
        if location_type is None:
            continue

        records.append(
            {
                "id": f"osm:{element['type']}/{element['id']}",
                "name": name,
                "type": location_type.value,
                "lat": elat,
                "lon": elon,
            }
        )
    return records


def _match_type(tags: dict, place_types: list[LocationType]) -> LocationType | None:
    for place_type in place_types:
        for key, value in TAG_QUERIES[place_type]:
            if tags.get(key) == value:
                return place_type
    return None


def _curated_candidates(
    lat: float, lon: float, radius_km: float, place_types: list[LocationType]
) -> list[LocationRecord]:
    records = []
    for entry in CURATED_LOCATIONS:
        if entry["type"] not in place_types:
            continue
        distance_km = _haversine_km(lat, lon, entry["lat"], entry["lon"])
        if distance_km > radius_km:
            continue
        records.append(
            LocationRecord(
                id=entry["id"],
                name=entry["name"],
                type=entry["type"],
                lat=entry["lat"],
                lon=entry["lon"],
                source=LocationSource.CURATED,
                distance_km=round(distance_km, 2),
            )
        )
    return records


def _merge_and_dedupe(
    osm_records: list[LocationRecord], curated_records: list[LocationRecord]
) -> list[LocationRecord]:
    seen_names = {r.name.strip().lower() for r in osm_records}
    merged = list(osm_records)
    for record in curated_records:
        key = record.name.strip().lower()
        if key not in seen_names:
            merged.append(record)
            seen_names.add(key)
    return merged


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth_radius_km = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * earth_radius_km * math.asin(math.sqrt(a))
