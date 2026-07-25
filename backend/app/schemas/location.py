from enum import Enum

from pydantic import BaseModel


class LocationType(str, Enum):
    BEACH = "beach"
    PARK = "park"
    WATERFRONT = "waterfront"
    PROMENADE = "promenade"
    ELEVATED_VIEWPOINT = "elevated_viewpoint"


class LocationSource(str, Enum):
    OSM = "osm"
    CURATED = "curated"


class LocationRecord(BaseModel):
    id: str
    name: str
    type: LocationType
    lat: float
    lon: float
    source: LocationSource
    distance_km: float
