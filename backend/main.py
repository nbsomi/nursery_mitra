import os
import asyncio
import subprocess
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.database import engine, Base
from app.routers import telemetry, nursery, observations, ota, search, ml

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

# Expose static images
app.mount("/api/images", StaticFiles(directory="backend/images"), name="images")

@app.on_event("startup")
async def startup_event():
    """
    Global Application Bootstrap Layer.
    Automatically generates the SQLite database file and tables on disk if they don't already exist.
    """
    Base.metadata.create_all(bind=engine)
    
    # Start the FIFO background ML worker
    from app.core.worker import process_queue
    asyncio.create_task(process_queue())

    # Start Cloudflare Tunnel automatically
    global cloudflared_process
    try:
        os.makedirs("backend/logs", exist_ok=True)
        # Using line-buffered output
        log_file = open("backend/logs/cloudflared.log", "a", buffering=1)
        cloudflared_process = subprocess.Popen(
            ["cloudflared", "tunnel", "run", "--url", "http://localhost:8000", "nursery-mitra-backend"],
            stdout=log_file,
            stderr=subprocess.STDOUT
        )
        print("Cloudflare tunnel background process started via FastAPI.")
    except Exception as e:
        print(f"Failed to start Cloudflare tunnel: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    global cloudflared_process
    if 'cloudflared_process' in globals() and cloudflared_process:
        cloudflared_process.terminate()
        print("Cloudflare tunnel background process terminated.")

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
app.include_router(ml.router)
