# 🚀 Quick Start: Medicaid Drug RAG System

Get your RAG system running in 15 minutes!

## Prerequisites

- ✅ GCP account with Vertex AI enabled
- ✅ Python 3.10+
- ✅ BigQuery table `medicaid_enriched.nadac_drugs_enriched` populated
- ✅ `gcloud` CLI configured

## Step 1: Setup Environment (2 min)

```bash
cd notebooks

# Create virtual environment
python -m venv venv

# Activate it
# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Authenticate with GCP
gcloud auth application-default login
```

## Step 2: Run the Notebook (10 min)

```bash
# Start Jupyter
jupyter notebook drug_rag_system.ipynb
```

In the notebook:

1. **Update configuration** (Cell #4):
   ```python
   PROJECT_ID = "your-project-id"  # Change this!
   LOCATION = "us-central1"
   ```

2. **Run all cells** sequentially:
   - Press `Shift+Enter` to run each cell
   - Or use `Cell > Run All` menu

3. **Key cells**:
   - Cell #3: Install packages (~2 min)
   - Cell #9: Load data from BigQuery (~1 min)
   - Cell #12: Generate embeddings (~5 min for 1000 drugs)
   - Cell #15: Build vector store (~30 sec)
   - Cell #18: Initialize RAG system (~10 sec)
   - Cell #21-26: Test queries! 🎉

## Step 3: Test Queries (3 min)

Try these in the notebook:

```python
# Simple query
result = rag_system.query("What are pain medications in tablet form?")
print(result['answer'])

# With sources
ask_question("What are affordable antibiotics?", show_context=True)

# Conversational
conv_rag = ConversationalRAG(rag_system)
conv_rag.chat("Tell me about diabetes medications")
conv_rag.chat("What are their prices?")  # Contextual follow-up!
```

## What You Can Ask

### Drug Search
- "What antibiotics are available in liquid form?"
- "Show me over-the-counter allergy medications"
- "Find injectable insulin products"

### Pricing
- "What are the cheapest cholesterol medications?"
- "Compare prices for blood pressure drugs"
- "Show me affordable pain medications"

### Drug Details
- "Tell me about metformin dosage forms"
- "What strengths does ibuprofen come in?"
- "Details on lisinopril pricing"

### Comparisons
- "Compare generic vs brand name options"
- "Tablet vs capsule forms of the same drug"

## Expected Results

After running the notebook, you'll have:

✅ Vector store with embeddings: `drug_rag_output/`
✅ Working RAG system that answers questions
✅ Retrieval accuracy: ~85-95% relevance
✅ Response time: 2-5 seconds per query

## 💾 Save Your Work

The notebook automatically saves the vector store:

```python
# Already done in Section 10
vector_store.save(
    "drug_rag_output/drug_index.faiss",
    "drug_rag_output/drug_metadata.pkl"
)
```

## 🚀 Next Steps

### Option A: Keep Using the Notebook
Perfect for exploration and analysis!

### Option B: Deploy as API (Advanced)
See `DEPLOYMENT_GUIDE.md` for details:

```bash
# 1. Extract classes
python extract_notebook_code.py
# Manually copy classes from notebook to rag_system.py

# 2. Test API locally
python rag_api.py

# 3. Query it
curl -X POST http://localhost:8080/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What are pain medications?"}'
```

### Option C: Integrate with Dashboard
Add to your Streamlit dashboard:

```python
# In dashboard/app.py
import sys
sys.path.append('../notebooks')
from rag_system import DrugRAGSystem

# Add chat interface
st.header("💬 Ask About Drugs")
question = st.text_input("Your question:")
if question:
    result = rag_system.query(question)
    st.write(result['answer'])
```

## 🐛 Troubleshooting

### Error: "Project not found"
```bash
# Set your project
gcloud config set project your-project-id
export GOOGLE_CLOUD_PROJECT=your-project-id
```

### Error: "Vertex AI API not enabled"
```bash
gcloud services enable aiplatform.googleapis.com
```

### Error: "Table not found"
Ensure you've run the data pipeline first:
- Extract Medicaid data (composer DAG)
- Enrich with Dataproc
- Check: `bq ls gcp-project-deliverable:medicaid_enriched`

### Error: "Out of memory"
Reduce dataset size:
```python
# In cell #9
df = load_drug_data(PROJECT_ID, DATASET_ID, TABLE_ID, limit=100)
```

### Slow embeddings
This is normal! Vertex AI processes in batches:
- 1,000 drugs: ~5 min
- 10,000 drugs: ~45 min
- 50,000 drugs: ~3-4 hours

### Poor retrieval quality
Try adjusting:
- `k` parameter (more documents)
- Query phrasing (be more specific)
- Temperature (lower = more deterministic)

## 📊 Performance Tips

### For Faster Testing
```python
# Use smaller dataset
df = load_drug_data(PROJECT_ID, DATASET_ID, TABLE_ID, limit=500)
```

### For Better Results
```python
# Retrieve more documents
result = rag_system.query(question, k=10)

# More creative responses
result = rag_system.query(question, temperature=0.5)
```

### For Production
```python
# Load full dataset
df = load_drug_data(PROJECT_ID, DATASET_ID, TABLE_ID, limit=None)

# Optimize FAISS index
# See notebook Section 12 for details
```

## 💰 Cost Estimates (GCP)

Approximate costs for testing:

- **Embeddings** (text-embedding-gecko):
  - 1,000 drugs: ~$0.10
  - 10,000 drugs: ~$1.00
  - 50,000 drugs: ~$5.00

- **LLM Queries** (gemini-pro):
  - Per query: ~$0.001-0.01
  - 100 queries: ~$0.50

- **BigQuery**:
  - Data scan: ~$0.01 (minimal)

**Total for testing**: ~$1-2

## 🎉 Success Checklist

- [ ] Notebook runs without errors
- [ ] Can load drug data from BigQuery
- [ ] Embeddings generated successfully
- [ ] Vector store created
- [ ] RAG system answers questions correctly
- [ ] Responses are relevant and accurate
- [ ] Vector store saved to disk

## 📚 Learn More

- **Notebook**: Open `drug_rag_system.ipynb` - fully documented!
- **Deployment**: See `DEPLOYMENT_GUIDE.md` for API deployment
- **Architecture**: Check `README.md` for system overview
- **Vertex AI**: https://cloud.google.com/vertex-ai/docs

## 🆘 Need Help?

1. Check the troubleshooting section above
2. Review notebook cell outputs for errors
3. Check GCP Console logs
4. Review Vertex AI quotas

## 🎯 What's Next?

Now that you have a working RAG system:

1. ✅ **Test thoroughly** with various queries
2. ✅ **Evaluate accuracy** (Section 12 in notebook)
3. ✅ **Scale to full dataset** (remove `limit`)
4. 🔄 **Deploy as API** (see DEPLOYMENT_GUIDE.md)
5. 🔄 **Integrate with dashboard** (add chat interface)
6. 🔄 **Monitor and improve** (collect feedback)

---

**Ready to start?** Run `jupyter notebook drug_rag_system.ipynb` and follow along! 🚀

Questions about any step? Check the detailed README.md or DEPLOYMENT_GUIDE.md!
