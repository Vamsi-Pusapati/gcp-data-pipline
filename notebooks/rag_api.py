#!/usr/bin/env python3
"""
Standalone RAG API Service
Deploy the drug RAG system as a FastAPI service.

Usage:
    python rag_api.py

Then query:
    curl -X POST http://localhost:8080/query \
         -H "Content-Type: application/json" \
         -d '{"question": "What are pain medications in tablet form?"}'
"""

import os
import logging
from typing import Dict, List, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# Import RAG components (assuming they're in a module or copied)
try:
    from rag_system import DrugRAGSystem, EmbeddingGenerator, DrugVectorStore, load_drug_data
except ImportError:
    print("Warning: rag_system module not found. You'll need to extract classes from the notebook.")
    # For now, we'll provide imports and initialization code

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "gcp-project-deliverable")
LOCATION = os.getenv("VERTEX_AI_LOCATION", "us-central1")
DATASET_ID = os.getenv("BQ_DATASET", "medicaid_enriched")
TABLE_ID = os.getenv("BQ_TABLE", "nadac_drugs_enriched")

EMBEDDING_MODEL = "textembedding-gecko@003"
LLM_MODEL = "gemini-1.5-pro-001"

# Global RAG system instance
rag_system = None

# FastAPI app
app = FastAPI(
    title="Medicaid Drug RAG API",
    description="Query Medicaid drug information using natural language",
    version="1.0.0"
)

# Request/Response models
class QueryRequest(BaseModel):
    question: str
    k: Optional[int] = 5  # Number of documents to retrieve
    temperature: Optional[float] = 0.2
    include_sources: Optional[bool] = False

class DrugSource(BaseModel):
    ndc: str
    ndc_description: str
    drug_name: Optional[str]
    nadac_per_unit: Optional[float]
    pricing_unit: Optional[str]
    similarity_score: float

class QueryResponse(BaseModel):
    question: str
    answer: str
    num_sources: int
    sources: Optional[List[DrugSource]] = None

class HealthResponse(BaseModel):
    status: str
    vector_store_size: int
    models: Dict[str, str]

@app.on_event("startup")
async def startup_event():
    """Initialize RAG system on startup."""
    global rag_system
    
    logger.info("Initializing RAG system...")
    
    try:
        # Initialize Vertex AI
        import vertexai
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        
        # Try to load pre-built vector store
        index_path = os.getenv("VECTOR_INDEX_PATH", "drug_rag_output/drug_index.faiss")
        metadata_path = os.getenv("VECTOR_METADATA_PATH", "drug_rag_output/drug_metadata.pkl")
        
        if os.path.exists(index_path) and os.path.exists(metadata_path):
            logger.info(f"Loading vector store from {index_path}")
            vector_store = DrugVectorStore.load(index_path, metadata_path)
        else:
            logger.warning("Vector store not found. You need to build it first using the notebook.")
            # In production, you might want to build it here or fail fast
            raise FileNotFoundError("Vector store files not found")
        
        # Initialize embedding generator
        embedding_generator = EmbeddingGenerator(model_name=EMBEDDING_MODEL)
        
        # Initialize RAG system
        rag_system = DrugRAGSystem(
            vector_store=vector_store,
            embedding_generator=embedding_generator,
            llm_model_name=LLM_MODEL
        )
        
        logger.info("✓ RAG system initialized successfully")
        
    except Exception as e:
        logger.error(f"Failed to initialize RAG system: {e}")
        raise

@app.get("/", response_model=Dict[str, str])
async def root():
    """Root endpoint."""
    return {
        "service": "Medicaid Drug RAG API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    if rag_system is None:
        raise HTTPException(status_code=503, detail="RAG system not initialized")
    
    return HealthResponse(
        status="healthy",
        vector_store_size=rag_system.vector_store.index.ntotal,
        models={
            "embedding": EMBEDDING_MODEL,
            "llm": LLM_MODEL
        }
    )

@app.post("/query", response_model=QueryResponse)
async def query_drugs(request: QueryRequest):
    """
    Query the RAG system with a natural language question.
    
    Example:
        {
            "question": "What are pain medications in tablet form?",
            "k": 5,
            "temperature": 0.2,
            "include_sources": true
        }
    """
    if rag_system is None:
        raise HTTPException(status_code=503, detail="RAG system not initialized")
    
    try:
        logger.info(f"Processing query: {request.question}")
        
        # Query RAG system
        result = rag_system.query(
            question=request.question,
            k=request.k,
            temperature=request.temperature
        )
        
        # Build response
        response = QueryResponse(
            question=request.question,
            answer=result['answer'],
            num_sources=result['num_documents']
        )
        
        # Include sources if requested
        if request.include_sources:
            response.sources = [
                DrugSource(
                    ndc=doc.get('ndc', ''),
                    ndc_description=doc.get('ndc_description', ''),
                    drug_name=doc.get('drug_name'),
                    nadac_per_unit=doc.get('nadac_per_unit'),
                    pricing_unit=doc.get('pricing_unit'),
                    similarity_score=doc.get('similarity_score', 0.0)
                )
                for doc in result['retrieved_documents']
            ]
        
        logger.info(f"Query processed successfully. Answer length: {len(result['answer'])} chars")
        return response
        
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/batch-query")
async def batch_query(questions: List[str], k: int = 5):
    """
    Process multiple queries in batch.
    
    Example:
        {
            "questions": [
                "What are pain medications?",
                "What are antibiotics?"
            ],
            "k": 5
        }
    """
    if rag_system is None:
        raise HTTPException(status_code=503, detail="RAG system not initialized")
    
    try:
        results = []
        for question in questions:
            result = rag_system.query(question, k=k)
            results.append({
                "question": question,
                "answer": result['answer'],
                "num_sources": result['num_documents']
            })
        
        return {"results": results}
        
    except Exception as e:
        logger.error(f"Error processing batch query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def main():
    """Run the API server."""
    port = int(os.getenv("PORT", 8080))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"Starting RAG API server on {host}:{port}")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info"
    )

if __name__ == "__main__":
    main()
