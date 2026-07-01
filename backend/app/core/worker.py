import asyncio
import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from .database import SessionLocal
from ..models.schemas import PendingProcessing, PendingReview
from ..services.ml_service import ml_service
from ..services.vector_service import vector_service

async def process_queue():
    """
    Background worker that polls PendingProcessing for image groups.
    It groups multiple images of the same plant and processes them together.
    """
    print("Background Group-Aware ML worker started.")
    while True:
        try:
            db: Session = SessionLocal()
            
            # Find groups that are still pending
            pending_groups = db.query(PendingProcessing.GroupId).filter(
                PendingProcessing.Status == "Pending"
            ).distinct().all()
            
            processed_something = False
            
            for (group_id,) in pending_groups:
                # GroupId might be None for old items, handle gracefully
                
                items = db.query(PendingProcessing).filter(
                    PendingProcessing.GroupId == group_id,
                    PendingProcessing.Status == "Pending"
                ).all()
                
                if not items:
                    continue
                    
                latest_upload_time = max(item.Timestamp for item in items)
                
                # Handle naive vs aware datetimes for SQLite
                if latest_upload_time.tzinfo:
                    now = datetime.now(timezone.utc)
                else:
                    now = datetime.utcnow()
                
                # If the last image in the batch was uploaded more than 5 seconds ago
                if (now - latest_upload_time).total_seconds() > 5:
                    print(f"ML Worker picked up Batch {group_id} ({len(items)} images) for processing...")
                    
                    best_plant_pred = None
                    best_bag_pred = None
                    best_image_path = None
                    highest_confidence = -1.0
                    nursery_id = items[0].NurseryID
                    
                    # Run inference on all images in the batch
                    for item in items:
                        plant_pred = ml_service.predict_plant_species(item.RawImagePath)
                        bag_size_pred = ml_service.estimate_bag_size(item.RawImagePath)
                        
                        conf = plant_pred.get("confidence", 0.0)
                        if conf > highest_confidence:
                            highest_confidence = conf
                            best_plant_pred = plant_pred
                            best_bag_pred = bag_size_pred
                            best_image_path = item.RawImagePath
                            
                    # Store the single best result
                    if best_plant_pred:
                        review_id = str(uuid.uuid4())
                        review = PendingReview(
                            ReviewID=review_id,
                            NurseryID=nursery_id,
                            ImagePath=best_image_path,  # Store the clearest image
                            ExtractedName=best_plant_pred.get("species"),
                            ExtractedSize=None,
                            ExtractedBagSize=best_bag_pred,
                            Confidence=highest_confidence
                        )
                        db.add(review)
                        
                        # Store the vector embedding of the clearest image
                        embedding = best_plant_pred.get("embedding")
                        if embedding:
                            vector_service.add_embedding(review_id, embedding, nursery_id, best_plant_pred.get("species"))
                    
                    # Mark all raw images in the batch as processed
                    for item in items:
                        item.Status = "Processed"
                        
                    db.commit()
                    processed_something = True
                    print(f"Finished processing batch {group_id}.")
                    
            if not processed_something:
                await asyncio.sleep(5)
            else:
                # Small sleep to prevent CPU hogging during massive batch loads
                await asyncio.sleep(0.5)
                
        except Exception as e:
            print(f"Error in ML worker queue: {e}")
            await asyncio.sleep(5)
        finally:
            db.close()
