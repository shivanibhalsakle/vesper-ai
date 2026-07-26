from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.health import router as health_router
from app.api.session import router as session_router

app = FastAPI(title="Vesper API")

# Dev-only: the Flutter web client runs on a different origin/port than this
# API. Tighten this to specific origins before any production deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(session_router)
