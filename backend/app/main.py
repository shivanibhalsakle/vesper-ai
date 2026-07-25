from fastapi import FastAPI

from app.api.health import router as health_router

app = FastAPI(title="Sunset Discovery API")

app.include_router(health_router)
