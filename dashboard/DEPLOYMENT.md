# GKE Deployment Guide (Windows - No Docker Required)

## Overview
This guide shows how to deploy the Medicaid Dashboard to GKE without installing Docker locally. We use **Cloud Build** to build the image remotely on GCP.

## Prerequisites
- Google Cloud SDK (gcloud) installed
- kubectl installed (comes with gcloud)
- Authenticated with GCP: `gcloud auth login`
- Project ID: `gcp-project-deliverable`

## Quick Deployment (All-in-One)

### Option 1: Full Deployment Script
```powershell
cd dashboard
.\deploy-gke.ps1
```

This script will:
1. Build the Docker image using Cloud Build (remotely on GCP)
2. Push to Google Container Registry (GCR)
3. Create or use existing GKE cluster
4. Set up Workload Identity
5. Deploy the application
6. Expose via LoadBalancer

**Time:** ~10-15 minutes for first run, ~5 minutes for updates

### Option 2: Step-by-Step

#### Step 1: Build Image (No Docker Needed!)
```powershell
cd dashboard
.\build-image.ps1
```

This uses Cloud Build to build your image remotely. No local Docker required!

#### Step 2: Create GKE Cluster (First Time Only)
```powershell
gcloud container clusters create medicaid-dashboard-cluster `
  --region=us-central1 `
  --num-nodes=2 `
  --machine-type=e2-standard-2 `
  --enable-autoscaling `
  --min-nodes=1 `
  --max-nodes=4 `
  --workload-pool=gcp-project-deliverable.svc.id.goog
```

#### Step 3: Get Cluster Credentials
```powershell
gcloud container clusters get-credentials medicaid-dashboard-cluster --region=us-central1
```

#### Step 4: Set Up Workload Identity
```powershell
# Create Kubernetes service account
kubectl create serviceaccount dashboard-ksa

# Bind to GCP service account
gcloud iam service-accounts add-iam-policy-binding `
  data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com `
  --role=roles/iam.workloadIdentityUser `
  --member="serviceAccount:gcp-project-deliverable.svc.id.goog[default/dashboard-ksa]"

# Annotate K8s service account
kubectl annotate serviceaccount dashboard-ksa `
  iam.gke.io/gcp-service-account=data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com
```

#### Step 5: Deploy Application
```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

#### Step 6: Get External IP
```powershell
kubectl get service medicaid-dashboard-service
```

Wait for EXTERNAL-IP to be assigned (may take 2-5 minutes). Then access:
```
http://<EXTERNAL-IP>:8501
```

## Updating the Application

### After Code Changes
```powershell
# 1. Rebuild image with Cloud Build
cd dashboard
.\build-image.ps1 -ImageTag "v1.1"

# 2. Update deployment to use new image
kubectl set image deployment/medicaid-dashboard `
  medicaid-dashboard=gcr.io/gcp-project-deliverable/medicaid-dashboard:v1.1

# Or use rollout restart to pull latest
kubectl rollout restart deployment/medicaid-dashboard
```

## Useful Commands

### Check Deployment Status
```powershell
# View pods
kubectl get pods

# View logs
kubectl logs -l app=medicaid-dashboard

# View service
kubectl get service medicaid-dashboard-service

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name>
```

### Check Cloud Build Status
```powershell
# List recent builds
gcloud builds list --limit=5

# View build logs
gcloud builds log <BUILD-ID>
```

### Scale Deployment
```powershell
# Scale to 3 replicas
kubectl scale deployment/medicaid-dashboard --replicas=3

# View horizontal pod autoscaling
kubectl get hpa
```

### Delete Resources
```powershell
# Delete deployment and service
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml

# Delete cluster (careful!)
gcloud container clusters delete medicaid-dashboard-cluster --region=us-central1
```

## Troubleshooting

### Build Fails
```powershell
# Check Cloud Build logs
gcloud builds list
gcloud builds log <BUILD-ID>

# Common issues:
# - Missing files: Check .dockerignore
# - Permission denied: Enable Cloud Build API
# - Timeout: Increase timeout in cloudbuild.yaml
```

### Pods Not Starting
```powershell
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>

# Common issues:
# - Image pull error: Check GCR permissions
# - CrashLoopBackOff: Check logs with kubectl logs
# - Workload Identity: Verify service account bindings
```

### Can't Access Dashboard
```powershell
# Check service
kubectl get service medicaid-dashboard-service

# Common issues:
# - No external IP: Wait a few minutes or check LoadBalancer quota
# - Wrong port: Ensure using port 8501
# - Firewall: Check GCP firewall rules
```

### BigQuery Authentication Issues
```powershell
# Check Workload Identity binding
gcloud iam service-accounts get-iam-policy `
  data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com

# Check pod service account
kubectl get pod <pod-name> -o yaml | grep serviceAccountName

# View pod logs for auth errors
kubectl logs <pod-name>
```

## Cost Optimization

### Current Setup Cost (Estimate)
- GKE Cluster: ~$150/month (2 e2-standard-2 nodes)
- Cloud Build: Free tier (120 build minutes/day)
- Container Registry: ~$0.10/GB/month storage
- LoadBalancer: ~$18/month

### Reduce Costs
```powershell
# Use smaller nodes
--machine-type=e2-small

# Use autopilot mode (pay per pod)
gcloud container clusters create-auto medicaid-dashboard-cluster

# Use preemptible nodes (not recommended for production)
--preemptible

# Scale down when not in use
kubectl scale deployment/medicaid-dashboard --replicas=0
```

## Security Best Practices

1. **Use Workload Identity** (already configured)
   - No service account keys needed
   - Automatic credential rotation

2. **Network Policies** (optional)
   - Restrict pod-to-pod communication
   - Use private GKE cluster

3. **HTTPS/TLS** (recommended for production)
   - Use Google Cloud Load Balancer
   - Configure SSL certificate

4. **Resource Limits** (already configured)
   - Prevents resource exhaustion
   - See deployment.yaml

## Production Enhancements

### Add HTTPS with Ingress
```powershell
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ingress with managed certificate
# (requires domain name)
```

### Add Monitoring
```powershell
# Enable GKE monitoring
gcloud container clusters update medicaid-dashboard-cluster `
  --enable-cloud-logging `
  --enable-cloud-monitoring `
  --region=us-central1
```

### Add Caching
- Use Redis for query caching
- Add to deployment.yaml as sidecar

## File Reference

```
dashboard/
├── app.py                    # Streamlit app
├── requirements.txt          # Python dependencies
├── Dockerfile                # Container definition
├── .dockerignore             # Exclude files from build
├── deploy-gke.ps1            # Full deployment script (Windows)
├── build-image.ps1           # Build image only (Windows)
├── k8s/
│   ├── deployment.yaml       # Kubernetes deployment
│   └── service.yaml          # LoadBalancer service
└── service_account_secret/   # Local dev only (not in Git)
    └── gcp-project-deliverable-*.json

../cloudbuild.yaml            # Cloud Build config
```

## Next Steps

After successful deployment:
1. Test dashboard at http://<EXTERNAL-IP>:8501
2. Monitor logs and metrics
3. Set up alerts for errors
4. Configure HTTPS for production
5. Implement caching for better performance
6. Add CI/CD pipeline for automated deployments

## Support

Common issues and solutions:
- **No gcloud**: Install from https://cloud.google.com/sdk/docs/install
- **No kubectl**: Run `gcloud components install kubectl`
- **Permission denied**: Run `gcloud auth login` and `gcloud auth application-default login`
- **Quota exceeded**: Request quota increase in GCP Console
- **Build timeout**: Increase timeout in cloudbuild.yaml

For more help, check:
- GKE Documentation: https://cloud.google.com/kubernetes-engine/docs
- Cloud Build Documentation: https://cloud.google.com/build/docs
- Kubernetes Documentation: https://kubernetes.io/docs/
