# Medicaid Dashboard

Interactive Streamlit dashboard for visualizing Medicaid drug pricing data from BigQuery.

## Features

- **Real-time BigQuery Integration**: Queries enriched Medicaid data directly from BigQuery
- **Multiple Visualizations**:
  - Bar chart: Average price by drug
  - Pie chart: Top 10 drugs by price + others
  - Line chart: Price trends over time
  - Scatter plot: Price vs. dosage correlation
- **Interactive Filters**: Drug, date range, and dosage form selection
- **Responsive Design**: Modern, clean UI with sidebar controls
- **Secure Authentication**: Supports Workload Identity (GKE) and service account keys (local dev)

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│  Streamlit  │─────▶│  BigQuery    │─────▶│  Medicaid   │
│  Dashboard  │      │  (enriched)  │      │  API Data   │
└─────────────┘      └──────────────┘      └─────────────┘
      │
      ▼
┌─────────────────────────────────────────────────────┐
│  GKE (Kubernetes) with Workload Identity            │
│  ├── Deployment (2 replicas, auto-scaling)          │
│  ├── LoadBalancer Service (external access)         │
│  └── Health checks (liveness/readiness probes)      │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Local Development

1. **Install dependencies:**
   ```powershell
   pip install -r requirements.txt
   ```

2. **Set up authentication:**
   ```powershell
   # Option 1: Use Application Default Credentials (recommended)
   gcloud auth application-default login
   
   # Option 2: Use service account key (not recommended)
   $env:GOOGLE_APPLICATION_CREDENTIALS="service_account_secret\gcp-project-deliverable-*.json"
   ```

3. **Run the dashboard:**
   ```powershell
   streamlit run app.py
   ```

4. **Access:** http://localhost:8501

### Deploy to GKE (Production)

**No Docker installation required!** We use Cloud Build to build images remotely.

1. **Verify setup:**
   ```powershell
   .\verify-setup.ps1
   ```

2. **Deploy (one command):**
   ```powershell
   .\deploy-gke.ps1
   ```

   This will:
   - Build image using Cloud Build (remote)
   - Create GKE cluster
   - Set up Workload Identity
   - Deploy application
   - Expose via LoadBalancer

3. **Access:** Wait for external IP, then visit http://<EXTERNAL-IP>:8501

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

## Project Structure

```
dashboard/
├── app.py                          # Main Streamlit application
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container definition
├── .dockerignore                   # Exclude files from Docker build
│
├── k8s/                            # Kubernetes manifests
│   ├── deployment.yaml             # App deployment (replicas, resources)
│   └── service.yaml                # LoadBalancer service
│
├── deploy-gke.ps1                  # Full deployment script (Windows)
├── build-image.ps1                 # Build image only (Windows)
├── verify-setup.ps1                # Pre-deployment checks
├── DEPLOYMENT.md                   # Detailed deployment guide
├── README.md                       # This file
│
└── service_account_secret/         # Local dev only (not in Git)
    └── *.json                      # Service account key
```

## Configuration

### Environment Variables

The dashboard supports multiple authentication methods (in order of precedence):

1. **Workload Identity (GKE)**: Automatic, no configuration needed
2. **SERVICE_ACCOUNT_SECRET**: Path to service account JSON key
3. **GOOGLE_APPLICATION_CREDENTIALS**: Standard GCP environment variable
4. **Local Secret File**: Searches `service_account_secret/` directory

Example:
```powershell
# For local development
$env:SERVICE_ACCOUNT_SECRET="C:\path\to\service-account.json"
```

### BigQuery Configuration

Default configuration (modify in `app.py` if needed):
```python
PROJECT_ID = "gcp-project-deliverable"
DATASET_ID = "medicaid_data"
TABLE_ID = "enriched_drug_data"
```

## Authentication Methods

### 1. Workload Identity (GKE - Recommended)

Automatically configured by deployment script. No keys needed!

**Pros:**
- No service account keys to manage
- Automatic credential rotation
- Most secure

**Setup:** Handled by `deploy-gke.ps1`

### 2. Application Default Credentials (Local Dev)

```powershell
gcloud auth application-default login
```

**Pros:**
- No key files needed
- Uses your GCP account credentials

**Cons:**
- Requires gcloud CLI

### 3. Service Account Key (Local Dev)

```powershell
# Set environment variable
$env:GOOGLE_APPLICATION_CREDENTIALS="service_account_secret\key.json"

# Or use SERVICE_ACCOUNT_SECRET
$env:SERVICE_ACCOUNT_SECRET="service_account_secret\key.json"
```

**Pros:**
- Works without gcloud CLI

**Cons:**
- Must secure key file
- Manual key rotation

## Development

### Run Locally

```powershell
# Install dependencies
pip install -r requirements.txt

# Authenticate
gcloud auth application-default login

# Run app
streamlit run app.py

# App will open at http://localhost:8501
```

### Test BigQuery Connection

```python
from google.cloud import bigquery

client = bigquery.Client(project="gcp-project-deliverable")
query = "SELECT COUNT(*) as count FROM `medicaid_data.enriched_drug_data`"
result = client.query(query).result()
print(f"Row count: {list(result)[0].count}")
```

### Modify Visualizations

Edit `app.py` sections:
- **Filters**: Update sidebar controls
- **Charts**: Modify chart functions (`create_bar_chart`, etc.)
- **Queries**: Update SQL queries in chart functions

### Hot Reload

Streamlit automatically reloads on file changes. Just save `app.py` and refresh browser.

## Deployment

### Build Image (Cloud Build - No Docker Needed)

```powershell
.\build-image.ps1
```

Builds remotely on GCP using Cloud Build. No local Docker required!

### Deploy to GKE

```powershell
# Full deployment
.\deploy-gke.ps1

# Or step-by-step (see DEPLOYMENT.md)
```

### Update Existing Deployment

```powershell
# 1. Rebuild image
.\build-image.ps1 -ImageTag "v1.1"

# 2. Update deployment
kubectl set image deployment/medicaid-dashboard `
  medicaid-dashboard=gcr.io/gcp-project-deliverable/medicaid-dashboard:v1.1

# Or restart with latest
kubectl rollout restart deployment/medicaid-dashboard
```

### Monitor Deployment

```powershell
# View pods
kubectl get pods

# View logs
kubectl logs -l app=medicaid-dashboard

# View service
kubectl get service medicaid-dashboard-service

# Follow logs in real-time
kubectl logs -f -l app=medicaid-dashboard
```

## Troubleshooting

### Issue: "No data available"

**Cause:** BigQuery table empty or authentication failed

**Fix:**
```powershell
# Check authentication
gcloud auth application-default login

# Verify table exists and has data
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM medicaid_data.enriched_drug_data"

# Check dashboard logs
kubectl logs -l app=medicaid-dashboard
```

### Issue: "Permission denied" errors

**Cause:** Service account lacks BigQuery permissions

**Fix:**
```powershell
gcloud projects add-iam-policy-binding gcp-project-deliverable `
  --member="serviceAccount:data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com" `
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding gcp-project-deliverable `
  --member="serviceAccount:data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com" `
  --role="roles/bigquery.jobUser"
```

### Issue: Pod crashes (CrashLoopBackOff)

**Cause:** Application error or missing dependencies

**Fix:**
```powershell
# Check pod logs
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Common issues:
# - Missing package: Update requirements.txt and rebuild
# - Import error: Check Python version in Dockerfile
# - BigQuery error: Verify authentication and permissions
```

### Issue: Can't access external IP

**Cause:** LoadBalancer not created or firewall rules

**Fix:**
```powershell
# Check service status
kubectl get service medicaid-dashboard-service

# Wait for external IP (may take 5 minutes)
kubectl get service medicaid-dashboard-service --watch

# Check GCP firewall rules
gcloud compute firewall-rules list --filter="name~gke"
```

## Performance Optimization

### Query Optimization

```python
# Use table partitioning in BigQuery
# Use query cache
# Limit rows with WHERE clauses
# Use LIMIT for testing

# Example optimized query
query = f"""
    SELECT drug_name, AVG(pricing) as avg_price
    FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    WHERE quarter = '2024Q1'  -- Partition filter
    GROUP BY drug_name
    ORDER BY avg_price DESC
    LIMIT 100
"""
```

### Caching

Add Streamlit caching to expensive operations:

```python
@st.cache_data(ttl=3600)  # Cache for 1 hour
def load_data():
    query = "SELECT * FROM ..."
    return client.query(query).to_dataframe()
```

### Resource Limits

Current limits (in `k8s/deployment.yaml`):
- Memory: 512Mi request, 1Gi limit
- CPU: 250m request, 500m limit

Adjust based on usage:
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Security

### Best Practices

1. ✅ **Use Workload Identity** (no service account keys)
2. ✅ **Never commit secrets** (.gitignore configured)
3. ✅ **Use least privilege** (BigQuery dataViewer only)
4. ⚠️ **Add HTTPS** (use Ingress with SSL for production)
5. ⚠️ **Network policies** (restrict pod-to-pod traffic)
6. ⚠️ **Private GKE cluster** (no public IPs for nodes)

### Production Checklist

- [ ] Enable HTTPS/TLS with managed certificate
- [ ] Set up Cloud Armor for DDoS protection
- [ ] Configure Cloud IAP for authentication
- [ ] Enable GKE logging and monitoring
- [ ] Set up alerting for errors/downtime
- [ ] Use private GKE cluster
- [ ] Implement network policies
- [ ] Regular security audits with `gcloud` binary authorization

## Monitoring

### View Logs

```powershell
# Real-time logs
kubectl logs -f -l app=medicaid-dashboard

# Last 100 lines
kubectl logs -l app=medicaid-dashboard --tail=100

# Logs from specific pod
kubectl logs <pod-name>
```

### GCP Logging

```powershell
# Enable GKE monitoring
gcloud container clusters update medicaid-dashboard-cluster `
  --enable-cloud-logging `
  --enable-cloud-monitoring `
  --region=us-central1
```

View in GCP Console:
- Logs: https://console.cloud.google.com/logs
- Metrics: https://console.cloud.google.com/monitoring

### Health Checks

Dashboard includes health endpoints:
- Liveness: `/healthz` (Streamlit running)
- Readiness: `/healthz` (ready for traffic)

Configured in `k8s/deployment.yaml`.

## Cost Estimation

### Monthly Cost (Approximate)

- **GKE Cluster**: ~$150/month
  - 2 x e2-standard-2 nodes (2 vCPU, 8GB RAM each)
- **LoadBalancer**: ~$18/month
- **Cloud Build**: Free tier (120 build-minutes/day)
- **Container Registry**: ~$0.10/GB/month (minimal)
- **BigQuery**: Pay per query (usually < $10/month for this use case)

**Total**: ~$170-180/month

### Cost Optimization

```powershell
# Use smaller nodes
--machine-type=e2-small  # ~$50/month savings

# Use Autopilot (pay per pod, not per node)
gcloud container clusters create-auto medicaid-dashboard-cluster

# Scale down when not in use
kubectl scale deployment/medicaid-dashboard --replicas=0  # Stop all pods
kubectl scale deployment/medicaid-dashboard --replicas=2  # Start again
```

## Next Steps

1. ✅ **Deploy to GKE** - Use `deploy-gke.ps1`
2. ⬜ **Add HTTPS** - Configure Ingress with SSL
3. ⬜ **Add Authentication** - Use Cloud IAP or OAuth
4. ⬜ **Add Caching** - Use Redis for query caching
5. ⬜ **Add More Charts** - Extend visualizations
6. ⬜ **Add CI/CD** - Automate deployments with Cloud Build triggers

## Resources

- [Streamlit Documentation](https://docs.streamlit.io/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Deployment Guide](DEPLOYMENT.md)

## Support

For issues or questions:
1. Check [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions
2. Review error logs: `kubectl logs -l app=medicaid-dashboard`
3. Check GCP Console for BigQuery/GKE status
4. Verify authentication and permissions

## License

Internal project - All rights reserved
