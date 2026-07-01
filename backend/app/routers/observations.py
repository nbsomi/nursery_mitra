import os
import uuid
import json
from typing import Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query, Header
from sqlalchemy.orm import Session

from ..models.schemas import MasterInventory, PendingProcessing, PendingReview
from ..api.deps import get_db

router = APIRouter(
    prefix="/api/observations",
    tags=["observations"]
)

@router.post("/upload", status_code=status.HTTP_201_CREATED)
async def upload_observation(
    # Core requested fields
    nursery_id: Optional[str] = Form(None),
    visit_id: Optional[str] = Form(None),
    remarks: Optional[str] = Form(None),
    auto_approve: bool = Query(False),
    
    # Structural checks for processing mode (header or query)
    processing_mode: Optional[str] = Query(None),
    x_processing_mode: Optional[str] = Header(None, alias="X-Processing-Mode"),
    
    # Fallback mappings for robust compatibility with Dart frontend multipart streams
    payload: Optional[str] = Form(None),
    autoApprove: Optional[str] = Form(None),
    
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # Decode fallback mapping if data was sent via stringified JSON payload
    plant_name = None
    if payload:
        try:
            data = json.loads(payload)
            nursery_id = nursery_id or data.get("nurseryId")
            visit_id = visit_id or data.get("visitId")
            remarks = remarks or data.get("remarks")
            plant_name = data.get("plantName")
        except Exception:
            pass
            
    group_id = None
    if plant_name and '_' in plant_name:
        group_id = plant_name.rsplit('_', 1)[0]
    else:
        group_id = str(uuid.uuid4())
            
    # Normalize auto-approve boolean if passed as a form string
    if autoApprove is not None:
        auto_approve = autoApprove.lower() == 'true'

    if not nursery_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Missing required field: nursery_id"
        )

    # Determine processing mode timing context
    is_later_mode = (processing_mode == "later") or (x_processing_mode == "later")

    try:
        # 1. Image Asset Preservation
        save_directory = "backend/images/plants"
        os.makedirs(save_directory, exist_ok=True)
        
        file_id = plant_name if plant_name else str(uuid.uuid4())
        file_extension = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
        file_path = os.path.join(save_directory, f"{file_id}{file_extension}")
        
        # Stream image bytes synchronously to isolate file I/O safely
        with open(file_path, "wb") as buffer:
            buffer.write(await file.read())
            
        # 2. Path A Logic Evaluation (Processing Timing: Later)
        if is_later_mode:
            queue_id = str(uuid.uuid4())
            pending_proc = PendingProcessing(
                QueueID=queue_id,
                NurseryID=nursery_id,
                GroupId=group_id,
                RawImagePath=file_path,
                Status="Pending"
            )
            db.add(pending_proc)
            db.commit()
            
            return {
                "message": "Observation saved for later processing.", 
                "queue_id": queue_id
            }
            
        # 3. Path B Logic Evaluation (Processing Timing: Immediate)
        # Mock Placeholder: Simulating the AI Parsing Wrapper Engine
        predicted_name = "Mock Extracted Plant (e.g. Mango)"
        predicted_size = 120.5
        predicted_bag = "10x12"
        confidence_score = 0.95
        
        if auto_approve:
            # Sub-Path 1: Auto-Approve Enabled -> Commit straight to Master Ledger
            plant_id = str(uuid.uuid4())
            inventory = MasterInventory(
                PlantID=plant_id,
                NurseryID=nursery_id,
                CommonName=predicted_name,
                SizingMetric=predicted_size,
                BagSize=predicted_bag
            )
            db.add(inventory)
            db.commit()
            
            return {
                "message": "Observation finalized and integrated successfully.", 
                "plant_id": plant_id
            }
        else:
            # Sub-Path 2: Auto-Approve Disabled -> Write to PendingReview
            review_id = str(uuid.uuid4())
            review = PendingReview(
                ReviewID=review_id,
                NurseryID=nursery_id,
                ImagePath=file_path,
                ExtractedName=predicted_name,
                ExtractedSize=str(predicted_size),
                ExtractedBagSize=predicted_bag,
                Confidence=confidence_score,
                Status="Pending"
            )
            db.add(review)
            db.commit()
            db.refresh(review)
            
            # Return mapping structured explicitly for the dart ReviewScreen parser
            return {
                "reviewId": review.ReviewID,
                "nurseryId": review.NurseryID,
                "extractedPlantName": review.ExtractedName,
                "extractedSize": review.ExtractedSize,
                "extractedBagSize": review.ExtractedBagSize,
                "confidenceScore": review.Confidence
            }
            
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred while processing the observation: {str(e)}"
        )


@router.get("/pending-reviews")
def get_pending_reviews(
    nursery_id: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    """
    Returns a list of all PendingReview items waiting for manual confirmation.
    """
    query = db.query(PendingReview).filter(PendingReview.Status == "Pending")
    if nursery_id:
        query = query.filter(PendingReview.NurseryID == nursery_id)
        
    reviews = query.all()
    
    # We must construct relative URLs for the static files
    # The image path in DB is "backend/images/plants/xyz.jpg"
    # We want to serve it as "/images/plants/xyz.jpg"
    results = []
    for r in reviews:
        image_url = ""
        if r.ImagePath:
            image_url = "/api/" + r.ImagePath.split("backend/", 1)[-1] if "backend/" in r.ImagePath else r.ImagePath
            
        results.append({
            "reviewId": r.ReviewID,
            "nurseryId": r.NurseryID,
            "extractedPlantName": r.ExtractedName or "",
            "extractedBagSize": r.ExtractedBagSize or "",
            "confidence": r.Confidence or 0.0,
            "imageUrl": image_url
        })
        
    return {"reviews": results}

class ConfirmReviewRequest(BaseModel):
    reviewId: str
    plantName: str
    bagSize: str

@router.post("/confirm-review")
def confirm_review(
    request: ConfirmReviewRequest,
    db: Session = Depends(get_db)
):
    review = db.query(PendingReview).filter(PendingReview.ReviewID == request.reviewId).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    
    review.Status = "Committed"
    
    sizing_metric = 0.0

    plant_id = str(uuid.uuid4())
    inventory = MasterInventory(
        PlantID=plant_id,
        NurseryID=review.NurseryID,
        CommonName=request.plantName,
        SizingMetric=sizing_metric,
        BagSize=request.bagSize
    )
    db.add(inventory)
    db.commit()
    
    return {"message": "Review confirmed successfully", "plant_id": plant_id}
