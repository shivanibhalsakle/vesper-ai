from fastapi import APIRouter

from app.schemas.simulation import SimulationRequest, SimulationResponse
from app.services.simulation import generate_simulation

router = APIRouter(tags=["simulation"])


@router.post("/simulate", response_model=SimulationResponse)
def create_simulation(request: SimulationRequest) -> SimulationResponse:
    return generate_simulation(request)
