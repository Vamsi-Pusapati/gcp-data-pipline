#!/bin/bash
# Complete Workload Identity setup for GKE dashboard

set -e

PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
GCP_SA_NAME="data-pipeline-sa"
K8S_SA_NAME="dashboard-ksa"
NAMESPACE="default"

echo "=== Setting up Workload Identity for Dashboard ==="

# 1. Verify cluster has Workload Identity enabled
echo ""
echo "[1/7] Checking Workload Identity on cluster..."
WORKLOAD_POOL=$(gcloud container clusters describe ${CLUSTER_NAME} \
  --region=${REGION} \
  --format="value(workloadIdentityConfig.workloadPool)")

if [ -z "$WORKLOAD_POOL" ]; then
  echo "⚠️  Workload Identity not enabled. Enabling..."
  gcloud container clusters update ${CLUSTER_NAME} \
    --region=${REGION} \
    --workload-pool=${PROJECT_ID}.svc.id.goog
  echo "✓ Workload Identity enabled"
else
  echo "✓ Workload Identity already enabled: $WORKLOAD_POOL"
fi

# 2. Get cluster credentials
echo ""
echo "[2/7] Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION}

# 3. Create or verify Kubernetes service account
echo ""
echo "[3/7] Setting up Kubernetes service account..."
if kubectl get serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE} 2>/dev/null; then
  echo "✓ Kubernetes service account already exists"
else
  kubectl create serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE}
  echo "✓ Kubernetes service account created"
fi

# 4. Verify GCP service account exists
echo ""
echo "[4/7] Verifying GCP service account..."
SA_EMAIL="${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe ${SA_EMAIL} 2>/dev/null; then
  echo "✓ GCP service account exists: ${SA_EMAIL}"
else
  echo "❌ GCP service account not found!"
  echo "Create it with:"
  echo "  gcloud iam service-accounts create ${GCP_SA_NAME}"
  exit 1
fi

# 5. Grant BigQuery permissions
echo ""
echo "[5/7] Granting BigQuery permissions..."

# BigQuery Data Viewer
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataViewer" \
  --condition=None 2>&1 | grep -q "already has" || echo "✓ BigQuery Data Viewer granted"

# BigQuery Job User
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.jobUser" \
  --condition=None 2>&1 | grep -q "already has" || echo "✓ BigQuery Job User granted"

echo "✓ BigQuery permissions configured"

# 6. Bind GCP SA to K8s SA
echo ""
echo "[6/7] Binding service accounts..."
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]" \
  2>&1 | grep -q "already has" || echo "✓ Workload Identity binding created"

# 7. Annotate K8s service account
echo ""
echo "[7/7] Annotating Kubernetes service account..."
kubectl annotate serviceaccount ${K8S_SA_NAME} \
  -n ${NAMESPACE} \
  iam.gke.io/gcp-service-account=${SA_EMAIL} \
  --overwrite

echo "✓ Annotation added"

# Verify setup
echo ""
echo "=== Verification ==="
echo ""
echo "Kubernetes Service Account:"
kubectl get serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE} -o yaml | grep -A 2 "annotations:"

echo ""
echo "GCP Service Account IAM Policy:"
gcloud iam service-accounts get-iam-policy ${SA_EMAIL} --format=json | grep -A 5 "workloadIdentityUser"

echo ""
echo "Project IAM Bindings:"
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}" \
  --format="table(bindings.role)"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Now restart your deployment:"
echo "  kubectl rollout restart deployment/medicaid-dashboard -n ${NAMESPACE}"
echo "  kubectl rollout status deployment/medicaid-dashboard -n ${NAMESPACE}"
echo ""
echo "Then check logs:"
echo "  kubectl logs -l app=medicaid-dashboard --tail=50"
