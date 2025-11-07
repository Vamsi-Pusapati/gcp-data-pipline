#!/bin/bash
# Deployment script optimized for Google Cloud Shell
# No local Docker needed - uses Cloud Build!

set -e

# Configuration
PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
IMAGE_NAME="medicaid-dashboard"
IMAGE_TAG="latest"
GCP_SA_NAME="data-pipeline-sa"
K8S_SA_NAME="dashboard-ksa"
NAMESPACE="default"

echo "=============================================="
echo "  Medicaid Dashboard - GKE Deployment"
echo "  (Cloud Shell Edition)"
echo "=============================================="

# Step 1: Set project
echo ""
echo "[1/10] Setting GCP project..."
gcloud config set project ${PROJECT_ID}

# Step 2: Enable required APIs
echo ""
echo "[2/10] Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable containerregistry.googleapis.com --quiet
gcloud services enable container.googleapis.com --quiet
gcloud services enable bigquery.googleapis.com --quiet

# Step 3: Build image using Cloud Build (no Docker needed!)
echo ""
echo "[3/10] Building Docker image using Cloud Build..."
echo "This builds the image remotely on GCP (no local Docker required)"

# Navigate to project root for Cloud Build
cd ..

gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=TAG_NAME=${IMAGE_TAG} \
  --timeout=20m

echo "✓ Image built: gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

# Return to dashboard directory
cd dashboard

# Step 4: Create or get GKE cluster
echo ""
echo "[4/10] Setting up GKE cluster..."
if gcloud container clusters describe ${CLUSTER_NAME} --region=${REGION} 2>/dev/null; then
  echo "✓ Cluster already exists"
else
  echo "Creating new GKE cluster (this may take 5-10 minutes)..."
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
  echo "✓ Cluster created"
fi

# Step 5: Get cluster credentials
echo ""
echo "[5/10] Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION}

# Step 6: Verify service account
echo ""
echo "[6/10] Verifying service account..."
SA_EMAIL="${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe ${SA_EMAIL} 2>/dev/null; then
  echo "✓ Service account exists: ${SA_EMAIL}"
else
  echo "Creating service account..."
  gcloud iam service-accounts create ${GCP_SA_NAME} \
    --display-name="Data Pipeline Service Account"
  echo "✓ Service account created"
fi

# Step 7: Grant BigQuery permissions
echo ""
echo "[7/10] Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataViewer" \
  --condition=None 2>&1 | grep -v "already exists" || true

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.jobUser" \
  --condition=None 2>&1 | grep -v "already exists" || true

echo "✓ Permissions granted"

# Step 8: Setup Workload Identity
echo ""
echo "[8/10] Setting up Workload Identity..."

# Create Kubernetes service account
if kubectl get serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE} 2>/dev/null; then
  echo "✓ Kubernetes service account already exists"
else
  kubectl create serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE}
  echo "✓ Kubernetes service account created"
fi

# Bind GCP SA to K8s SA
echo "Binding service accounts..."
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]" \
  2>&1 | grep -v "already has" || true

# Annotate K8s SA
kubectl annotate serviceaccount ${K8S_SA_NAME} \
  -n ${NAMESPACE} \
  "iam.gke.io/gcp-service-account=${SA_EMAIL}" \
  --overwrite

echo "✓ Workload Identity configured"

# Step 9: Update deployment manifest with current image
echo ""
echo "[9/10] Deploying to GKE..."

# Update image in deployment
sed -i "s|image: gcr.io/gcp-project-deliverable/medicaid-dashboard:.*|image: gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/deployment.yaml

# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Step 10: Wait for deployment
echo ""
echo "[10/10] Waiting for deployment to be ready..."
kubectl rollout status deployment/medicaid-dashboard -n ${NAMESPACE} --timeout=5m

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="

# Get service endpoint
echo ""
echo "Getting service information..."
echo "Waiting for external IP (this may take 2-5 minutes)..."

ATTEMPTS=0
MAX_ATTEMPTS=30

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  EXTERNAL_IP=$(kubectl get service medicaid-dashboard-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ ! -z "$EXTERNAL_IP" ]; then
    echo ""
    echo "✓ Dashboard URL: http://${EXTERNAL_IP}:8501"
    echo ""
    echo "Note: It may take a few minutes for the service to be fully available."
    break
  fi
  
  ATTEMPTS=$((ATTEMPTS + 1))
  echo -n "."
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo ""
  echo "⚠ External IP not yet assigned. Check status with:"
  echo "  kubectl get service medicaid-dashboard-service -n ${NAMESPACE}"
fi

echo ""
echo "Useful commands:"
echo "  # View pods"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "  # View logs"
echo "  kubectl logs -l app=medicaid-dashboard -n ${NAMESPACE}"
echo ""
echo "  # View service"
echo "  kubectl get service medicaid-dashboard-service -n ${NAMESPACE}"
echo ""
echo "  # Restart deployment"
echo "  kubectl rollout restart deployment/medicaid-dashboard -n ${NAMESPACE}"
echo ""
echo "=============================================="
