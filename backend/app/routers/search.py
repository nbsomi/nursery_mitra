from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

from ..api.deps import get_db
from ..models.schemas import Nurseries, MasterInventory

router = APIRouter(
    prefix="/api/search",
    tags=["search"]
)

@router.get("/nursery/{nursery_id}/plants")
def search_plants_in_nursery(nursery_id: str, db: Session = Depends(get_db)):
    """
    Returns all plants associated with a given Nursery ID.
    """
    plants = db.query(MasterInventory).filter(MasterInventory.NurseryID == nursery_id).all()
    
    result = []
    for p in plants:
        result.append({
            "PlantID": p.PlantID,
            "CommonName": p.CommonName,
            "SizingMetric": p.SizingMetric,
            "BagSize": p.BagSize
        })
    return result

@router.get("/plants")
def search_by_plant(name: str = Query(..., description="CommonName to search for"), db: Session = Depends(get_db)):
    """
    Returns all nurseries that carry a specific plant, along with the available sizes at that nursery.
    """
    # Case-insensitive partial match
    results = (
        db.query(Nurseries, MasterInventory)
        .join(MasterInventory, Nurseries.NurseryID == MasterInventory.NurseryID)
        .filter(MasterInventory.CommonName.ilike(f"%{name}%"))
        .all()
    )
    
    # Group results by Nursery
    nursery_map = {}
    for nursery, inventory in results:
        if nursery.NurseryID not in nursery_map:
            nursery_map[nursery.NurseryID] = {
                "NurseryID": nursery.NurseryID,
                "Name": nursery.Name,
                "FarmerName": nursery.FarmerName,
                "plants": []
            }
        
        nursery_map[nursery.NurseryID]["plants"].append({
            "CommonName": inventory.CommonName,
            "SizingMetric": inventory.SizingMetric,
            "BagSize": inventory.BagSize
        })
        
    return list(nursery_map.values())

@router.get("/plant-bag")
def search_by_plant_and_bag_size(
    name: str = Query(..., description="CommonName to search for"),
    bag_size: str = Query(..., description="BagSize to exactly match"),
    db: Session = Depends(get_db)
):
    """
    Returns all nurseries that carry a specific plant at a specific bag size.
    """
    results = (
        db.query(Nurseries, MasterInventory)
        .join(MasterInventory, Nurseries.NurseryID == MasterInventory.NurseryID)
        .filter(MasterInventory.CommonName.ilike(f"%{name}%"))
        .filter(MasterInventory.BagSize == bag_size)
        .all()
    )
    
    nursery_map = {}
    for nursery, inventory in results:
        if nursery.NurseryID not in nursery_map:
            nursery_map[nursery.NurseryID] = {
                "NurseryID": nursery.NurseryID,
                "Name": nursery.Name,
                "FarmerName": nursery.FarmerName,
                "MatchedPlant": inventory.CommonName,
                "MatchedBagSize": inventory.BagSize
            }
            
    return list(nursery_map.values())
