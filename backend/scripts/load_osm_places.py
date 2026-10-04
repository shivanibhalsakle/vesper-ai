"""Bulk-load named OpenStreetMap places into the osm_places table.

Downloads one Geofabrik regional extract at a time, pulls out the parks,
beaches, viewpoints, etc. the app recommends, upserts them, then deletes the
download. Each finished region is recorded, so an interrupted run resumes.

Run from backend/, inside the container so dependencies match production:

  docker compose run --rm backend sh -c "pip install -q --target /tmp/deps -r requirements-data.txt \
      && PYTHONPATH=/tmp/deps python -m scripts.load_osm_places --region new-york"

  ... --all-us                      every US state + DC + Puerto Rico
  ... --pbf some.osm.pbf --region x use an already-downloaded file
  -e DATABASE_URL=postgresql://...  load into another database (e.g. Neon)
"""

import argparse
import sys
import tempfile
import time
from collections.abc import Iterator
from pathlib import Path

import httpx
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings
from app.services.osm_loader import (
    BATCH_SIZE,
    database_size_mb,
    mask_for_tags,
    record_region,
    region_loaded,
    upsert_places,
)
from app.services.places import TAG_QUERIES

GEOFABRIK_US_URL = "https://download.geofabrik.de/north-america/us/{region}-latest.osm.pbf"

US_REGIONS = [
    "alabama", "alaska", "arizona", "arkansas", "california", "colorado",
    "connecticut", "delaware", "district-of-columbia", "florida", "georgia",
    "hawaii", "idaho", "illinois", "indiana", "iowa", "kansas", "kentucky",
    "louisiana", "maine", "maryland", "massachusetts", "michigan", "minnesota",
    "mississippi", "missouri", "montana", "nebraska", "nevada", "new-hampshire",
    "new-jersey", "new-mexico", "new-york", "north-carolina", "north-dakota",
    "ohio", "oklahoma", "oregon", "pennsylvania", "puerto-rico", "rhode-island",
    "south-carolina", "south-dakota", "tennessee", "texas", "utah", "vermont",
    "virginia", "washington", "west-virginia", "wisconsin", "wyoming",
]  # fmt: skip


def download(region: str, work_dir: Path) -> Path:
    url = GEOFABRIK_US_URL.format(region=region)
    destination = work_dir / f"{region}.osm.pbf"
    for attempt in range(1, 6):
        try:
            have = destination.stat().st_size if destination.exists() else 0
            headers = {"Range": f"bytes={have}-"} if have else {}
            with httpx.stream(
                "GET", url, headers=headers, follow_redirects=True, timeout=60
            ) as response:
                if response.status_code == 416:  # nothing left to fetch
                    return destination
                response.raise_for_status()
                mode = "ab" if response.status_code == 206 else "wb"
                written = have if mode == "ab" else 0
                started, next_report = time.monotonic(), written + 50 * 1024 * 1024
                with destination.open(mode) as out:
                    for chunk in response.iter_bytes(1024 * 1024):
                        out.write(chunk)
                        written += len(chunk)
                        if written >= next_report:
                            rate = (written - have) / max(time.monotonic() - started, 1) / 1e6
                            print(f"  downloaded {written / 1e6:,.0f} MB ({rate:.1f} MB/s)", flush=True)
                            next_report += 50 * 1024 * 1024
            return destination
        except (httpx.HTTPError, OSError) as exc:
            print(f"  download attempt {attempt}/5 failed: {exc}", flush=True)
            time.sleep(5 * attempt)
    raise RuntimeError(f"Could not download {url}")


def extract_rows(pbf_path: Path) -> Iterator[dict]:
    import osmium  # only this script needs it, not the API

    # Order matters: locations first, so node coordinates are recorded for
    # every node (including the unnamed ones that make up ways); then areas,
    # restricted to relations carrying a tag we care about so we don't
    # assemble every building multipolygon in the state; the name filter last
    # so it applies to ways, nodes and assembled areas alike.
    wanted_tags = [pair for pairs in TAG_QUERIES.values() for pair in pairs]
    processor = (
        osmium.FileProcessor(str(pbf_path), osmium.osm.NODE | osmium.osm.WAY | osmium.osm.AREA)
        .with_locations()
        .with_areas(osmium.filter.TagFilter(*wanted_tags))
        .with_filter(osmium.filter.KeyFilter("name"))
    )
    for obj in processor:
        # Closed ways also arrive as areas; they're already handled as ways.
        if obj.is_area() and obj.from_way():
            continue

        mask = mask_for_tags(obj.tags)
        if not mask:
            continue

        if obj.is_node():
            if not obj.location.valid():
                continue
            kind, osm_id = "node", obj.id
            lat, lon = obj.location.lat, obj.location.lon
        else:
            if obj.is_area():  # a multipolygon relation: big or complex parks, lakes
                kind, osm_id = "relation", obj.orig_id()
                nodes = (node for ring in obj.outer_rings() for node in ring)
            else:
                kind, osm_id = "way", obj.id
                nodes = obj.nodes
            lats, lons = [], []
            for node in nodes:
                if node.location.valid():
                    lats.append(node.location.lat)
                    lons.append(node.location.lon)
            if not lats:
                continue
            # Bounding-box centre, matching what Overpass's `out center` returns.
            lat = (min(lats) + max(lats)) / 2
            lon = (min(lons) + max(lons)) / 2

        yield {
            "id": f"osm:{kind}/{osm_id}",
            "name": obj.tags.get("name"),
            "type_mask": mask,
            "lat": lat,
            "lon": lon,
        }


def load_region(session_factory, region: str, pbf_path: Path) -> int:
    total, batch = 0, []
    for row in extract_rows(pbf_path):
        batch.append(row)
        if len(batch) >= BATCH_SIZE:
            with session_factory() as session:
                upsert_places(session, batch)
            total += len(batch)
            batch = []
            print(f"  {total:,} places loaded", flush=True)
    if batch:
        with session_factory() as session:
            upsert_places(session, batch)
        total += len(batch)
    with session_factory() as session:
        record_region(session, region, total)
    return total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--region", nargs="+", default=[], help="Geofabrik US region slug(s)")
    parser.add_argument("--all-us", action="store_true", help="load every US region")
    parser.add_argument("--pbf", type=Path, help="use a local .osm.pbf instead of downloading")
    parser.add_argument("--force", action="store_true", help="reload regions already loaded")
    parser.add_argument("--keep-download", action="store_true", help="don't delete the .pbf afterwards")
    parser.add_argument("--work-dir", type=Path, help="where to put downloads (default: temp dir)")
    parser.add_argument(
        "--max-db-mb",
        type=float,
        default=400,
        help="stop before loading another region once the database reaches this size "
        "(Neon's free tier caps at 512 MB)",
    )
    args = parser.parse_args(argv)

    regions = US_REGIONS if args.all_us else args.region
    if not regions:
        parser.error("give --region <slug ...> or --all-us")
    if args.pbf and len(regions) != 1:
        parser.error("--pbf needs exactly one --region name to record it under")

    engine = create_engine(get_settings().database_url, pool_pre_ping=True)
    session_factory = sessionmaker(bind=engine)
    work_dir = args.work_dir or Path(tempfile.mkdtemp(prefix="osm-load-"))
    work_dir.mkdir(parents=True, exist_ok=True)

    failures = []
    for region in regions:
        with session_factory() as session:
            if not args.force and region_loaded(session, region):
                print(f"[{region}] already loaded, skipping", flush=True)
                continue
            size_mb = database_size_mb(session)
        if size_mb >= args.max_db_mb:
            print(f"Database is {size_mb:,.0f} MB (limit {args.max_db_mb:,.0f}). Stopping before {region}.")
            failures.append(region)
            break

        print(f"[{region}] database is {size_mb:,.0f} MB", flush=True)
        started = time.monotonic()
        try:
            pbf_path = args.pbf or download(region, work_dir)
            total = load_region(session_factory, region, pbf_path)
        except Exception as exc:  # keep going; one bad region shouldn't lose the rest
            print(f"[{region}] FAILED: {exc}", flush=True)
            failures.append(region)
            continue
        finally:
            if not args.pbf and not args.keep_download:
                (work_dir / f"{region}.osm.pbf").unlink(missing_ok=True)
        print(f"[{region}] done: {total:,} places in {time.monotonic() - started:,.0f}s", flush=True)

    with session_factory() as session:
        print(f"Finished. Database size: {database_size_mb(session):,.0f} MB")
    if failures:
        print("Not loaded:", ", ".join(failures))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
