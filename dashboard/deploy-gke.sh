#!/bin/bash
set -e

# Configuration
PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
IMAGE_NAME="medicaid-dashboard"
IMAGE_TAG="latest"
GCP_SA_NAME="data-pipeline-sa"  # Using existing service account
K8S_SA_NAME="dashboard-ksa"
NAMESPACE="default"

echo "=== GKE Deployment for Medicaid Dashboard ==="

# Step 1: Build and push Docker image
echo "Step 1: Building Docker image..."
docker build -t gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} .

echo "Step 2: Pushing to GCR..."
docker push gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}

# Step 3: Create or get GKE cluster
echo "Step 3: Creating GKE cluster (if not exists)..."
gcloud container clusters describe ${CLUSTER_NAME} --region=${REGION} 2>/dev/null || \
gcloud container clusters create ${CLUSTER_NAME} \
  --region=${REGION} \
  --num-nodes=2 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=4 \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool=${PROJECT_ID}.svc.id.goog

# Step 4: Get cluster credentials
echo "Step 4: Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION}

# Step 5: Use existing service account (data-pipeline-sa)
# Update GCP_SA_NAME if you want to use a different service account
echo "Step 5: Using existing service account: ${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Verifying service account exists..."
gcloud iam service-accounts describe ${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

# Step 6: Ensure BigQuery permissions (skip if already granted)
echo "Step 6: Ensuring BigQuery permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer" 2>/dev/null || echo "Role already granted"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser" 2>/dev/null || echo "Role already granted"

# Step 7: Create Kubernetes Service Account
echo "Step 7: Creating Kubernetes service account..."
kubectl create serviceaccount ${K8S_SA_NAME} --namespace=${NAMESPACE} 2>/dev/null || echo "KSA already exists"

# Step 8: Bind Workload Identity
echo "Step 8: Binding Workload Identity..."
gcloud iam service-accounts add-iam-policy-binding \
  ${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]"

kubectl annotate serviceaccount ${K8S_SA_NAME} \
  --namespace=${NAMESPACE} \
  iam.gke.io/gcp-service-account=${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --overwrite

# Step 9: Deploy to GKE
echo "Step 9: Deploying to GKE..."
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Step 10: Wait for deployment
echo "Step 10: Waiting for deployment..."
kubectl rollout status deployment/medicaid-dashboard

# Step 11: Get external IP
echo "Step 11: Getting external IP..."
echo "Waiting for LoadBalancer IP..."
kubectl get service medicaid-dashboard-svc --watch

echo ""
echo "=== Deployment Complete ==="
echo "Run: kubectl get service medicaid-dashboard-svc"
echo "Then access the dashboard at: http://<EXTERNAL-IP>"
