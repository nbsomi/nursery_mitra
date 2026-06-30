import os
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session
from ..models.schemas import Nurseries
from ..api.deps import get_db

router = APIRouter(
    prefix="/api/nursery",
    tags=["nursery"]
)

class NurseryCreateRequest(BaseModel):
    name: str
    latitude: float
    longitude: float
    phone: Optional[str] = None

@router.post("/create-manual", status_code=status.HTTP_201_CREATED)
def create_manual_nursery(nursery_req: NurseryCreateRequest, db: Session = Depends(get_db)):
    try:
        new_id = str(uuid.uuid4())
        nursery = Nurseries(
            NurseryID=new_id,
            Name=nursery_req.name,
            Latitude=nursery_req.latitude,
            Longitude=nursery_req.longitude,
            Phone=nursery_req.phone
        )
        db.add(nursery)
        db.commit()
        db.refresh(nursery)
        
        return {
            "nurseryId": nursery.NurseryID,
            "name": nursery.Name,
            "latitude": nursery.Latitude,
            "longitude": nursery.Longitude,
            "address": nursery.Address,
            "phone": nursery.Phone,
            "firstSeenDate": nursery.FirstSeenDate.isoformat() if nursery.FirstSeenDate else None,
            "lastVerifiedDate": nursery.LastVerifiedDate.isoformat() if nursery.LastVerifiedDate else None
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to instantiate manual nursery profile: {str(e)}"
        )

@router.post("/upload-signboard", status_code=status.HTTP_201_CREATED)
async def upload_signboard(file: UploadFile = File(...), db: Session = Depends(get_db)):
    try:
        # Define and prepare raw image storage path
        save_directory = "backend/images/signboards"
        os.makedirs(save_directory, exist_ok=True)
        
        file_id = str(uuid.uuid4())
        file_extension = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
        file_path = os.path.join(save_directory, f"{file_id}{file_extension}")
        
        # Write bytes synchronously to block correctly
        with open(file_path, "wb") as buffer:
            buffer.write(await file.read())
            
        # Instantiate placeholder mock profile (Will integrate AI logic here in Module 4)
        nursery_id = str(uuid.uuid4())
        nursery = Nurseries(
            NurseryID=nursery_id,
            Name=f"Mock Nursery Profile {nursery_id[:6]}",
            Latitude=0.0,
            Longitude=0.0,
            Address="Signboard Image Stored, Awaiting AI Extraction"
        )
        db.add(nursery)
        db.commit()
        db.refresh(nursery)
        
        return {
            "nurseryId": nursery.NurseryID,
            "name": nursery.Name,
            "latitude": nursery.Latitude,
            "longitude": nursery.Longitude,
            "address": nursery.Address,
            "phone": nursery.Phone,
            "firstSeenDate": nursery.FirstSeenDate.isoformat() if nursery.FirstSeenDate else None,
            "lastVerifiedDate": nursery.LastVerifiedDate.isoformat() if nursery.LastVerifiedDate else None,
            "signboard_path": file_path
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process multipart signboard stream: {str(e)}"
        )
