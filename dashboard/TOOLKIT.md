# Dashboard Deployment - Complete Toolkit

## 📋 Overview

You now have a complete toolkit for deploying and managing your Medicaid Dashboard on GKE **without requiring Docker to be installed locally**. All Docker image builds are done remotely using Google Cloud Build.

## 🛠️ Available Scripts

### 1. `verify-setup.ps1` - Pre-Deployment Checks
```powershell
.\verify-setup.ps1
```
**Purpose:** Validates your environment before deployment
**Checks:**
- ✅ gcloud CLI installed
- ✅ kubectl installed
- ✅ GCP authentication status
- ✅ Project configuration
- ✅ Required files present
- ✅ Service account exists
- ✅ Required APIs enabled
- ✅ BigQuery dataset exists

**When to use:** Before first deployment or when troubleshooting

---

### 2. `build-image.ps1` - Build Docker Image
```powershell
.\build-image.ps1
# Or with specific tag:
.\build-image.ps1 -ImageTag "v1.2"
```
**Purpose:** Build Docker image using Cloud Build (no local Docker needed!)
**What it does:**
- Builds image remotely on GCP
- Pushes to Google Container Registry
- Tags as both specified version and "latest"

**When to use:** 
- After code changes
- Before deploying updates
- Testing new features

**No Docker installation required!** ✨

---

### 3. `deploy-gke.ps1` - Full Deployment
```powershell
.\deploy-gke.ps1
```
**Purpose:** Complete end-to-end deployment
**What it does:**
1. Builds Docker image (Cloud Build)
2. Creates/updates GKE cluster
3. Configures Workload Identity
4. Deploys application
5. Creates LoadBalancer
6. Returns dashboard URL

**When to use:**
- First-time deployment
- Complete redeployment
- Setting up new environment

**Time:** 10-15 minutes (first run), 5 minutes (updates)

---

### 4. `manage-dashboard.ps1` - Daily Operations
```powershell
# Check status
.\manage-dashboard.ps1 -Action status

# View real-time logs
.\manage-dashboard.ps1 -Action logs

# Restart deployment
.\manage-dashboard.ps1 -Action restart

# Scale replicas
.\manage-dashboard.ps1 -Action scale -Replicas 3

# Get dashboard URL
.\manage-dashboard.ps1 -Action url

# Delete deployment (keeps cluster)
.\manage-dashboard.ps1 -Action delete

# Show help
.\manage-dashboard.ps1 -Action help
```
**Purpose:** Manage running dashboard
**When to use:** Daily operations, troubleshooting, scaling

---

## 📚 Documentation

### `QUICKSTART.md` - Fast Track Guide
- 5-minute deployment guide
- No Docker required approach
- Quick commands reference
- Common troubleshooting

### `README.md` - Complete Documentation
- Architecture overview
- Feature descriptions
- Local development setup
- Authentication methods
- Performance optimization
- Security best practices
- Cost estimation
- Monitoring guide

### `DEPLOYMENT.md` - Detailed Deployment Guide
- Step-by-step instructions
- Alternative deployment methods
- Update procedures
- Troubleshooting scenarios
- Production enhancements
- Cost optimization tips

### `TOOLKIT.md` - This File
- Script reference
- Workflow examples
- Best practices

---

## 🚀 Common Workflows

### First-Time Deployment

```powershell
# 1. Verify setup
cd dashboard
.\verify-setup.ps1

# 2. Deploy everything
.\deploy-gke.ps1

# 3. Get URL
.\manage-dashboard.ps1 -Action url

# 4. Check status
.\manage-dashboard.ps1 -Action status
```

---

### Update After Code Changes

```powershell
# 1. Rebuild image
.\build-image.ps1

# 2. Restart deployment
.\manage-dashboard.ps1 -Action restart

# 3. Check logs
.\manage-dashboard.ps1 -Action logs
```

---

### Daily Monitoring

```powershell
# Check health
.\manage-dashboard.ps1 -Action status

# View logs
.\manage-dashboard.ps1 -Action logs

# Get URL
.\manage-dashboard.ps1 -Action url
```

---

### Scale for High Traffic

```powershell
# Scale up
.\manage-dashboard.ps1 -Action scale -Replicas 5

# Check status
.\manage-dashboard.ps1 -Action status

# Scale down
.\manage-dashboard.ps1 -Action scale -Replicas 2
```

---

### Troubleshooting Issues

```powershell
# 1. Check status
.\manage-dashboard.ps1 -Action status

# 2. View logs
.\manage-dashboard.ps1 -Action logs

# 3. Verify setup
.\verify-setup.ps1

# 4. Restart if needed
.\manage-dashboard.ps1 -Action restart
```

---

### Cost Optimization (Scale to Zero)

```powershell
# Stop all pods (no cost)
.\manage-dashboard.ps1 -Action scale -Replicas 0

# Later, start again
.\manage-dashboard.ps1 -Action scale -Replicas 2
```

---

## 🎯 Best Practices

### ✅ DO

1. **Always verify setup first**
   ```powershell
   .\verify-setup.ps1
   ```

2. **Use Cloud Build (no local Docker)**
   ```powershell
   .\build-image.ps1
   ```

3. **Check logs after deployment**
   ```powershell
   .\manage-dashboard.ps1 -Action logs
   ```

4. **Tag images for versioning**
   ```powershell
   .\build-image.ps1 -ImageTag "v1.2.3"
   ```

5. **Monitor resource usage**
   ```powershell
   kubectl top pods
   kubectl top nodes
   ```

### ❌ DON'T

1. **Don't skip verification**
   - Always run `verify-setup.ps1` first

2. **Don't commit secrets**
   - `.gitignore` is configured, but double-check

3. **Don't use local Docker**
   - Cloud Build is faster and more consistent

4. **Don't forget to scale down**
   - Save costs when not in use

5. **Don't deploy untested changes**
   - Test locally with `streamlit run app.py` first

---

## 🔧 Manual Commands (Advanced)

### Build & Deploy
```powershell
# Manual Cloud Build
gcloud builds submit `
  --config=..\cloudbuild.yaml `
  --substitutions=TAG_NAME=v1.0

# Manual kubectl apply
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Cluster Management
```powershell
# Get credentials
gcloud container clusters get-credentials medicaid-dashboard-cluster --region=us-central1

# List clusters
gcloud container clusters list

# Describe cluster
gcloud container clusters describe medicaid-dashboard-cluster --region=us-central1
```

### Image Management
```powershell
# List images
gcloud container images list --repository=gcr.io/gcp-project-deliverable

# Delete old images
gcloud container images delete gcr.io/gcp-project-deliverable/medicaid-dashboard:old-tag
```

### Workload Identity
```powershell
# Check bindings
gcloud iam service-accounts get-iam-policy `
  data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com

# Verify annotation
kubectl get serviceaccount dashboard-ksa -o yaml
```

---

## 📊 Monitoring & Logs

### Quick Checks
```powershell
# Pod status
kubectl get pods -l app=medicaid-dashboard

# Service status
kubectl get service medicaid-dashboard-service

# Deployment status
kubectl get deployment medicaid-dashboard
```

### Detailed Logs
```powershell
# Real-time logs (all pods)
kubectl logs -f -l app=medicaid-dashboard

# Logs from specific pod
kubectl logs <pod-name>

# Previous container logs (if pod crashed)
kubectl logs <pod-name> --previous

# Logs from last hour
kubectl logs <pod-name> --since=1h
```

### Cloud Logging
```powershell
# View in GCP Console
start https://console.cloud.google.com/logs/query

# Query via CLI
gcloud logging read "resource.type=k8s_container AND resource.labels.cluster_name=medicaid-dashboard-cluster" --limit 50
```

---

## 💰 Cost Management

### Current Configuration
- **Cluster:** 2 x e2-standard-2 nodes (~$150/month)
- **LoadBalancer:** ~$18/month
- **Cloud Build:** Free tier (120 min/day)
- **GCR:** ~$0.10/GB/month
- **Total:** ~$170-180/month

### Reduce Costs

#### Option 1: Smaller Nodes
```powershell
gcloud container clusters create medicaid-dashboard-cluster `
  --machine-type=e2-small  # Saves ~$50/month
```

#### Option 2: Autopilot (Pay Per Pod)
```powershell
gcloud container clusters create-auto medicaid-dashboard-cluster
```

#### Option 3: Scale to Zero When Not in Use
```powershell
# Stop
.\manage-dashboard.ps1 -Action scale -Replicas 0

# Start
.\manage-dashboard.ps1 -Action scale -Replicas 2
```

#### Option 4: Delete Cluster When Not Needed
```powershell
# Delete cluster (can recreate anytime)
gcloud container clusters delete medicaid-dashboard-cluster --region=us-central1

# Recreate later with
.\deploy-gke.ps1
```

---

## 🔐 Security Checklist

- [x] Workload Identity configured (no service account keys)
- [x] Service account has minimum required permissions
- [x] Secrets excluded from Git (.gitignore)
- [x] Secrets excluded from Docker image (.dockerignore)
- [x] Resource limits configured (prevent DoS)
- [ ] HTTPS/TLS enabled (use Ingress + managed cert)
- [ ] Network policies (restrict pod traffic)
- [ ] Private GKE cluster (no public node IPs)
- [ ] Cloud Armor (DDoS protection)
- [ ] Cloud IAP (authentication)

---

## 🆘 Troubleshooting Guide

### Issue: "gcloud not found"
```powershell
# Install Google Cloud SDK
# https://cloud.google.com/sdk/docs/install
```

### Issue: "Not authenticated"
```powershell
gcloud auth login
gcloud auth application-default login
```

### Issue: "Permission denied"
```powershell
# Grant BigQuery permissions
gcloud projects add-iam-policy-binding gcp-project-deliverable `
  --member="serviceAccount:data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com" `
  --role="roles/bigquery.dataViewer"
```

### Issue: "Pod CrashLoopBackOff"
```powershell
# Check logs
kubectl logs <pod-name>
kubectl describe pod <pod-name>

# Common fixes:
# - Missing dependency: Update requirements.txt, rebuild
# - Import error: Check Python version in Dockerfile
# - Auth error: Verify Workload Identity
```

### Issue: "Image pull error"
```powershell
# Ensure GCR access
gcloud auth configure-docker

# Check image exists
gcloud container images list --repository=gcr.io/gcp-project-deliverable
```

### Issue: "No external IP"
```powershell
# Wait (can take 5 minutes)
kubectl get service medicaid-dashboard-service --watch

# Check LoadBalancer quota
gcloud compute project-info describe --project=gcp-project-deliverable
```

---

## 📞 Support Resources

- **Scripts:** All scripts include `--help` or `-Action help`
- **Docs:** README.md, DEPLOYMENT.md, QUICKSTART.md
- **Logs:** `.\manage-dashboard.ps1 -Action logs`
- **Status:** `.\manage-dashboard.ps1 -Action status`
- **GCP Console:** https://console.cloud.google.com
- **GKE Docs:** https://cloud.google.com/kubernetes-engine/docs
- **Streamlit Docs:** https://docs.streamlit.io

---

## ✨ Why This Approach Works

### No Docker Needed
- ✅ Cloud Build handles all image building
- ✅ Consistent build environment
- ✅ Faster builds (GCP infrastructure)
- ✅ Better security (no local Docker daemon)
- ✅ Easier CI/CD integration

### Production-Ready
- ✅ Workload Identity (keyless authentication)
- ✅ Auto-scaling (1-4 nodes)
- ✅ Health checks (liveness/readiness)
- ✅ Resource limits (prevent exhaustion)
- ✅ LoadBalancer (external access)

### Developer-Friendly
- ✅ PowerShell scripts for Windows
- ✅ One-command deployment
- ✅ Easy updates and rollbacks
- ✅ Comprehensive documentation
- ✅ Built-in troubleshooting

---

## 🎓 Next Steps

1. ✅ **Deploy:** `.\deploy-gke.ps1`
2. ⬜ **Monitor:** Set up alerts and dashboards
3. ⬜ **Secure:** Add HTTPS and authentication
4. ⬜ **Optimize:** Add caching and query optimization
5. ⬜ **Automate:** Set up CI/CD pipeline
6. ⬜ **Scale:** Add horizontal pod autoscaling

---

## 📄 File Index

```
dashboard/
├── app.py                      # Streamlit application
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Container definition
├── .dockerignore              # Docker build exclusions
│
├── k8s/
│   ├── deployment.yaml        # Kubernetes deployment
│   └── service.yaml           # LoadBalancer service
│
├── Scripts/
│   ├── verify-setup.ps1       # Pre-deployment checks
│   ├── build-image.ps1        # Build Docker image
│   ├── deploy-gke.ps1         # Full deployment
│   └── manage-dashboard.ps1   # Daily operations
│
└── Documentation/
    ├── QUICKSTART.md          # 5-minute guide
    ├── README.md              # Complete docs
    ├── DEPLOYMENT.md          # Detailed deployment
    └── TOOLKIT.md             # This file
```

---

**Ready to deploy?** Start with `.\verify-setup.ps1` then `.\deploy-gke.ps1`!
