# Medicaid Drug RAG System

This directory contains a complete Retrieval-Augmented Generation (RAG) system for querying Medicaid drug information using Vertex AI.

## 📁 Files

- `drug_rag_system.ipynb` - Complete Jupyter notebook with RAG implementation

## 🎯 What This Does

The RAG system enables natural language queries over your enriched Medicaid drug data:

1. **Loads data** from BigQuery (`medicaid_enriched.nadac_drugs_enriched`)
2. **Creates embeddings** using Vertex AI's text-embedding-gecko model
3. **Builds a vector store** with FAISS for semantic search
4. **Answers questions** using Vertex AI's Gemini Pro LLM

## 🚀 Quick Start

### Prerequisites

1. **GCP Project Access**
   ```bash
   gcloud auth login
   gcloud config set project gcp-project-deliverable
   ```

2. **Enable Required APIs**
   ```bash
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable bigquery.googleapis.com
   ```

3. **Python Environment** (Python 3.10+)
   ```bash
   pip install jupyter notebook
   ```

### Running the Notebook

#### Option 1: Local Jupyter
```bash
cd notebooks
jupyter notebook drug_rag_system.ipynb
```

#### Option 2: Google Colab
1. Upload `drug_rag_system.ipynb` to Google Colab
2. Authenticate with your GCP account
3. Run all cells

#### Option 3: Vertex AI Workbench
1. Create a Vertex AI Workbench instance
2. Upload the notebook
3. Execute (authentication is automatic)

## 📊 Notebook Structure

### Section 1-3: Setup
- Install dependencies
- Configure GCP project
- Initialize Vertex AI

### Section 4-5: Data Loading
- Query BigQuery for enriched drug data
- Create rich text descriptions for embeddings

### Section 6-7: Vector Store
- Generate embeddings with Vertex AI
- Build FAISS index for similarity search
- Test retrieval quality

### Section 8-9: RAG System
- Integrate LLM (Gemini Pro) with retrieval
- Test with natural language queries
- Examples:
  - "What are some pain medications available in tablet form?"
  - "What are the most affordable antibiotic options?"
  - "What injectable medications are available for diabetes?"

### Section 10-11: Advanced Features
- Save/load vector store for reuse
- Multi-turn conversational interface
- Context-aware follow-up questions

### Section 12-13: Evaluation & Deployment
- Retrieval quality metrics
- Production deployment guidance

## 💡 Example Usage

```python
# After running the notebook setup...

# Ask a question
result = rag_system.query("What are affordable blood pressure medications?")
print(result['answer'])

# Or use the conversational interface
conv_rag = ConversationalRAG(rag_system)
response1 = conv_rag.chat("Tell me about diabetes medications")
response2 = conv_rag.chat("What are their prices?")  # Context-aware follow-up
```

## 🎨 Sample Questions

Try these queries in the notebook:

1. **Drug Search**
   - "What antibiotics are available in liquid form?"
   - "Show me over-the-counter pain medications"

2. **Pricing**
   - "What are the cheapest cholesterol medications?"
   - "Compare prices for insulin products"

3. **Drug Details**
   - "Tell me about metformin dosage forms"
   - "What strengths does ibuprofen come in?"

4. **Comparisons**
   - "Compare generic vs brand name blood pressure drugs"
   - "What's the price difference between tablet and capsule forms?"

## 🔧 Configuration

Edit these variables in the notebook as needed:

```python
PROJECT_ID = "gcp-project-deliverable"  # Your GCP project
LOCATION = "us-central1"                # Vertex AI location
DATASET_ID = "medicaid_enriched"        # BigQuery dataset
TABLE_ID = "nadac_drugs_enriched"       # BigQuery table

# Model configurations
EMBEDDING_MODEL = "textembedding-gecko@003"
LLM_MODEL = "gemini-1.5-pro-001"
```

## 📈 Data Volume Considerations

The notebook uses `limit=1000` for testing. For production:

```python
# Load full dataset
df = load_drug_data(PROJECT_ID, DATASET_ID, TABLE_ID, limit=None)
```

**Expected volumes:**
- Small test: 1,000 drugs (~2 minutes to embed)
- Medium: 10,000 drugs (~20 minutes)
- Full dataset: 50,000+ drugs (~1-2 hours)

## 💾 Saving & Reusing the Vector Store

The notebook includes code to save the vector store:

```python
vector_store.save("drug_index.faiss", "drug_metadata.pkl")
```

To load later:
```python
vector_store = DrugVectorStore.load("drug_index.faiss", "drug_metadata.pkl")
```

## 🚀 Production Deployment

After testing in the notebook, deploy as:

### Option 1: FastAPI Service
```python
from fastapi import FastAPI
app = FastAPI()

# Load RAG system once at startup
rag_system = load_rag_system()

@app.post("/query")
def query_drugs(question: str):
    result = rag_system.query(question)
    return {"answer": result['answer']}
```

### Option 2: Cloud Function
```python
def rag_query(request):
    question = request.get_json()['question']
    result = rag_system.query(question)
    return {"answer": result['answer']}
```

### Option 3: Add to Streamlit Dashboard
Integrate with your existing `dashboard/app.py`:

```python
# In app.py
st.header("💬 Ask About Drugs")
question = st.text_input("Your question:")
if question:
    answer = rag_system.query(question)
    st.write(answer['answer'])
```

## 📊 Performance Optimization

### For Faster Embeddings
- Use batch processing (already implemented)
- Consider caching common embeddings
- Use Vertex AI batch prediction for large datasets

### For Faster Search
- Use FAISS IVF indexes for >100K vectors
- Consider managed solutions:
  - Vertex AI Vector Search
  - Pinecone
  - Weaviate

### For Better Answers
- Adjust `k` (number of retrieved documents)
- Tune LLM `temperature` (0 = deterministic, 1 = creative)
- Experiment with different prompt templates

## 🔍 Troubleshooting

### Authentication Issues
```bash
# Set application default credentials
gcloud auth application-default login

# Verify project
gcloud config get-value project
```

### API Not Enabled
```bash
gcloud services enable aiplatform.googleapis.com
```

### Quota Errors
- Check Vertex AI quotas: https://console.cloud.google.com/iam-admin/quotas
- Request quota increase if needed
- Reduce batch size or add rate limiting

### Memory Issues
- Reduce dataset size with `limit` parameter
- Use smaller embedding batches
- Consider using a larger VM/Colab instance

## 📚 Additional Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [FAISS Documentation](https://github.com/facebookresearch/faiss)
- [LangChain RAG Guide](https://python.langchain.com/docs/use_cases/question_answering/)

## 🎓 Next Steps

1. ✅ Run the notebook end-to-end
2. ✅ Test with your own queries
3. ✅ Evaluate retrieval quality
4. 🔄 Scale to full dataset
5. 🔄 Deploy as API or integrate with dashboard
6. 🔄 Add monitoring and logging
7. 🔄 Collect user feedback and iterate

## 📝 Notes

- The notebook is self-contained and well-documented
- Each cell includes explanations and can be run independently
- All GCP costs are pay-per-use (embeddings, LLM calls)
- Consider caching results for frequent queries to reduce costs

## 🤝 Support

For issues or questions about the RAG system:
1. Check the troubleshooting section above
2. Review Vertex AI logs in GCP Console
3. Examine the notebook cell outputs for errors
4. Consult the GCP Vertex AI documentation

---

**Ready to start?** Open `drug_rag_system.ipynb` and run all cells! 🚀
