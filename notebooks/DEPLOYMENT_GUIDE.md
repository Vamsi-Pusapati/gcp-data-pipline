# Deploying the RAG System as an API

This guide explains how to deploy the Medicaid Drug RAG system as a production API service.

## 📋 Prerequisites

1. **Build the Vector Store** - Run the notebook first to create:
   - `drug_rag_output/drug_index.faiss`
   - `drug_rag_output/drug_metadata.pkl`

2. **Extract RAG Classes** - Option A or B:

### Option A: Use Notebook Classes Directly

Save the classes from the notebook to `rag_system.py`:

```python
# Extract these classes from drug_rag_system.ipynb:
# - EmbeddingGenerator
# - DrugVectorStore
# - DrugRAGSystem
# - create_rich_text_description (if needed)
```

### Option B: Use nbconvert

```bash
# Convert notebook to Python script
jupyter nbconvert --to script drug_rag_system.ipynb

# Extract classes into rag_system.py
python extract_classes.py  # You'll need to create this
```

## 🚀 Deployment Options

### Option 1: Local Development

1. **Install dependencies**:
```bash
pip install -r requirements.txt
pip install fastapi uvicorn
```

2. **Set environment variables**:
```bash
export GOOGLE_CLOUD_PROJECT="gcp-project-deliverable"
export VERTEX_AI_LOCATION="us-central1"
export BQ_DATASET="medicaid_enriched"
export BQ_TABLE="nadac_drugs_enriched"
export VECTOR_INDEX_PATH="drug_rag_output/drug_index.faiss"
export VECTOR_METADATA_PATH="drug_rag_output/drug_metadata.pkl"
```

3. **Run the API**:
```bash
python rag_api.py
```

4. **Test it**:
```bash
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What are pain medications in tablet form?", "include_sources": true}'
```

### Option 2: Docker Container

1. **Create Dockerfile** (see `Dockerfile` in this directory)

2. **Build image**:
```bash
docker build -t drug-rag-api:latest .
```

3. **Run container**:
```bash
docker run -p 8080:8080 \
  -e GOOGLE_CLOUD_PROJECT=gcp-project-deliverable \
  -v ~/.config/gcloud:/root/.config/gcloud \
  -v $(pwd)/drug_rag_output:/app/drug_rag_output \
  drug-rag-api:latest
```

### Option 3: Cloud Run

1. **Build and push to Container Registry**:
```bash
gcloud builds submit --tag gcr.io/gcp-project-deliverable/drug-rag-api

# Or use Artifact Registry
gcloud builds submit --tag us-central1-docker.pkg.dev/gcp-project-deliverable/docker/drug-rag-api
```

2. **Deploy to Cloud Run**:
```bash
gcloud run deploy drug-rag-api \
  --image gcr.io/gcp-project-deliverable/drug-rag-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --set-env-vars GOOGLE_CLOUD_PROJECT=gcp-project-deliverable,VERTEX_AI_LOCATION=us-central1
```

3. **Note**: You'll need to upload the vector store to GCS and download it on startup:
```python
# In startup_event():
from google.cloud import storage
client = storage.Client()
bucket = client.bucket("your-bucket")
bucket.blob("drug_rag_output/drug_index.faiss").download_to_filename("drug_index.faiss")
bucket.blob("drug_rag_output/drug_metadata.pkl").download_to_filename("drug_metadata.pkl")
```

### Option 4: GKE (Similar to Dashboard)

1. **Build and push image** (as above)

2. **Create Kubernetes manifests**:

`k8s/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drug-rag-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: drug-rag-api
  template:
    metadata:
      labels:
        app: drug-rag-api
    spec:
      serviceAccountName: rag-api-ksa
      containers:
      - name: rag-api
        image: gcr.io/gcp-project-deliverable/drug-rag-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: GOOGLE_CLOUD_PROJECT
          value: "gcp-project-deliverable"
        - name: VERTEX_AI_LOCATION
          value: "us-central1"
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
```

`k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: drug-rag-api
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: drug-rag-api
```

3. **Deploy**:
```bash
kubectl apply -f k8s/
```

## 🧪 API Endpoints

### GET /
Health check and service info.

### GET /health
Detailed health status with vector store size.

```bash
curl http://localhost:8080/health
```

Response:
```json
{
  "status": "healthy",
  "vector_store_size": 1000,
  "models": {
    "embedding": "textembedding-gecko@003",
    "llm": "gemini-1.5-pro-001"
  }
}
```

### POST /query
Main endpoint for querying drug information.

```bash
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are pain medications in tablet form?",
    "k": 5,
    "temperature": 0.2,
    "include_sources": true
  }'
```

Response:
```json
{
  "question": "What are pain medications in tablet form?",
  "answer": "Based on the Medicaid database, here are some pain medications available in tablet form:\n\n1. Acetaminophen 500MG tablet (NDC: 12345-678-90) - $0.05 per tablet\n2. Ibuprofen 200MG tablet (NDC: 23456-789-01) - $0.03 per tablet\n...",
  "num_sources": 5,
  "sources": [
    {
      "ndc": "12345-678-90",
      "ndc_description": "ACETAMINOPHEN 500MG TABLET",
      "drug_name": "ACETAMINOPHEN",
      "nadac_per_unit": 0.05,
      "pricing_unit": "EA",
      "similarity_score": 0.89
    }
  ]
}
```

### POST /batch-query
Process multiple queries at once.

```bash
curl -X POST http://localhost:8080/batch-query \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      "What are pain medications?",
      "What are antibiotics?"
    ],
    "k": 5
  }'
```

## 📊 Performance Tuning

### 1. Vector Store Optimization

For large datasets (>100K drugs), use FAISS IVF indexes:

```python
# In DrugVectorStore.__init__():
nlist = 100  # Number of clusters
quantizer = faiss.IndexFlatIP(dimension)
self.index = faiss.IndexIVFFlat(quantizer, dimension, nlist)

# After adding vectors:
self.index.train(embeddings)
self.index.add(embeddings)
```

### 2. Caching

Add Redis caching for frequent queries:

```python
import redis
cache = redis.Redis(host='localhost', port=6379)

def query_with_cache(question, k=5):
    cache_key = f"rag:{question}:{k}"
    cached = cache.get(cache_key)
    if cached:
        return json.loads(cached)
    
    result = rag_system.query(question, k)
    cache.setex(cache_key, 3600, json.dumps(result))  # 1 hour TTL
    return result
```

### 3. Batch Processing

For high throughput, batch embed queries:

```python
@app.post("/batch-query-optimized")
async def batch_query_optimized(questions: List[str], k: int = 5):
    # Embed all questions at once
    embeddings = embedding_generator.generate_embeddings(questions)
    
    # Search for each
    results = []
    for question, embedding in zip(questions, embeddings):
        docs = vector_store.search(embedding, k)
        # ... process
    
    return results
```

### 4. Async Processing

Use background tasks for long-running queries:

```python
from fastapi import BackgroundTasks

@app.post("/query-async")
async def query_async(request: QueryRequest, background_tasks: BackgroundTasks):
    task_id = str(uuid.uuid4())
    background_tasks.add_task(process_query, task_id, request)
    return {"task_id": task_id, "status": "processing"}

@app.get("/query-status/{task_id}")
async def query_status(task_id: str):
    # Check status from database/cache
    pass
```

## 🔒 Security Considerations

### 1. Authentication

Add API key authentication:

```python
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

def verify_api_key(api_key: str = Security(api_key_header)):
    if api_key != os.getenv("API_KEY"):
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key

@app.post("/query")
async def query_drugs(request: QueryRequest, api_key: str = Depends(verify_api_key)):
    # ...
```

### 2. Rate Limiting

Add rate limiting with slowapi:

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/query")
@limiter.limit("10/minute")
async def query_drugs(request: Request, query: QueryRequest):
    # ...
```

### 3. Input Validation

Already handled by Pydantic models, but add length checks:

```python
class QueryRequest(BaseModel):
    question: str = Field(..., min_length=3, max_length=500)
    k: int = Field(default=5, ge=1, le=20)
```

## 📈 Monitoring

### 1. Add Logging

```python
import logging
from google.cloud import logging as gcp_logging

# Use Cloud Logging in production
if os.getenv("ENV") == "production":
    client = gcp_logging.Client()
    client.setup_logging()
```

### 2. Add Metrics

```python
from prometheus_client import Counter, Histogram

query_counter = Counter('rag_queries_total', 'Total RAG queries')
query_latency = Histogram('rag_query_latency_seconds', 'RAG query latency')

@app.post("/query")
@query_latency.time()
async def query_drugs(request: QueryRequest):
    query_counter.inc()
    # ...
```

### 3. Health Checks

Already implemented at `/health`. Monitor:
- Vector store size
- Model availability
- Memory usage
- Response times

## 🧹 Maintenance

### Updating the Vector Store

1. **Re-run notebook** with latest data
2. **Generate new vector store** files
3. **Deploy updated files**:
   - Local: Replace files in `drug_rag_output/`
   - Cloud: Upload to GCS and restart service
   - GKE: Update ConfigMap/Volume

### Updating Models

To switch embedding or LLM models:

1. Update environment variables
2. Regenerate embeddings if embedding model changes
3. Redeploy service

## 💰 Cost Optimization

- **Cache frequent queries** (Redis/Memcached)
- **Use smaller k values** when possible
- **Batch process** during off-peak hours
- **Monitor Vertex AI usage** in GCP Console
- **Set resource limits** appropriately

## 📚 Example Integration

### Python Client

```python
import requests

class DrugRAGClient:
    def __init__(self, base_url: str, api_key: str = None):
        self.base_url = base_url
        self.headers = {"X-API-Key": api_key} if api_key else {}
    
    def query(self, question: str, k: int = 5):
        response = requests.post(
            f"{self.base_url}/query",
            json={"question": question, "k": k, "include_sources": True},
            headers=self.headers
        )
        return response.json()

# Usage
client = DrugRAGClient("http://localhost:8080")
result = client.query("What are pain medications?")
print(result['answer'])
```

### JavaScript Client

```javascript
class DrugRAGClient {
  constructor(baseUrl, apiKey = null) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
  }
  
  async query(question, k = 5) {
    const response = await fetch(`${this.baseUrl}/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(this.apiKey && {'X-API-Key': this.apiKey})
      },
      body: JSON.stringify({question, k, include_sources: true})
    });
    return response.json();
  }
}

// Usage
const client = new DrugRAGClient('http://localhost:8080');
const result = await client.query('What are pain medications?');
console.log(result.answer);
```

---

## 🎯 Quick Deployment Checklist

- [ ] Run notebook and build vector store
- [ ] Extract RAG classes to `rag_system.py`
- [ ] Test API locally
- [ ] Build Docker image
- [ ] Push to container registry
- [ ] Deploy to Cloud Run/GKE
- [ ] Set up monitoring and logging
- [ ] Configure rate limiting and authentication
- [ ] Test production endpoint
- [ ] Document API for users

Ready to deploy? Start with local testing, then move to Cloud Run for easiest production deployment! 🚀
