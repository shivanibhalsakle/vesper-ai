from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.feedback import router as feedback_router
from app.api.health import router as health_router
from app.api.saved_profiles import router as saved_profiles_router
from app.api.session import router as session_router
from app.api.simulation import router as simulation_router
from app.api.trip_window import router as trip_window_router
from app.core.config import get_settings

app = FastAPI(title="Vesper API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().allowed_origins.split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(session_router)
app.include_router(simulation_router)
app.include_router(feedback_router)
app.include_router(saved_profiles_router)
app.include_router(trip_window_router)
