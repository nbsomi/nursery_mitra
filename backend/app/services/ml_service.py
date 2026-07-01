import os
import torch
from PIL import Image
from transformers import AutoImageProcessor, AutoModelForImageClassification

class MLService:
    def __init__(self):
        # Using a model specifically fine-tuned on plant species that is open and ungated
        self.model_name = 'umutbozdag/plant-identity'
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        print(f"Initializing ML Service on {self.device}...")
        
        try:
            self.processor = AutoImageProcessor.from_pretrained(self.model_name)
            self.model = AutoModelForImageClassification.from_pretrained(self.model_name).to(self.device)
            print("ML Models loaded successfully.")
        except Exception as e:
            print(f"Error loading model: {e}")
            self.processor = None
            self.model = None

    def predict_plant_species(self, image_path: str):
        if not self.model:
            return {"species": "Unknown (Model not loaded)", "confidence": 0.0, "embedding": None}

        try:
            image = Image.open(image_path).convert("RGB")
            inputs = self.processor(images=image, return_tensors="pt").to(self.device)
            
            with torch.no_grad():
                # We need hidden states to extract embeddings for the vector DB
                outputs = self.model(**inputs, output_hidden_states=True)
                logits = outputs.logits
                hidden_states = outputs.hidden_states
                
            # Get prediction
            predicted_class_idx = logits.argmax(-1).item()
            predicted_label = self.model.config.id2label[predicted_class_idx]
            
            # Get confidence
            probabilities = torch.nn.functional.softmax(logits, dim=-1)
            confidence = float(probabilities[0][predicted_class_idx].item())
            
            # Extract embedding (use the CLS token from the last hidden state)
            # The shape is (batch_size, sequence_length, hidden_size). CLS token is at index 0.
            embedding = hidden_states[-1][0, 0, :].cpu().numpy().tolist()
            
            return {
                "species": predicted_label,
                "confidence": confidence,
                "embedding": embedding
            }
        except Exception as e:
            print(f"Prediction error for {image_path}: {e}")
            return {"species": "Error processing image", "confidence": 0.0, "embedding": None}
            
    def estimate_bag_size(self, image_path: str):
        """
        Without a physical reference, we estimate relative scale.
        For MVP, we return a heuristic placeholder. 
        Next step: integrate YOLOv8 to detect the pot bounding box relative to frame area.
        """
        # TODO: Implement YOLOv8 inference for bounding box extraction
        return "Medium"

# Singleton instance
ml_service = MLService()
