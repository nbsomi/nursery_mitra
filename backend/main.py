import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import engine, Base
from app.routers import telemetry, nursery, observations, ota, search

# Ensure the physical database directory exists prior to metadata creation
os.makedirs("backend/database", exist_ok=True)
os.makedirs("backend/releases", exist_ok=True)

# Instantiate the base FastAPI server layout context
app = FastAPI(
    title="Nursery Mitra Backend API",
    description="Core data collection and AI parsing backend.",
    version="1.0.0"
)

# Configure global CORSMiddleware permissions
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    """
    Global Application Bootstrap Layer.
    Automatically generates the SQLite database file and tables on disk if they don't already exist.
    """
    Base.metadata.create_all(bind=engine)

from fastapi.responses import RedirectResponse

@app.get("/api/api/ota/latest", include_in_schema=False)
def legacy_ota_latest_redirect():
    """
    Legacy bridge for versions of the app shipped with the double-api bug.
    """
    return RedirectResponse(url="/api/ota/latest")

@app.get("/api/api/ota/download", include_in_schema=False)
def legacy_ota_download_redirect():
    """
    Legacy bridge for versions of the app shipped with the double-api bug.
    """
    return RedirectResponse(url="/api/ota/download")

# Explicitly register and include all structural sub-routers
app.include_router(telemetry.router)
app.include_router(nursery.router)
app.include_router(observations.router)
app.include_router(ota.router)
app.include_router(search.router)
