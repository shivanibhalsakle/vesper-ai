from pydantic import BaseModel


class GeocodeResult(BaseModel):
    label: str
    lat: float
    lon: float
