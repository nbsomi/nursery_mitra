import faiss
import numpy as np
import os
import pickle

class VectorService:
    def __init__(self, index_file="backend/database/faiss_index.bin", metadata_file="backend/database/faiss_meta.pkl"):
        self.index_file = index_file
        self.metadata_file = metadata_file
        self.dimension = 768  # ViT base patch16 224 embedding size
        
        if os.path.exists(self.index_file):
            self.index = faiss.read_index(self.index_file)
            with open(self.metadata_file, "rb") as f:
                self.metadata = pickle.load(f)
        else:
            self.index = faiss.IndexFlatL2(self.dimension)
            self.metadata = []

    def add_embedding(self, review_id: str, embedding: list, nursery_id: str, species: str):
        if not embedding:
            return
            
        vector = np.array([embedding], dtype=np.float32)
        self.index.add(vector)
        self.metadata.append({
            "review_id": review_id,
            "nursery_id": nursery_id,
            "species": species
        })
        
        self.save()

    def search_similar(self, embedding: list, top_k: int = 5):
        if not embedding or self.index.ntotal == 0:
            return []
            
        vector = np.array([embedding], dtype=np.float32)
        distances, indices = self.index.search(vector, top_k)
        
        results = []
        for i, idx in enumerate(indices[0]):
            if idx != -1 and idx < len(self.metadata):
                res = self.metadata[idx].copy()
                res["distance"] = float(distances[0][i])
                results.append(res)
                
        return results

    def save(self):
        os.makedirs(os.path.dirname(self.index_file), exist_ok=True)
        faiss.write_index(self.index, self.index_file)
        with open(self.metadata_file, "wb") as f:
            pickle.dump(self.metadata, f)

vector_service = VectorService()
