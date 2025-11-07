# Medicaid Drug Data Pipeline - GCP

Production-grade data pipeline for extracting, processing, enriching, and visualizing Medicaid drug pricing data on Google Cloud Platform.

## 🎯 Project Overview

This project implements a complete end-to-end data pipeline:

1. **Extract** - Pull drug data from Medicaid API
2. **Store** - Save to Google Cloud Storage
3. **Load** - Import to BigQuery staging tables
4. **Enrich** - Process with Dataproc (PySpark) for structured drug information
5. **Visualize** - Interactive Streamlit dashboard on GKE

## 🏗️ Architecture

```
Medicaid API
    │
    ▼
[Extraction Script]
    │
    ▼
Cloud Storage (Raw Data)
    │
    ▼
BigQuery (Staging)
    │
    ▼
Dataproc (PySpark Enrichment)
    │
    ▼
BigQuery (Enriched Data)
    │
    ▼
Streamlit Dashboard (GKE)
    │
    ▼
End Users
```

## 📦 Project Structure

```
GCS_Project/
├── dataproc/
│   └── data_processing_job.py           # PySpark enrichment job
│
├── composer/
│   └── dags/
│       ├── medicaid_data_dag.py         # Extraction DAG
│       └── medicaid_enrichment_dag.py   # Enrichment DAG
│
├── dashboard/
│   ├── app.py                           # Streamlit dashboard
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── k8s/                             # Kubernetes manifests
│   ├── deploy-gke.ps1                   # Deployment script (Windows)
│   ├── build-image.ps1                  # Build script (Windows)
│   ├── verify-setup.ps1                 # Setup verification
│   ├── manage-dashboard.ps1             # Management script
│    ├── QUICKSTART.md                    # 5-minute deployment guide
    ├── README.md                        # Complete dashboard docs
    ├── DEPLOYMENT.md                    # Detailed deployment
    └── TOOLKIT.md                       # Complete script reference
│
├── scripts/
│   ├── setup-gcs.sh                     # GCS bucket setup
│   ├── setup-bigquery.sh                # BigQuery setup
│   └── setup-dataproc.sh                # Dataproc setup
│
├── cloudbuild.yaml                      # Cloud Build config
├── .gitignore                           # Git exclusions
└── README.md                            # This file
```

## 🚀 Quick Start

### Prerequisites

- ✅ Google Cloud SDK (`gcloud`) installed - [Download](https://cloud.google.com/sdk/docs/install)
- ✅ Authenticated with GCP: `gcloud auth login`
- ✅ Project ID: `gcp-project-deliverable`
- ❌ **Docker NOT required!** (Uses Cloud Build)

### Deploy Dashboard (5 Minutes)

```powershell
cd dashboard

# 1. Verify setup
.\verify-setup.ps1

# 2. Deploy (builds remotely, no Docker needed!)
.\deploy-gke.ps1

# 3. Access dashboard at http://<EXTERNAL-IP>:8501
```

**See [dashboard/QUICKSTART.md](dashboard/QUICKSTART.md) for detailed instructions.**

## 📊 Data Flow

### 1. Extraction (Airflow DAG)
**File:** `composer/dags/medicaid_data_dag.py`
- Pulls data from Medicaid Drug Pricing API
- Stores raw JSON in Cloud Storage
- Loads to BigQuery staging table

### 2. Enrichment (Dataproc PySpark)
**File:** `dataproc/data_processing_job.py`
- Parses drug names into components (name, strength, form)
- Explodes explanation codes
- Writes enriched data to BigQuery

**DAG:** `composer/dags/medicaid_enrichment_dag.py`

### 3. Visualization (Streamlit on GKE)
**File:** `dashboard/app.py`
- Interactive charts (bar, pie, line, scatter)
- Dynamic filters
- Real-time BigQuery queries

## 🎨 Dashboard Features

- **Real-time BigQuery Integration**
- **Multiple Visualizations:**
  - Bar chart: Average price by drug
  - Pie chart: Top 10 drugs + others
  - Line chart: Price trends over time
  - Scatter plot: Price vs. dosage
- **Interactive Filters** (drug, date, dosage form)
- **Secure Authentication** (Workload Identity)
- **Auto-scaling** (1-4 replicas)

## 🛠️ Management Scripts

All scripts are in the `dashboard/` directory:

```powershell
cd dashboard

# Verify prerequisites
.\verify-setup.ps1

# Build Docker image (uses Cloud Build, no local Docker!)
.\build-image.ps1

# Deploy everything to GKE
.\deploy-gke.ps1

# Daily operations
.\manage-dashboard.ps1 -Action status      # Check status
.\manage-dashboard.ps1 -Action logs        # View logs
.\manage-dashboard.ps1 -Action restart     # Restart
.\manage-dashboard.ps1 -Action scale -Replicas 3   # Scale
.\manage-dashboard.ps1 -Action url         # Get URL
```

## 📖 Documentation

### Dashboard
- **[QUICKSTART.md](dashboard/QUICKSTART.md)** - 5-minute deployment guide ⚡
- **[README.md](dashboard/README.md)** - Complete dashboard documentation
- **[DEPLOYMENT.md](dashboard/DEPLOYMENT.md)** - Detailed deployment instructions
- **[TOOLKIT.md](dashboard/TOOLKIT.md)** - Complete script reference

### Pipeline
- **[Dataproc Job](dataproc/data_processing_job.py)** - PySpark enrichment logic
- **[Extraction DAG](composer/dags/medicaid_data_dag.py)** - API extraction
- **[Enrichment DAG](composer/dags/medicaid_enrichment_dag.py)** - Data processing

## 🔧 Configuration

### GCP Resources

| Resource | Name/ID | Purpose |
|----------|---------|---------|
| Project | `gcp-project-deliverable` | Main GCP project |
| GCS Bucket | `gcp-project-deliverable-medicaid-data` | Raw data storage |
| BigQuery Dataset | `medicaid_data` | All tables |
| BigQuery Table (Staging) | `medicaid_raw` | Raw API data |
| BigQuery Table (Enriched) | `enriched_drug_data` | Processed data |
| Dataproc Cluster | `medicaid-processing-cluster` | PySpark processing |
| GKE Cluster | `medicaid-dashboard-cluster` | Dashboard hosting |
| Service Account | `data-pipeline-sa` | Pipeline execution |

## 🚨 Troubleshooting

### Dashboard Issues

```powershell
cd dashboard

# Check status
.\manage-dashboard.ps1 -Action status

# View logs
.\manage-dashboard.ps1 -Action logs

# Verify setup
.\verify-setup.ps1

# Restart
.\manage-dashboard.ps1 -Action restart
```

### Authentication Issues

```powershell
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Verify service account permissions
gcloud projects get-iam-policy gcp-project-deliverable
```

### More Help

See detailed troubleshooting in:
- [dashboard/DEPLOYMENT.md](dashboard/DEPLOYMENT.md) - Deployment issues
- [dashboard/TOOLKIT.md](dashboard/TOOLKIT.md) - Script issues

## 💰 Cost Estimate

### Monthly Costs (Approximate)

| Service | Cost |
|---------|------|
| GKE (2 e2-standard-2 nodes) | ~$150 |
| Cloud Storage | ~$5 |
| BigQuery (storage + queries) | ~$10-20 |
| Dataproc (on-demand) | ~$5-10 |
| LoadBalancer | ~$18 |
| Cloud Build | Free tier |
| **Total** | **~$190-200/month** |

### Cost Optimization

```powershell
# Scale down when not in use
.\dashboard\manage-dashboard.ps1 -Action scale -Replicas 0

# Use smaller machines
--machine-type=e2-small

# Delete cluster when not needed
gcloud container clusters delete medicaid-dashboard-cluster --region=us-central1
```

## 🔐 Security

### Implemented
- ✅ Workload Identity (no service account keys)
- ✅ Least privilege IAM roles
- ✅ Secrets excluded from Git/Docker
- ✅ Resource limits on pods
- ✅ Health checks

### Recommended Enhancements
- [ ] Enable HTTPS with managed certificates
- [ ] Add Cloud IAP for authentication
- [ ] Use Secret Manager
- [ ] Configure VPC Service Controls
- [ ] Enable Binary Authorization

## 🎓 Next Steps

1. ✅ **Deploy Dashboard:** `cd dashboard && .\deploy-gke.ps1`
2. ⬜ **Add HTTPS:** Configure Ingress with SSL
3. ⬜ **Add Authentication:** Use Cloud IAP
4. ⬜ **Set up Monitoring:** Enable Cloud Monitoring
5. ⬜ **Add CI/CD:** Automate with Cloud Build triggers
6. ⬜ **Optimize Costs:** Right-size resources

## 📞 Support

For issues:
1. Check documentation (QUICKSTART, README, DEPLOYMENT, TOOLKIT)
2. Run `.\dashboard\verify-setup.ps1`
3. View logs: `.\dashboard\manage-dashboard.ps1 -Action logs`
4. Check GCP Console for service status

## 🏆 Key Features

- ✅ Production-grade data pipeline
- ✅ Automated with Airflow/Composer
- ✅ Scalable processing with Dataproc
- ✅ Interactive Streamlit dashboard
- ✅ Kubernetes deployment (GKE)
- ✅ Secure Workload Identity
- ✅ Auto-scaling and health checks
- ✅ **No Docker required** (Cloud Build)
- ✅ Easy management scripts
- ✅ Comprehensive documentation

---

**Ready to deploy?** Start here: [dashboard/QUICKSTART.md](dashboard/QUICKSTART.md)
│   ├── README.md                        # Complete dashboard docs
│   ├── DEPLOYMENT.md                    # Detailed deployment
│   └── TOOLKIT.md                       # Complete script reference
│
├── scripts/
│   ├── setup-gcs.sh                     # GCS bucket setup
│   ├── setup-bigquery.sh                # BigQuery setup
│   └── setup-dataproc.sh                # Dataproc setup
│
├── cloudbuild.yaml                      # Cloud Build config
├── .gitignore                           # Git exclusions
└── README.md                            # This file
```

## � Quick Start

### Prerequisites

- ✅ Google Cloud SDK (`gcloud`) installed - [Download](https://cloud.google.com/sdk/docs/install)
- ✅ Authenticated with GCP: `gcloud auth login`
- ✅ Project ID: `gcp-project-deliverable`
- ❌ **Docker NOT required!** (Uses Cloud Build)

### Deploy Dashboard (5 Minutes)

```powershell
cd dashboard

# 1. Verify setup
.\verify-setup.ps1

# 2. Deploy (builds remotely, no Docker needed!)
.\deploy-gke.ps1

# 3. Access dashboard at http://<EXTERNAL-IP>:8501
```

**See [dashboard/QUICKSTART.md](dashboard/QUICKSTART.md) for detailed instructions.**

## 📊 Data Flow

### 1. Extraction (Airflow DAG)
**File:** `composer/dags/medicaid_data_dag.py`
- Pulls data from Medicaid Drug Pricing API
- Stores raw JSON in Cloud Storage
- Loads to BigQuery staging table

### 2. Enrichment (Dataproc PySpark)
**File:** `dataproc/data_processing_job.py`
- Parses drug names into components (name, strength, form)
- Explodes explanation codes
- Writes enriched data to BigQuery

**DAG:** `composer/dags/medicaid_enrichment_dag.py`

### 3. Visualization (Streamlit on GKE)
**File:** `dashboard/app.py`
- Interactive charts (bar, pie, line, scatter)
- Dynamic filters
- Real-time BigQuery queries

## 🎨 Dashboard Features

- **Real-time BigQuery Integration**
- **Multiple Visualizations:**
  - Bar chart: Average price by drug
  - Pie chart: Top 10 drugs + others
  - Line chart: Price trends over time
  - Scatter plot: Price vs. dosage
- **Interactive Filters** (drug, date, dosage form)
- **Secure Authentication** (Workload Identity)
- **Auto-scaling** (1-4 replicas)

## 🛠️ Management Scripts

All scripts are in the `dashboard/` directory:

```powershell
cd dashboard

# Verify prerequisites
.\verify-setup.ps1

# Build Docker image (uses Cloud Build, no local Docker!)
.\build-image.ps1

# Deploy everything to GKE
.\deploy-gke.ps1

# Daily operations
.\manage-dashboard.ps1 -Action status      # Check status
.\manage-dashboard.ps1 -Action logs        # View logs
.\manage-dashboard.ps1 -Action restart     # Restart
.\manage-dashboard.ps1 -Action scale -Replicas 3   # Scale
.\manage-dashboard.ps1 -Action url         # Get URL
```

## 📖 Documentation

### Dashboard
- **[QUICKSTART.md](dashboard/QUICKSTART.md)** - 5-minute deployment guide ⚡
- **[README.md](dashboard/README.md)** - Complete dashboard documentation
- **[DEPLOYMENT.md](dashboard/DEPLOYMENT.md)** - Detailed deployment instructions
- **[TOOLKIT.md](dashboard/TOOLKIT.md)** - Complete script reference

### Pipeline
- **[Dataproc Job](dataproc/data_processing_job.py)** - PySpark enrichment logic
- **[Extraction DAG](composer/dags/medicaid_data_dag.py)** - API extraction
- **[Enrichment DAG](composer/dags/medicaid_enrichment_dag.py)** - Data processing  
- Node.js installed (for React dashboard)

## Service Account Permissions

The service account needs the following roles:
- Storage Admin
- Pub/Sub Admin
- Cloud Functions Admin
- BigQuery Admin
- Dataproc Editor
- Kubernetes Engine Admin
- Composer Worker
