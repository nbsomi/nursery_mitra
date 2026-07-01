import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from ..models.schemas import PendingReview, ExpertFeedback
from ..api.deps import get_db
from ..services.ml_service import ml_service
from ..services.vector_service import vector_service

router = APIRouter(
    prefix="/api/ml",
    tags=["ml"]
)

os.makedirs("backend/dataset", exist_ok=True)

@router.post("/process-image")
async def process_image(
    nursery_id: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Process an uploaded image through the local ML pipeline.
    Saves image, runs inference, and stores in PendingReview.
    """
    file_id = str(uuid.uuid4())
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filepath = f"backend/dataset/{file_id}.{ext}"
    
    try:
        content = await file.read()
        with open(filepath, "wb") as f:
            f.write(content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save image: {e}")

    # Run Inference
    plant_pred = ml_service.predict_plant_species(filepath)
    bag_size_pred = ml_service.estimate_bag_size(filepath)

    # Store prediction for review
    review = PendingReview(
        ReviewID=file_id,
        NurseryID=nursery_id,
        ImagePath=filepath,
        ExtractedName=plant_pred.get("species"),
        ExtractedSize=None, # TBD
        ExtractedBagSize=bag_size_pred,
        Confidence=plant_pred.get("confidence")
    )
    db.add(review)
    db.commit()

    # Vector Search & Storage
    embedding = plant_pred.get("embedding")
    similar_plants = []
    if embedding:
        similar_plants = vector_service.search_similar(embedding, top_k=5)
        # Avoid saving until after we search so we don't just find ourselves,
        # but in production, we filter by ID.
        vector_service.add_embedding(file_id, embedding, nursery_id, plant_pred.get("species"))

    return {
        "review_id": file_id,
        "species": plant_pred.get("species"),
        "confidence": plant_pred.get("confidence"),
        "bag_size": bag_size_pred,
        "similar_plants": similar_plants
    }

from pydantic import BaseModel

class FeedbackRequest(BaseModel):
    review_id: str
    corrected_name: str
    corrected_bag_size: str

@router.post("/feedback")
def submit_feedback(
    feedback: FeedbackRequest,
    db: Session = Depends(get_db)
):
    """
    Accept user correction for a prediction. Moves data into ExpertFeedback.
    """
    # Fetch original review
    review = db.query(PendingReview).filter(PendingReview.ReviewID == feedback.review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review ID not found")
        
    expert = ExpertFeedback(
        FeedbackID=str(uuid.uuid4()),
        OriginalReviewID=review.ReviewID,
        ImagePath=review.ImagePath,
        PredictedName=review.ExtractedName,
        CorrectedName=feedback.corrected_name,
        PredictedBagSize=review.ExtractedBagSize,
        CorrectedBagSize=feedback.corrected_bag_size
    )
    
    db.add(expert)
    
    # Update original review status
    review.Status = "Committed"
    
    db.commit()
    
    return {"status": "success", "message": "Feedback submitted successfully. Thank you for training the model!"}
