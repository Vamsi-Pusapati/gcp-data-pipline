# 🚀 Deploy from Google Cloud Console (Cloud Shell)

## Why Use Cloud Shell?

✅ **Pre-installed tools** (gcloud, kubectl, docker, git)  
✅ **No local setup needed**  
✅ **Free to use** (5 GB persistent storage)  
✅ **Direct access to GCP**  
✅ **Works from any browser**

---

## 📋 Quick Start (5 Steps)

### **Step 1: Open Cloud Shell**
1. Go to https://console.cloud.google.com
2. Click the **Activate Cloud Shell** icon (>_) in the top-right corner
3. Wait for Cloud Shell to initialize (~30 seconds)

### **Step 2: Upload Project Files**

**Option A: Upload via Cloud Shell Editor**
```bash
# Click "Open Editor" button in Cloud Shell
# Then drag and drop the entire 'dashboard' folder
```

**Option B: Upload via Command Line**
```bash
# In Cloud Shell, click the ⋮ (More) menu → "Upload"
# Upload these files:
# - All files from dashboard/ directory
# - cloudbuild.yaml (from parent directory)
```

**Option C: Clone from Git (if you have a repo)**
```bash
git clone <your-repo-url>
cd GCS_Project/dashboard
```

### **Step 3: Make Script Executable**
```bash
chmod +x deploy-gke-cloudshell.sh
```

### **Step 4: Run Deployment**
```bash
./deploy-gke-cloudshell.sh
```

### **Step 5: Access Dashboard**
Once complete, you'll get a URL like:
```
✓ Dashboard URL: http://35.123.45.67:8501
```

**Time:** 15-20 minutes total

---

## 🎯 Alternative: Manual Step-by-Step

If you prefer to understand each step:

### **1. Set Project**
```bash
gcloud config set project gcp-project-deliverable
```

### **2. Enable APIs**
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable container.googleapis.com
```

### **3. Build Image (Cloud Build - No Docker Needed!)**
```bash
# Navigate to project root
cd ..

# Build with Cloud Build
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=TAG_NAME=latest \
  --timeout=20m

# Return to dashboard
cd dashboard
```

### **4. Create GKE Cluster**
```bash
gcloud container clusters create medicaid-dashboard-cluster \
  --region=us-central1 \
  --num-nodes=2 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=4 \
  --workload-pool=gcp-project-deliverable.svc.id.goog
```

### **5. Get Credentials**
```bash
gcloud container clusters get-credentials medicaid-dashboard-cluster --region=us-central1
```

### **6. Setup Workload Identity**
```bash
# Create Kubernetes service account
kubectl create serviceaccount dashboard-ksa

# Bind to GCP service account
gcloud iam service-accounts add-iam-policy-binding \
  data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:gcp-project-deliverable.svc.id.goog[default/dashboard-ksa]"

# Annotate
kubectl annotate serviceaccount dashboard-ksa \
  iam.gke.io/gcp-service-account=data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com
```

### **7. Deploy Application**
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### **8. Get External IP**
```bash
kubectl get service medicaid-dashboard-service

# Or wait for IP
kubectl get service medicaid-dashboard-service --watch
```

---

## 🛠️ Managing from Cloud Shell

### **Check Status**
```bash
kubectl get pods
kubectl get service medicaid-dashboard-service
```

### **View Logs**
```bash
kubectl logs -l app=medicaid-dashboard --tail=100
kubectl logs -f -l app=medicaid-dashboard  # Follow logs
```

### **Restart Deployment**
```bash
kubectl rollout restart deployment/medicaid-dashboard
kubectl rollout status deployment/medicaid-dashboard
```

### **Scale Replicas**
```bash
# Scale up
kubectl scale deployment/medicaid-dashboard --replicas=3

# Scale down
kubectl scale deployment/medicaid-dashboard --replicas=1

# Scale to zero (save costs)
kubectl scale deployment/medicaid-dashboard --replicas=0
```

### **Update After Code Changes**
```bash
# 1. Rebuild image
cd ..
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=TAG_NAME=v1.1 \
  --timeout=20m

# 2. Update deployment
cd dashboard
kubectl set image deployment/medicaid-dashboard \
  medicaid-dashboard=gcr.io/gcp-project-deliverable/medicaid-dashboard:v1.1

# Or restart to pull latest
kubectl rollout restart deployment/medicaid-dashboard
```

---

## 📁 Required Files in Cloud Shell

Make sure you have uploaded:

```
dashboard/
├── deploy-gke-cloudshell.sh    # Deployment script
├── app.py                      # Streamlit app
├── requirements.txt            # Dependencies
├── Dockerfile                  # Container config
├── .dockerignore               # Build exclusions
└── k8s/
    ├── deployment.yaml         # K8s deployment
    └── service.yaml            # LoadBalancer

../ (parent directory)
└── cloudbuild.yaml             # Cloud Build config
```

---

## 🎯 Upload Methods Compared

### **Method 1: Cloud Shell Upload (Easiest)**
```bash
# Click ⋮ menu → "Upload"
# Drag and drop files
```
- ✅ Easy for small projects
- ❌ Tedious for many files

### **Method 2: Cloud Shell Editor (Best for this project)**
```bash
# Click "Open Editor" button
# Drag entire folder into editor
```
- ✅ Upload entire directory at once
- ✅ Visual file browser
- ✅ Can edit files in browser

### **Method 3: Git Clone (Best for version control)**
```bash
git clone https://github.com/your-username/GCS_Project.git
cd GCS_Project/dashboard
```
- ✅ Complete project with history
- ✅ Easy to update
- ❌ Requires Git repository

### **Method 4: gsutil (For large files)**
```bash
# Upload from local to GCS
gsutil -m cp -r dashboard/ gs://your-bucket/

# Download in Cloud Shell
gsutil -m cp -r gs://your-bucket/dashboard/ .
```
- ✅ Good for large files
- ✅ Can resume interrupted uploads

---

## 🔍 Verification Steps

### **Before Deployment**
```bash
# Check files are uploaded
ls -la

# Verify cloudbuild.yaml exists in parent
ls -la ../cloudbuild.yaml

# Check project
gcloud config get-value project

# Check authentication
gcloud auth list
```

### **During Deployment**
```bash
# In another Cloud Shell tab, monitor build
gcloud builds list --limit=5

# View build logs
gcloud builds log <BUILD-ID>

# Watch pods
kubectl get pods --watch
```

### **After Deployment**
```bash
# Check all resources
kubectl get all

# Check service
kubectl get service medicaid-dashboard-service

# Test dashboard
curl http://<EXTERNAL-IP>:8501
```

---

## 🚨 Troubleshooting

### **"Permission denied" when running script**
```bash
chmod +x deploy-gke-cloudshell.sh
```

### **"cloudbuild.yaml not found"**
```bash
# Make sure you're in dashboard directory
pwd  # Should show: .../GCS_Project/dashboard

# Check if cloudbuild.yaml exists in parent
ls -la ../cloudbuild.yaml

# If missing, create it or upload it
```

### **"Project not set"**
```bash
gcloud config set project gcp-project-deliverable
```

### **"Service account not found"**
```bash
# Create it
gcloud iam service-accounts create data-pipeline-sa \
  --display-name="Data Pipeline Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding gcp-project-deliverable \
  --member="serviceAccount:data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"
```

### **"Build failed"**
```bash
# Check build logs
gcloud builds list
gcloud builds log <BUILD-ID>

# Common issues:
# - Missing files: Check all files uploaded
# - Syntax error: Check Dockerfile
# - Timeout: Increase timeout in cloudbuild.yaml
```

### **"Pod won't start"**
```bash
# Check pod status
kubectl get pods

# Describe pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common issues:
# - Image pull error: Check image exists in GCR
# - CrashLoopBackOff: Check application logs
# - Pending: Check cluster resources
```

---

## 💡 Pro Tips

### **1. Use Cloud Shell Editor**
```bash
# Click "Open Editor" to edit files visually
# Better than vim/nano for beginners
```

### **2. Split Terminal**
```bash
# Click "+" to open multiple terminals
# Monitor build in one, run commands in another
```

### **3. Persist Files**
```bash
# Cloud Shell home directory is persistent
# Store your project in ~/projects/
mkdir -p ~/projects
cd ~/projects
# Upload files here - they survive Cloud Shell restarts
```

### **4. Quick Reconnect**
```bash
# If Cloud Shell disconnects, reconnect with:
cd ~/projects/GCS_Project/dashboard
gcloud container clusters get-credentials medicaid-dashboard-cluster --region=us-central1
```

### **5. Boost Resources (if needed)**
```bash
# Click ⋮ menu → "Boost Cloud Shell"
# Temporarily increase CPU/RAM (free)
```

---

## 📊 Comparison: Cloud Shell vs Local

| Feature | Cloud Shell | Local (Windows) |
|---------|-------------|-----------------|
| **Docker** | ✅ Pre-installed | ❌ Need to install |
| **gcloud** | ✅ Pre-installed | ⚠️ Need to install |
| **kubectl** | ✅ Pre-installed | ⚠️ Need to install |
| **Storage** | ✅ 5GB persistent | ✅ Unlimited |
| **Speed** | ✅ Fast (in GCP) | ⚠️ Depends on internet |
| **Cost** | ✅ Free | ✅ Free |
| **Access** | ✅ Any browser | ❌ Specific computer |
| **Scripts** | ✅ Bash native | ⚠️ Need PowerShell |

**Recommendation:** Use **Cloud Shell** for deployment, **Local** for development.

---

## 🎯 Quick Commands Reference

```bash
# Deploy
./deploy-gke-cloudshell.sh

# Check status
kubectl get all

# View logs
kubectl logs -f -l app=medicaid-dashboard

# Get URL
kubectl get service medicaid-dashboard-service

# Restart
kubectl rollout restart deployment/medicaid-dashboard

# Scale
kubectl scale deployment/medicaid-dashboard --replicas=3

# Delete (cleanup)
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml
gcloud container clusters delete medicaid-dashboard-cluster --region=us-central1
```

---

## ✅ Success Checklist

- [ ] Cloud Shell opened
- [ ] Project files uploaded
- [ ] Script made executable (`chmod +x`)
- [ ] Project set (`gcloud config set project`)
- [ ] Deployment script run
- [ ] External IP obtained
- [ ] Dashboard accessible in browser

---

## 🎉 Done!

Once you see:
```
✓ Dashboard URL: http://35.123.45.67:8501
```

Open that URL in your browser and you're done! 🎊

---

**Questions?** Check:
- [QUICKSTART.md](QUICKSTART.md) - Alternative deployment methods
- [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed troubleshooting
- [README.md](README.md) - Complete documentation
