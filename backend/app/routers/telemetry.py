from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..models.schemas import Nurseries, MasterInventory
from ..api.deps import get_db

router = APIRouter(
    prefix="/api/telemetry",
    tags=["telemetry"]
)

@router.get("", status_code=status.HTTP_200_OK)
def get_telemetry(db: Session = Depends(get_db)):
    try:
        total_nurseries = db.query(Nurseries).count()
        total_plants = db.query(MasterInventory).count()
        
        # Calculate last sync timestamp securely from Nurseries and Inventory
        last_nursery = db.query(func.max(Nurseries.LastVerifiedDate)).scalar()
        last_inventory = db.query(func.max(MasterInventory.LastVerifiedTimestamp)).scalar()
        
        last_sync = None
        if last_nursery and last_inventory:
            last_sync = max(last_nursery, last_inventory)
        elif last_nursery:
            last_sync = last_nursery
        elif last_inventory:
            last_sync = last_inventory
            
        return {
            "totalNurseries": total_nurseries,
            "totalPlants": total_plants,
            "lastSyncTimestamp": last_sync.isoformat() if last_sync else "Never"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to compute system telemetry: {str(e)}"
        )
