#!/bin/bash
# Quick update script for dashboard after code changes

set -e

PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
IMAGE_NAME="medicaid-dashboard"
NAMESPACE="default"

echo "=============================================="
echo "  Dashboard Update Script"
echo "=============================================="

# Get current version
CURRENT_VERSION=$(date +%Y%m%d-%H%M%S)
IMAGE_TAG="v${CURRENT_VERSION}"

echo ""
echo "New image tag: ${IMAGE_TAG}"

# Step 1: Navigate to project root
echo ""
echo "[1/5] Checking location..."
if [ ! -f "../cloudbuild.yaml" ]; then
  echo "❌ Error: cloudbuild.yaml not found in parent directory"
  echo "Please run this script from the dashboard/ directory"
  exit 1
fi

cd ..
echo "✓ In project root"

# Step 2: Build new image with Cloud Build
echo ""
echo "[2/5] Building new Docker image..."
echo "This will take 3-5 minutes..."

gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions=TAG_NAME=${IMAGE_TAG} \
  --timeout=20m

echo "✓ Image built: gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

# Step 3: Get cluster credentials (in case not connected)
echo ""
echo "[3/5] Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION} --quiet

# Step 4: Update deployment with new image
echo ""
echo "[4/5] Updating deployment..."
cd dashboard

# Update the image in the deployment
kubectl set image deployment/medicaid-dashboard \
  medicaid-dashboard=gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} \
  -n ${NAMESPACE}

# Wait for rollout
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/medicaid-dashboard -n ${NAMESPACE} --timeout=5m

echo "✓ Deployment updated"

# Step 5: Verify deployment
echo ""
echo "[5/5] Verifying deployment..."

# Get pod status
kubectl get pods -l app=medicaid-dashboard -n ${NAMESPACE}

# Get external IP
EXTERNAL_IP=$(kubectl get service medicaid-dashboard-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

echo ""
echo "=============================================="
echo "  Update Complete!"
echo "=============================================="
echo ""
echo "Image: gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

if [ ! -z "$EXTERNAL_IP" ]; then
  echo "Dashboard URL: http://${EXTERNAL_IP}:8501"
else
  echo "Getting external IP..."
  kubectl get service medicaid-dashboard-service -n ${NAMESPACE}
fi

echo ""
echo "View logs:"
echo "  kubectl logs -l app=medicaid-dashboard --tail=50 --follow"
echo ""
echo "Rollback if needed:"
echo "  kubectl rollout undo deployment/medicaid-dashboard"
echo ""
echo "=============================================="
