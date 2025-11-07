# 🚀 Quick Start Guide - No Docker Required!

## For Windows Users Without Docker

Since you don't have Docker installed, we'll use **Cloud Build** to build the image remotely on GCP. This is actually a best practice for production deployments!

## Prerequisites

✅ **Required:**
- Google Cloud SDK (`gcloud`) - [Download here](https://cloud.google.com/sdk/docs/install)
- Authenticated with GCP: `gcloud auth login`

✅ **Auto-installed:**
- `kubectl` (installed via: `gcloud components install kubectl`)

## Deployment Steps (5 minutes)

### Step 1: Verify Your Setup
```powershell
cd dashboard
.\verify-setup.ps1
```

This checks:
- ✓ gcloud installed
- ✓ kubectl installed  
- ✓ GCP authentication
- ✓ Service account exists
- ✓ Required files present

### Step 2: Deploy Everything
```powershell
.\deploy-gke.ps1
```

**What this does:**
1. 🏗️ Builds Docker image on GCP (Cloud Build)
2. 📦 Pushes to Google Container Registry
3. ☸️ Creates GKE cluster (if needed)
4. 🔐 Sets up Workload Identity (secure, keyless auth)
5. 🚀 Deploys dashboard
6. 🌐 Creates LoadBalancer for external access

**Time:** ~10-15 minutes first time, ~5 minutes for updates

### Step 3: Access Dashboard
The script will output:
```
Dashboard URL: http://<EXTERNAL-IP>:8501
```

Open this URL in your browser!

## That's It! 🎉

No Docker, no complicated setup. Everything runs on GCP.

---

## Alternative: Step-by-Step Deployment

If you prefer more control:

### 1. Build Image Only
```powershell
.\build-image.ps1
```
Builds remotely using Cloud Build. No local Docker needed!

### 2. Create GKE Cluster
```powershell
gcloud container clusters create medicaid-dashboard-cluster `
  --region=us-central1 `
  --num-nodes=2 `
  --machine-type=e2-standard-2 `
  --workload-pool=gcp-project-deliverable.svc.id.goog
```

### 3. Get Credentials
```powershell
gcloud container clusters get-credentials medicaid-dashboard-cluster --region=us-central1
```

### 4. Deploy App
```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 5. Get External IP
```powershell
kubectl get service medicaid-dashboard-service
```
Wait for EXTERNAL-IP to appear, then access at `http://<IP>:8501`

---

## Updating After Code Changes

```powershell
# Rebuild image
.\build-image.ps1

# Restart deployment to pull latest
kubectl rollout restart deployment/medicaid-dashboard
```

---

## Useful Commands

```powershell
# View running pods
kubectl get pods

# View logs (real-time)
kubectl logs -f -l app=medicaid-dashboard

# Check service status
kubectl get service medicaid-dashboard-service

# Scale replicas
kubectl scale deployment/medicaid-dashboard --replicas=3
```

---

## Troubleshooting

### "gcloud: command not found"
Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install

### "Not authenticated"
Run: `gcloud auth login`

### "kubectl: command not found"
Run: `gcloud components install kubectl`

### "Permission denied"
Ensure service account has BigQuery permissions:
```powershell
gcloud projects add-iam-policy-binding gcp-project-deliverable `
  --member="serviceAccount:data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com" `
  --role="roles/bigquery.dataViewer"
```

### Build fails
Check Cloud Build logs:
```powershell
gcloud builds list --limit=5
gcloud builds log <BUILD-ID>
```

---

## Cost

Approximately **$170-180/month** for:
- GKE cluster (2 nodes)
- LoadBalancer
- Cloud Build (free tier)
- Container Registry (minimal storage)

**To reduce costs:**
- Use `--machine-type=e2-small` (saves ~$50/month)
- Scale to 0 when not in use: `kubectl scale deployment/medicaid-dashboard --replicas=0`

---

## Next Steps

- ✅ **Deploy**: Run `.\deploy-gke.ps1`
- ⬜ **Add HTTPS**: Configure Ingress with SSL
- ⬜ **Add Authentication**: Use Cloud IAP
- ⬜ **Add Monitoring**: Enable GKE monitoring/logging
- ⬜ **Add CI/CD**: Automate with Cloud Build triggers

---

## Documentation

- **README.md** - Full dashboard documentation
- **DEPLOYMENT.md** - Detailed deployment guide
- **Scripts:**
  - `deploy-gke.ps1` - Full deployment
  - `build-image.ps1` - Build image only
  - `verify-setup.ps1` - Pre-deployment checks

---

## Why No Docker Locally?

**Benefits of Cloud Build:**
- ✅ No Docker installation needed
- ✅ Consistent build environment
- ✅ Faster builds (uses GCP infrastructure)
- ✅ Better security (no local Docker daemon)
- ✅ Easier CI/CD integration
- ✅ Free tier (120 build-minutes/day)

This is actually the **recommended approach** for production deployments!

---

## Support

Issues? Check:
1. `.\verify-setup.ps1` - Validates prerequisites
2. `kubectl logs -l app=medicaid-dashboard` - Application logs
3. `gcloud builds list` - Build history
4. **DEPLOYMENT.md** - Detailed troubleshooting guide
