import os
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse

router = APIRouter(
    prefix="/api/ota",
    tags=["ota"]
)

# Configuration for OTA
# In a real production system, this could be read from the database or environment variable.
TARGET_APP_VERSION = "1.0.10"
APK_FILENAME = f"nurserymitra_{TARGET_APP_VERSION}.apk"
RELEASES_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "releases"))

@router.get("/latest", status_code=status.HTTP_200_OK)
def check_latest_version():
    """
    Returns the latest available version and the download URL.
    """
    return {
        "version": TARGET_APP_VERSION,
        # Providing a relative path allows the flutter client to dynamically build the URL based on its configured base URL
        "download_url": "/ota/download"
    }

@router.get("/download", response_class=FileResponse)
def download_apk():
    """
    Serves the actual APK file from the releases directory.
    """
    file_path = os.path.join(RELEASES_DIR, APK_FILENAME)
    if not os.path.exists(file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="APK release file not found on the server."
        )
    return FileResponse(
        path=file_path, 
        media_type='application/vnd.android.package-archive', 
        filename=APK_FILENAME
    )
