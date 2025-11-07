# 📚 Documentation Index

Quick links to all RAG system documentation and resources.

## 🎯 Start Here

| Document | Purpose | Time Required | Best For |
|----------|---------|---------------|----------|
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Overview of what's been built | 5 min | Understanding the project |
| [QUICKSTART.md](QUICKSTART.md) | Get running in 15 minutes | 15 min | First-time users |
| [drug_rag_system.ipynb](drug_rag_system.ipynb) | Complete implementation | 1-2 hours | Learning and experimentation |

## 📖 Main Documentation

### For Users

**[README.md](README.md)** - Main documentation
- Features and capabilities
- How to use the notebook
- Example queries
- Configuration options
- Troubleshooting
→ *Read this after quick start*

**[QUICKSTART.md](QUICKSTART.md)** - Fast setup guide
- Prerequisites
- Step-by-step setup (15 min)
- First queries
- Common issues
→ *Start here if you want to run it immediately*

### For Developers

**[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Production deployment
- Local development
- Docker containerization
- Cloud Run deployment
- GKE deployment
- API documentation
- Performance tuning
- Security considerations
→ *Use when ready to deploy*

**[OVERVIEW.md](OVERVIEW.md)** - Architecture and design
- System architecture
- Component details
- Data flow
- Performance characteristics
- Integration points
- Cost analysis
→ *Read for deep understanding*

## 🔧 Implementation Files

### Core Implementation

**[drug_rag_system.ipynb](drug_rag_system.ipynb)** - Main Jupyter notebook
- 13 sections covering full pipeline
- ~40 code cells with explanations
- Interactive examples
- Evaluation metrics
→ *This is the main deliverable*

### Deployment Code

**[rag_api.py](rag_api.py)** - FastAPI service
- REST API endpoints
- Request/response models
- Health checks
- Batch processing
→ *Use for production API deployment*

**[Dockerfile](Dockerfile)** - Container image
- Python 3.10 base
- All dependencies
- Optimized for Cloud Run/GKE
→ *Use for containerized deployment*

### Utility Scripts

**[setup_rag.py](setup_rag.py)** - Automated setup
- Checks prerequisites
- Creates virtual environment
- Installs dependencies
→ *Run this first*

**[extract_notebook_code.py](extract_notebook_code.py)** - Code extraction
- Extracts classes from notebook
- Creates standalone module
→ *Use when deploying as API*

## 📋 Configuration Files

**[requirements.txt](requirements.txt)** - Notebook dependencies
- Core Python packages
- Vertex AI libraries
- FAISS vector store
- Jupyter environment

**[rag-api-requirements.txt](rag-api-requirements.txt)** - API dependencies
- FastAPI framework
- Uvicorn server
- Optional monitoring tools

## 🗺️ Navigation Guide

### I want to...

**...understand what this is**
1. Read [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
2. Skim [OVERVIEW.md](OVERVIEW.md)

**...run it quickly**
1. Run `python setup_rag.py`
2. Follow [QUICKSTART.md](QUICKSTART.md)
3. Open [drug_rag_system.ipynb](drug_rag_system.ipynb)

**...learn how it works**
1. Read [README.md](README.md)
2. Study [drug_rag_system.ipynb](drug_rag_system.ipynb)
3. Review [OVERVIEW.md](OVERVIEW.md) architecture section

**...deploy to production**
1. Complete notebook setup first
2. Follow [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
3. Use [rag_api.py](rag_api.py) and [Dockerfile](Dockerfile)

**...integrate with dashboard**
1. Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) → Integration section
2. Extract classes with [extract_notebook_code.py](extract_notebook_code.py)
3. Import into dashboard code

**...troubleshoot issues**
1. Check [QUICKSTART.md](QUICKSTART.md) → Troubleshooting
2. Review [README.md](README.md) → Troubleshooting
3. Check notebook cell outputs

## 📊 Document Relationships

```
PROJECT_SUMMARY.md (Start here!)
    ├─→ QUICKSTART.md (Run it quickly)
    │   └─→ drug_rag_system.ipynb (Main implementation)
    │
    ├─→ README.md (Learn to use)
    │   └─→ drug_rag_system.ipynb
    │
    ├─→ OVERVIEW.md (Understand architecture)
    │   └─→ README.md
    │
    └─→ DEPLOYMENT_GUIDE.md (Deploy to production)
        ├─→ rag_api.py
        ├─→ Dockerfile
        └─→ extract_notebook_code.py
```

## 🎯 Quick Reference

### Common Tasks

| Task | Command/File |
|------|-------------|
| Setup environment | `python setup_rag.py` |
| Run notebook | `jupyter notebook drug_rag_system.ipynb` |
| Check prerequisites | [QUICKSTART.md](QUICKSTART.md) Prerequisites |
| Example queries | [README.md](README.md) Sample Questions |
| Deploy API | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) Option 2 |
| Deploy to Cloud Run | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) Option 3 |
| Integrate with dashboard | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) Integration |
| Troubleshooting | [QUICKSTART.md](QUICKSTART.md) Troubleshooting |
| Architecture details | [OVERVIEW.md](OVERVIEW.md) Architecture |
| Cost analysis | [OVERVIEW.md](OVERVIEW.md) Cost Analysis |

### Configuration

| Parameter | Where to Change |
|-----------|----------------|
| GCP Project | Notebook cell #4, `PROJECT_ID` variable |
| Dataset size | Notebook cell #9, `limit` parameter |
| Number of results | Notebook cell #21+, `k` parameter |
| LLM creativity | Query calls, `temperature` parameter |
| Embedding model | Notebook cell #4, `EMBEDDING_MODEL` |
| LLM model | Notebook cell #4, `LLM_MODEL` |

## 📈 Recommended Reading Order

### For First-Time Users
1. [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - 5 min
2. [QUICKSTART.md](QUICKSTART.md) - 15 min
3. [drug_rag_system.ipynb](drug_rag_system.ipynb) - Run it!
4. [README.md](README.md) - Reference as needed

### For Developers
1. [OVERVIEW.md](OVERVIEW.md) - Architecture
2. [drug_rag_system.ipynb](drug_rag_system.ipynb) - Implementation
3. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Production
4. [rag_api.py](rag_api.py) - API code

### For DevOps/Deployment
1. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Full guide
2. [Dockerfile](Dockerfile) - Container setup
3. [rag_api.py](rag_api.py) - Service code
4. [OVERVIEW.md](OVERVIEW.md) - Performance section

## 🔍 Search Guide

Looking for specific information?

| Topic | Document | Section |
|-------|----------|---------|
| Setup instructions | QUICKSTART.md | Step 1 |
| Example queries | README.md | Sample Questions |
| Architecture | OVERVIEW.md | Architecture |
| API endpoints | DEPLOYMENT_GUIDE.md | API Endpoints |
| Cost estimates | OVERVIEW.md | Cost Analysis |
| Troubleshooting | QUICKSTART.md | Troubleshooting |
| Integration | DEPLOYMENT_GUIDE.md | Integration Points |
| Performance | OVERVIEW.md | Performance |
| Security | DEPLOYMENT_GUIDE.md | Security |

## 📞 Support Resources

1. **Documentation** - You're reading it!
2. **Notebook Comments** - Detailed explanations in [drug_rag_system.ipynb](drug_rag_system.ipynb)
3. **GCP Docs** - [Vertex AI](https://cloud.google.com/vertex-ai/docs)
4. **FAISS Docs** - [GitHub](https://github.com/facebookresearch/faiss)

## 🚀 Next Steps

1. **New User?** → [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) → [QUICKSTART.md](QUICKSTART.md)
2. **Ready to Run?** → `python setup_rag.py` → [drug_rag_system.ipynb](drug_rag_system.ipynb)
3. **Want to Deploy?** → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
4. **Need Help?** → [QUICKSTART.md](QUICKSTART.md) Troubleshooting

---

**Lost? Start with [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** 📖

**Ready? Run `python setup_rag.py`** 🚀
