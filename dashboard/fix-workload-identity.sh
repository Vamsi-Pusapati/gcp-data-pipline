#!/bin/bash
# Fix Workload Identity issues

set -e

PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
CLUSTER_NAME="medicaid-dashboard-cluster"
GCP_SA_NAME="data-pipeline-sa"
K8S_SA_NAME="dashboard-ksa"
NAMESPACE="default"

echo "=============================================="
echo "  Workload Identity Troubleshooting"
echo "=============================================="

# Step 1: Check cluster Workload Identity
echo ""
echo "[1/10] Checking Workload Identity on cluster..."
WORKLOAD_POOL=$(gcloud container clusters describe ${CLUSTER_NAME} \
  --region=${REGION} \
  --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null || echo "")

if [ -z "$WORKLOAD_POOL" ]; then
  echo "❌ Workload Identity NOT enabled on cluster"
  echo "Enabling... (this will take 5-10 minutes)"
  gcloud container clusters update ${CLUSTER_NAME} \
    --region=${REGION} \
    --workload-pool=${PROJECT_ID}.svc.id.goog
  echo "✓ Workload Identity enabled"
else
  echo "✓ Workload Identity enabled: ${WORKLOAD_POOL}"
fi

# Step 2: Get credentials
echo ""
echo "[2/10] Getting cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region=${REGION} --quiet
echo "✓ Credentials obtained"

# Step 3: Check GCP service account exists
echo ""
echo "[3/10] Checking GCP service account..."
SA_EMAIL="${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe ${SA_EMAIL} &>/dev/null; then
  echo "✓ GCP service account exists: ${SA_EMAIL}"
else
  echo "❌ GCP service account NOT found: ${SA_EMAIL}"
  echo "Creating..."
  gcloud iam service-accounts create ${GCP_SA_NAME} \
    --display-name="Data Pipeline Service Account"
  echo "✓ Created"
fi

# Step 4: Grant BigQuery permissions
echo ""
echo "[4/10] Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataViewer" \
  --condition=None &>/dev/null
echo "✓ BigQuery Data Viewer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.jobUser" \
  --condition=None &>/dev/null
echo "✓ BigQuery Job User"

# Step 5: Create K8s service account
echo ""
echo "[5/10] Creating Kubernetes service account..."
if kubectl get serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE} &>/dev/null; then
  echo "✓ Kubernetes service account exists"
else
  kubectl create serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE}
  echo "✓ Created"
fi

# Step 6: Bind service accounts
echo ""
echo "[6/10] Binding GCP SA to K8s SA..."
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]" \
  &>/dev/null
echo "✓ Binding created"

# Step 7: Annotate K8s SA
echo ""
echo "[7/10] Annotating Kubernetes service account..."
kubectl annotate serviceaccount ${K8S_SA_NAME} \
  -n ${NAMESPACE} \
  iam.gke.io/gcp-service-account=${SA_EMAIL} \
  --overwrite
echo "✓ Annotation added"

# Step 8: Check deployment SA
echo ""
echo "[8/10] Checking deployment configuration..."
DEPLOYMENT_SA=$(kubectl get deployment medicaid-dashboard -n ${NAMESPACE} \
  -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "")

if [ "$DEPLOYMENT_SA" == "${K8S_SA_NAME}" ]; then
  echo "✓ Deployment uses correct service account: ${DEPLOYMENT_SA}"
else
  echo "❌ Deployment using wrong service account: ${DEPLOYMENT_SA}"
  echo "Patching deployment..."
  kubectl patch deployment medicaid-dashboard -n ${NAMESPACE} \
    -p '{"spec":{"template":{"spec":{"serviceAccountName":"'${K8S_SA_NAME}'"}}}}'
  echo "✓ Patched"
fi

# Step 9: Restart deployment
echo ""
echo "[9/10] Restarting deployment..."
kubectl rollout restart deployment/medicaid-dashboard -n ${NAMESPACE}
echo "Waiting for rollout..."
kubectl rollout status deployment/medicaid-dashboard -n ${NAMESPACE} --timeout=5m
echo "✓ Deployment restarted"

# Step 10: Verify
echo ""
echo "[10/10] Verifying setup..."
sleep 5

echo ""
echo "=== Configuration Summary ==="
echo ""
echo "GCP Service Account:"
echo "  ${SA_EMAIL}"
echo ""
echo "Kubernetes Service Account:"
kubectl get serviceaccount ${K8S_SA_NAME} -n ${NAMESPACE} -o yaml | grep -A 2 "annotations:"
echo ""
echo "Workload Identity Binding:"
gcloud iam service-accounts get-iam-policy ${SA_EMAIL} \
  --format="table(bindings.members)" | grep -A 1 "workloadIdentityUser" || echo "  No binding found"
echo ""
echo "BigQuery Permissions:"
gcloud projects get-iam-policy ${PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}" \
  --format="table(bindings.role)"

echo ""
echo "=== Testing Authentication ==="
echo ""
echo "Checking pod logs..."
sleep 3
POD_NAME=$(kubectl get pods -l app=medicaid-dashboard -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ ! -z "$POD_NAME" ]; then
  echo "Pod: ${POD_NAME}"
  echo ""
  kubectl logs ${POD_NAME} --tail=20 | grep -i "bigquery\|authentication\|credentials\|error" || echo "No relevant logs yet"
else
  echo "⚠ No pods found yet"
fi

echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Wait 1-2 minutes for pods to fully start"
echo "  2. Check logs: kubectl logs -l app=medicaid-dashboard --tail=50"
echo "  3. Access dashboard: kubectl get service medicaid-dashboard-service"
echo ""
echo "If still having issues, run:"
echo "  kubectl describe pod -l app=medicaid-dashboard"
echo ""
echo "=============================================="
