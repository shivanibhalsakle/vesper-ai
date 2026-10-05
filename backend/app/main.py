from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.best_date import router as best_date_router
from app.api.feedback import router as feedback_router
from app.api.geocode import router as geocode_router
from app.api.health import router as health_router
from app.api.internal import router as internal_router
from app.api.me import router as me_router
from app.api.places import router as places_router
from app.api.saved_profiles import router as saved_profiles_router
from app.api.session import router as session_router
from app.api.sky import router as sky_router
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
app.include_router(internal_router)
app.include_router(session_router)
app.include_router(simulation_router)
app.include_router(feedback_router)
app.include_router(saved_profiles_router)
app.include_router(trip_window_router)
app.include_router(geocode_router)
app.include_router(places_router)
app.include_router(sky_router)
app.include_router(best_date_router)
app.include_router(me_router)
