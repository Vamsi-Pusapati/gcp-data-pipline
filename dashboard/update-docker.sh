#!/bin/bash
# Update dashboard using Docker build in Cloud Shell

set -e

PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
IMAGE_NAME="medicaid-dashboard"
NAMESPACE="default"

echo "=============================================="
echo "  Dashboard Update (Docker Build)"
echo "=============================================="

# Generate version tag
VERSION=$(date +%Y%m%d-%H%M%S)
IMAGE_TAG="v${VERSION}"

echo ""
echo "Building image: gcr.io/${PROJECT_ID}/${IMAGE_NAME}"
echo "Tags: latest, ${IMAGE_TAG}"

# Step 1: Verify we're in the right directory
echo ""
echo "[1/6] Checking directory..."
if [ ! -f "Dockerfile" ]; then
  echo "❌ Error: Dockerfile not found"
  echo "Please run this script from the dashboard/ directory"
  exit 1
fi
echo "✓ In dashboard directory"

# Step 2: Configure Docker for GCR
echo ""
echo "[2/6] Configuring Docker for GCR..."
gcloud auth configure-docker --quiet
echo "✓ Docker configured"

# Step 3: Build Docker image
echo ""
echo "[3/6] Building Docker image..."
echo "This will take 2-3 minutes..."

docker build \
  -t gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest \
  -t gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} \
  .

echo "✓ Image built"

# Step 4: Push to GCR
echo ""
echo "[4/6] Pushing to Google Container Registry..."

docker push gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest
docker push gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}

echo "✓ Image pushed to GCR"

# Step 5: Get cluster credentials
echo ""
echo "[5/6] Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION} --quiet
echo "✓ Connected to cluster"

# Step 6: Update deployment
echo ""
echo "[6/6] Updating deployment..."

# Option 1: Update with specific tag
kubectl set image deployment/medicaid-dashboard \
  medicaid-dashboard=gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG} \
  -n ${NAMESPACE}

# Wait for rollout
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/medicaid-dashboard -n ${NAMESPACE} --timeout=5m

echo "✓ Deployment updated"

# Get status
echo ""
echo "=============================================="
echo "  Update Complete!"
echo "=============================================="
echo ""

# Show pods
echo "Pods:"
kubectl get pods -l app=medicaid-dashboard -n ${NAMESPACE}

# Show service
echo ""
echo "Service:"
kubectl get service medicaid-dashboard-service -n ${NAMESPACE}

# Get external IP
EXTERNAL_IP=$(kubectl get service medicaid-dashboard-service -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

echo ""
if [ ! -z "$EXTERNAL_IP" ]; then
  echo "✓ Dashboard URL: http://${EXTERNAL_IP}:8501"
else
  echo "Getting external IP..."
  echo "Run: kubectl get service medicaid-dashboard-service"
fi

echo ""
echo "Images deployed:"
echo "  gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest"
echo "  gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "Useful commands:"
echo "  # View logs"
echo "  kubectl logs -l app=medicaid-dashboard --tail=50 --follow"
echo ""
echo "  # Check pod details"
echo "  kubectl describe pod -l app=medicaid-dashboard"
echo ""
echo "  # Rollback if needed"
echo "  kubectl rollout undo deployment/medicaid-dashboard"
echo ""
echo "=============================================="
