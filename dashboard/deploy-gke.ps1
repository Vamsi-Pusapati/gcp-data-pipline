# PowerShell deployment script for GKE (without local Docker)
# Uses Cloud Build for remote image building

param(
    [string]$ProjectId = "gcp-project-deliverable",
    [string]$Region = "us-central1",
    [string]$ClusterName = "medicaid-dashboard-cluster",
    [string]$ImageName = "medicaid-dashboard",
    [string]$ImageTag = "latest",
    [string]$GcpSaName = "data-pipeline-sa",
    [string]$K8sSaName = "dashboard-ksa",
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "=== GKE Deployment for Medicaid Dashboard ===" -ForegroundColor Cyan
Write-Host "Using Cloud Build (no local Docker required)" -ForegroundColor Green

# Step 1: Set project
Write-Host "`nStep 1: Setting GCP project..." -ForegroundColor Yellow
gcloud config set project $ProjectId

# Step 2: Enable required APIs
Write-Host "`nStep 2: Enabling required APIs..." -ForegroundColor Yellow
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable container.googleapis.com

# Step 3: Build image using Cloud Build (no local Docker needed!)
Write-Host "`nStep 3: Building Docker image using Cloud Build..." -ForegroundColor Yellow
Write-Host "This will build the image remotely on GCP..." -ForegroundColor Gray

# Navigate to project root for Cloud Build
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    gcloud builds submit `
        --config=cloudbuild.yaml `
        --substitutions=TAG_NAME=$ImageTag `
        --timeout=20m
    
    Write-Host "Image built successfully: gcr.io/$ProjectId/$ImageName`:$ImageTag" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 4: Create or get GKE cluster
Write-Host "`nStep 4: Setting up GKE cluster..." -ForegroundColor Yellow
$clusterExists = gcloud container clusters describe $ClusterName --region=$Region 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating new GKE cluster (this may take 5-10 minutes)..." -ForegroundColor Gray
    gcloud container clusters create $ClusterName `
        --region=$Region `
        --num-nodes=2 `
        --machine-type=e2-standard-2 `
        --enable-autoscaling `
        --min-nodes=1 `
        --max-nodes=4 `
        --enable-autorepair `
        --enable-autoupgrade `
        --workload-pool="$ProjectId.svc.id.goog"
} else {
    Write-Host "Cluster already exists." -ForegroundColor Green
}

# Step 5: Get cluster credentials
Write-Host "`nStep 5: Getting cluster credentials..." -ForegroundColor Yellow
gcloud container clusters get-credentials $ClusterName --region=$Region

# Step 6: Verify service account
Write-Host "`nStep 6: Verifying service account..." -ForegroundColor Yellow
$saEmail = "$GcpSaName@$ProjectId.iam.gserviceaccount.com"
gcloud iam service-accounts describe $saEmail

# Step 7: Ensure BigQuery permissions
Write-Host "`nStep 7: Ensuring BigQuery permissions..." -ForegroundColor Yellow
gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$saEmail" `
    --role="roles/bigquery.dataViewer" `
    --condition=None 2>&1 | Out-Null

gcloud projects add-iam-policy-binding $ProjectId `
    --member="serviceAccount:$saEmail" `
    --role="roles/bigquery.jobUser" `
    --condition=None 2>&1 | Out-Null

Write-Host "Permissions verified." -ForegroundColor Green

# Step 8: Setup Workload Identity
Write-Host "`nStep 8: Setting up Workload Identity..." -ForegroundColor Yellow

# Create Kubernetes service account
kubectl get serviceaccount $K8sSaName -n $Namespace 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    kubectl create serviceaccount $K8sSaName -n $Namespace
    Write-Host "Created Kubernetes service account: $K8sSaName" -ForegroundColor Green
} else {
    Write-Host "Kubernetes service account already exists." -ForegroundColor Green
}

# Bind GCP SA to K8s SA
Write-Host "Binding GCP service account to Kubernetes service account..." -ForegroundColor Gray
gcloud iam service-accounts add-iam-policy-binding $saEmail `
    --role="roles/iam.workloadIdentityUser" `
    --member="serviceAccount:$ProjectId.svc.id.goog[$Namespace/$K8sSaName]" 2>&1 | Out-Null

# Annotate K8s SA
kubectl annotate serviceaccount $K8sSaName `
    -n $Namespace `
    "iam.gke.io/gcp-service-account=$saEmail" `
    --overwrite

Write-Host "Workload Identity configured." -ForegroundColor Green

# Step 9: Update Kubernetes manifests with current image
Write-Host "`nStep 9: Updating Kubernetes manifests..." -ForegroundColor Yellow
$deploymentPath = Join-Path $PSScriptRoot "k8s\deployment.yaml"
$servicePath = Join-Path $PSScriptRoot "k8s\service.yaml"

# Read deployment file
$deployment = Get-Content $deploymentPath -Raw

# Update image tag in deployment
$deployment = $deployment -replace 'image: gcr.io/gcp-project-deliverable/medicaid-dashboard:.*', "image: gcr.io/$ProjectId/$ImageName`:$ImageTag"

# Save updated deployment
$deployment | Set-Content $deploymentPath -NoNewline

Write-Host "Deployment manifest updated with image: gcr.io/$ProjectId/$ImageName`:$ImageTag" -ForegroundColor Green

# Step 10: Deploy to GKE
Write-Host "`nStep 10: Deploying to GKE..." -ForegroundColor Yellow
kubectl apply -f $deploymentPath
kubectl apply -f $servicePath

# Step 11: Wait for deployment
Write-Host "`nStep 11: Waiting for deployment to be ready..." -ForegroundColor Yellow
kubectl rollout status deployment/medicaid-dashboard -n $Namespace --timeout=5m

# Step 12: Get service endpoint
Write-Host "`nStep 12: Getting service information..." -ForegroundColor Yellow
Write-Host "Waiting for external IP (this may take a few minutes)..." -ForegroundColor Gray

$attempts = 0
$maxAttempts = 30
$externalIp = $null

while ($attempts -lt $maxAttempts) {
    $serviceInfo = kubectl get service medicaid-dashboard-service -n $Namespace -o json | ConvertFrom-Json
    $externalIp = $serviceInfo.status.loadBalancer.ingress[0].ip
    
    if ($externalIp) {
        break
    }
    
    $attempts++
    Write-Host "Attempt $attempts/$maxAttempts - waiting for external IP..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
}

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan

if ($externalIp) {
    Write-Host "`nDashboard URL: http://$externalIp`:8501" -ForegroundColor Green
    Write-Host "Note: It may take a few minutes for the service to be fully available." -ForegroundColor Yellow
} else {
    Write-Host "`nExternal IP not yet assigned. Check status with:" -ForegroundColor Yellow
    Write-Host "  kubectl get service medicaid-dashboard-service -n $Namespace" -ForegroundColor White
}

Write-Host "`nUseful commands:" -ForegroundColor Cyan
Write-Host "  # View pods" -ForegroundColor Gray
Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
Write-Host "`n  # View logs" -ForegroundColor Gray
Write-Host "  kubectl logs -l app=medicaid-dashboard -n $Namespace" -ForegroundColor White
Write-Host "`n  # View service" -ForegroundColor Gray
Write-Host "  kubectl get service medicaid-dashboard-service -n $Namespace" -ForegroundColor White
Write-Host "`n  # Update deployment (after rebuilding image)" -ForegroundColor Gray
Write-Host "  kubectl rollout restart deployment/medicaid-dashboard -n $Namespace" -ForegroundColor White
