from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import get_current_user_id
from app.db.session import get_db
from app.schemas.simulation import SimulationRequest, SimulationResponse
from app.services.image_limits import ImageLimitExceeded
from app.services.simulation import generate_simulation

router = APIRouter(tags=["simulation"])


@router.post("/simulate", response_model=SimulationResponse)
def create_simulation(
    request: SimulationRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SimulationResponse:
    try:
        return generate_simulation(request, user_id=user_id, db=db)
    except ImageLimitExceeded as exc:
        raise HTTPException(status_code=429, detail=str(exc))
