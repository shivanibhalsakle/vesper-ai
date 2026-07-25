from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.session import router as session_router

app = FastAPI(title="Sunset Discovery API")

app.include_router(health_router)
app.include_router(session_router)
