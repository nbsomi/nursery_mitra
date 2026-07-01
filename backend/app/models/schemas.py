from sqlalchemy import Column, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..core.database import Base

class Nurseries(Base):
    __tablename__ = "nurseries"

    NurseryID = Column(String, primary_key=True, index=True)
    Name = Column(String, nullable=False)
    FarmerName = Column(String, nullable=True)
    Latitude = Column(Float, nullable=False)
    Longitude = Column(Float, nullable=False)
    Address = Column(String, nullable=True)
    Phone1 = Column(String, nullable=True)
    Phone2 = Column(String, nullable=True)
    FirstSeenDate = Column(DateTime(timezone=True), default=func.now())
    LastVerifiedDate = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

    # Relationships
    inventory = relationship("MasterInventory", back_populates="nursery", cascade="all, delete-orphan")
    pending_processing = relationship("PendingProcessing", back_populates="nursery", cascade="all, delete-orphan")
    pending_reviews = relationship("PendingReview", back_populates="nursery", cascade="all, delete-orphan")

class MasterInventory(Base):
    __tablename__ = "master_inventory"

    PlantID = Column(String, primary_key=True, index=True)
    NurseryID = Column(String, ForeignKey("nurseries.NurseryID"), nullable=False)
    CommonName = Column(String, nullable=False)
    SizingMetric = Column(Float, nullable=False)
    BagSize = Column(String, nullable=False)
    LastVerifiedTimestamp = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

    # Relationships
    nursery = relationship("Nurseries", back_populates="inventory")

class PendingProcessing(Base):
    __tablename__ = "pending_processing"

    QueueID = Column(String, primary_key=True, index=True)
    NurseryID = Column(String, ForeignKey("nurseries.NurseryID"), nullable=False)
    GroupId = Column(String, nullable=True, index=True) # Used to group multiple images of the same plant
    RawImagePath = Column(String, nullable=False)
    Status = Column(String, default="Pending") # 'Pending' or 'Processed'
    Timestamp = Column(DateTime(timezone=True), default=func.now())

    # Relationships
    nursery = relationship("Nurseries", back_populates="pending_processing")

class PendingReview(Base):
    __tablename__ = "pending_review"

    ReviewID = Column(String, primary_key=True, index=True)
    NurseryID = Column(String, ForeignKey("nurseries.NurseryID"), nullable=False)
    ImagePath = Column(String, nullable=False)
    ExtractedName = Column(String, nullable=True)
    ExtractedSize = Column(String, nullable=True)
    ExtractedBagSize = Column(String, nullable=True)
    Confidence = Column(Float, nullable=True)
    Status = Column(String, default="Pending") # 'Pending' or 'Committed'

    # Relationships
    nursery = relationship("Nurseries", back_populates="pending_reviews")

class ExpertFeedback(Base):
    __tablename__ = "expert_feedback"

    FeedbackID = Column(String, primary_key=True, index=True)
    OriginalReviewID = Column(String, nullable=True)
    ImagePath = Column(String, nullable=False)
    PredictedName = Column(String, nullable=True)
    CorrectedName = Column(String, nullable=True)
    PredictedBagSize = Column(String, nullable=True)
    CorrectedBagSize = Column(String, nullable=True)
    Timestamp = Column(DateTime(timezone=True), default=func.now())
