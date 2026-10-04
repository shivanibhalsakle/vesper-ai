import json
import logging
import math
import random
import time
from datetime import datetime, timedelta, timezone

import httpx
import redis

from app.core.config import get_settings
from app.data.curated_locations import CURATED_LOCATIONS
from app.schemas.location import LocationRecord, LocationSource, LocationType
from app.services.cache import Cache, RedisCache
from app.services.place_index import PlaceIndex, PostgresPlaceIndex
from app.services.place_store import PlaceStore, PostgresPlaceStore

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 60 * 60 * 24 * 30  # 30 days — OSM place tagging changes rarely

# Overpass's public instances reject generic/default User-Agents (406) and ask
# clients to identify themselves.
REQUEST_HEADERS = {"User-Agent": "vesper-app/1.0 (+https://vesper.shivanibhalsakle.com)"}
REQUEST_TIMEOUT_SECONDS = 15.0
OVERPASS_QUERY_TIMEOUT_SECONDS = 15
MAX_ATTEMPTS = 3  # rotates through the configured mirrors
RETRY_BACKOFF_SECONDS = 0.5

# Searches are cached per ~1km map cell and radius bucket, always for ALL place
# types, then filtered per request — so "park only" and "everything" share one
# cache entry and one Overpass call. The fetch radius gets a margin so a user
# anywhere inside the cell is fully covered out to the bucket radius.
RADIUS_BUCKETS_KM = [5, 10, 25, 50, 100]
CELL_MARGIN_KM = 1.0

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


class PlaceDataUnavailable(Exception):
    """Place data couldn't be loaded (Overpass down, nothing stored or curated)
    — distinct from a search that genuinely found nothing.
    """


class _OverpassRuntimeError(Exception):
    """Overpass answered HTTP 200 but with an error remark instead of data."""


def find_candidate_locations(
    lat: float,
    lon: float,
    radius_km: float,
    place_types: list[LocationType],
    client: httpx.Client | None = None,
    cache: Cache | None = None,
    store: PlaceStore | None = None,
    index: PlaceIndex | None = None,
) -> list[LocationRecord]:
    # Our own loaded OSM data comes first: it's fast and doesn't depend on a
    # public service being up. Overpass below only covers areas we haven't loaded.
    index = index if index is not None else PostgresPlaceIndex()
    indexed = _osm_records(
        index.search(lat, lon, radius_km, place_types), lat, lon, radius_km, place_types
    )
    if indexed:
        return _with_curated(indexed, lat, lon, radius_km, place_types)

    cache = cache if cache is not None else RedisCache()
    store = store if store is not None else PostgresPlaceStore()

    try:
        raw_osm = _load_osm_places(lat, lon, radius_km, client, cache, store)
    except PlaceDataUnavailable:
        curated = _curated_candidates(lat, lon, radius_km, place_types)
        if not curated:
            raise
        logger.warning("Overpass unavailable; serving %d curated locations only", len(curated))
        curated.sort(key=lambda r: r.distance_km)
        return curated

    osm_records = _osm_records(raw_osm, lat, lon, radius_km, place_types)
    return _with_curated(osm_records, lat, lon, radius_km, place_types)


def _with_curated(
    osm_records: list[LocationRecord],
    lat: float,
    lon: float,
    radius_km: float,
    place_types: list[LocationType],
) -> list[LocationRecord]:
    curated_records = _curated_candidates(lat, lon, radius_km, place_types)
    merged = _merge_and_dedupe(osm_records, curated_records)
    merged.sort(key=lambda r: r.distance_km)
    return merged


def _load_osm_places(
    lat: float,
    lon: float,
    radius_km: float,
    client: httpx.Client | None,
    cache: Cache,
    store: PlaceStore,
) -> list[dict]:
    """Redis -> Postgres -> Overpass, falling back to an expired Postgres
    entry (stale-if-error) when Overpass is down.
    """
    key = _cache_key(lat, lon, radius_km)

    cached = _cache_get(cache, key)
    if cached is not None:
        return json.loads(cached)

    stored = store.get(key)
    if stored is not None and _is_fresh(stored.fetched_at):
        _cache_set(cache, key, json.dumps(stored.payload))
        return stored.payload

    try:
        payload = _query_overpass(
            round(lat, 2), round(lon, 2), _radius_bucket(radius_km) + CELL_MARGIN_KM, client
        )
    except PlaceDataUnavailable:
        if stored is not None:
            logger.warning("Overpass unavailable; serving expired stored places for %s", key)
            return stored.payload
        raise

    raw_osm = _parse_overpass_response(payload)
    store.set(key, raw_osm)
    _cache_set(cache, key, json.dumps(raw_osm))
    return raw_osm


def _is_fresh(fetched_at: datetime) -> bool:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    return now - fetched_at < timedelta(seconds=CACHE_TTL_SECONDS)


def _cache_get(cache: Cache, key: str) -> str | None:
    # Render's free Redis can restart at any time — a cache outage should cost
    # a cache miss, not fail the search.
    try:
        return cache.get(key)
    except redis.RedisError:
        logger.warning("Place cache read failed", exc_info=True)
        return None


def _cache_set(cache: Cache, key: str, value: str) -> None:
    try:
        cache.set(key, value, CACHE_TTL_SECONDS)
    except redis.RedisError:
        logger.warning("Place cache write failed", exc_info=True)


def _radius_bucket(radius_km: float) -> int:
    for bucket in RADIUS_BUCKETS_KM:
        if radius_km <= bucket:
            return bucket
    return RADIUS_BUCKETS_KM[-1]


def _cache_key(lat: float, lon: float, radius_km: float) -> str:
    # Round to ~1.1km grid cells so nearby queries share a cache entry;
    # distance is always recomputed against the real query point later, so
    # this rounding only affects hit rate, not accuracy.
    return f"places:v2:{round(lat, 2)}:{round(lon, 2)}:{_radius_bucket(radius_km)}"


def _overpass_urls() -> list[str]:
    return [u.strip() for u in get_settings().overpass_urls.split(",") if u.strip()]


def _query_overpass(
    lat: float, lon: float, radius_km: float, client: httpx.Client | None
) -> dict:
    query = _build_overpass_query(lat, lon, radius_km)
    urls = _overpass_urls()
    owns_client = client is None
    client = client or httpx.Client(timeout=REQUEST_TIMEOUT_SECONDS)
    last_error: Exception | None = None
    try:
        for attempt in range(MAX_ATTEMPTS):
            url = urls[attempt % len(urls)]
            try:
                return _post_query(client, url, query)
            except (httpx.HTTPError, ValueError, _OverpassRuntimeError) as exc:
                last_error = exc
                logger.warning(
                    "Overpass attempt %d/%d via %s failed: %s",
                    attempt + 1,
                    MAX_ATTEMPTS,
                    url,
                    exc,
                )
                if attempt < MAX_ATTEMPTS - 1:
                    time.sleep(RETRY_BACKOFF_SECONDS * (2**attempt) + random.uniform(0, 0.25))
    finally:
        if owns_client:
            client.close()
    raise PlaceDataUnavailable("All Overpass attempts failed") from last_error


def _post_query(client: httpx.Client, url: str, query: str) -> dict:
    response = client.post(url, data={"data": query}, headers=REQUEST_HEADERS)
    response.raise_for_status()
    payload = response.json()  # ValueError if Overpass sent an HTML error page
    if not isinstance(payload, dict):
        raise ValueError("unexpected Overpass response shape")
    # Overpass reports query timeouts/overload as HTTP 200 with a remark and
    # no elements — that must never be mistaken for "no places here".
    remark = str(payload.get("remark", ""))
    if "runtime error" in remark.lower():
        raise _OverpassRuntimeError(remark)
    return payload


def _build_overpass_query(lat: float, lon: float, radius_km: float) -> str:
    radius_m = int(radius_km * 1000)
    clauses = []
    for tag_pairs in TAG_QUERIES.values():
        for key, value in tag_pairs:
            # ["name"] keeps the response small — unnamed places are discarded anyway.
            clauses.append(f'node["{key}"="{value}"]["name"](around:{radius_m},{lat},{lon});')
            clauses.append(f'way["{key}"="{value}"]["name"](around:{radius_m},{lat},{lon});')
    body = "\n  ".join(clauses)
    return f"[out:json][timeout:{OVERPASS_QUERY_TIMEOUT_SECONDS}];\n(\n  {body}\n);\nout center tags;"


def _parse_overpass_response(payload: dict) -> list[dict]:
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

        types = _matching_types(tags)
        if not types:
            continue

        records.append(
            {
                "id": f"osm:{element['type']}/{element['id']}",
                "name": name,
                "types": [t.value for t in types],
                "lat": elat,
                "lon": elon,
            }
        )
    return records


def _matching_types(tags: dict) -> list[LocationType]:
    return [
        place_type
        for place_type, tag_pairs in TAG_QUERIES.items()
        if any(tags.get(key) == value for key, value in tag_pairs)
    ]


def _osm_records(
    raw_osm: list[dict],
    lat: float,
    lon: float,
    radius_km: float,
    place_types: list[LocationType],
) -> list[LocationRecord]:
    requested = set(place_types)
    records = []
    for entry in raw_osm:
        matched = [LocationType(t) for t in entry["types"] if LocationType(t) in requested]
        if not matched:
            continue
        distance_km = _haversine_km(lat, lon, entry["lat"], entry["lon"])
        if distance_km > radius_km:
            continue
        records.append(
            LocationRecord(
                id=entry["id"],
                name=entry["name"],
                type=matched[0],
                lat=entry["lat"],
                lon=entry["lon"],
                source=LocationSource.OSM,
                distance_km=round(distance_km, 2),
            )
        )
    return records


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
