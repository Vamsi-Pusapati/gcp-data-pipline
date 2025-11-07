#!/bin/bash

# GKE Setup Script
# Creates GKE cluster for React dashboard deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
fi

echo -e "${GREEN}Setting up GKE...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"

# Set gcloud project
gcloud config set project $PROJECT_ID

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CLUSTER_NAME="dashboard-cluster"

# Enable required APIs
echo -e "${YELLOW}Enabling GKE API...${NC}"
gcloud services enable container.googleapis.com

# Create GKE cluster
echo -e "${YELLOW}Creating GKE cluster: $CLUSTER_NAME${NC}"

gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --machine-type=e2-medium \
    --num-nodes=2 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autorepair \
    --enable-autoupgrade \
    --preemptible \
    --disk-size=50GB \
    --disk-type=pd-ssd \
    --image-type=COS_CONTAINERD \
    --enable-network-policy \
    --enable-ip-alias \
    --network=data-pipeline-vpc \
    --subnetwork=data-pipeline-subnet \
    --cluster-secondary-range-name=pods \
    --services-secondary-range-name=services \
    --enable-shielded-nodes \
    --enable-workload-identity \
    --workload-pool=${PROJECT_ID}.svc.id.goog \
    --logging=SYSTEM,WORKLOAD \
    --monitoring=SYSTEM

# Get cluster credentials
echo -e "${YELLOW}Getting cluster credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID

# Create namespace
echo -e "${YELLOW}Creating dashboard namespace...${NC}"
kubectl create namespace dashboard --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes service account
echo -e "${YELLOW}Setting up Kubernetes service account...${NC}"
kubectl create serviceaccount dashboard-service-account -n dashboard --dry-run=client -o yaml | kubectl apply -f -

# Set up Workload Identity
echo -e "${YELLOW}Setting up Workload Identity...${NC}"
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[dashboard/dashboard-service-account]"

kubectl annotate serviceaccount dashboard-service-account \
    -n dashboard \
    iam.gke.io/gcp-service-account=$SERVICE_ACCOUNT_EMAIL \
    --overwrite

# Build and push Docker images
echo -e "${YELLOW}Building and pushing Docker images...${NC}"

# Configure Docker to use gcloud as credential helper
gcloud auth configure-docker --quiet

# Build backend image
echo "Building FastAPI backend image..."
cd ../react-dashboard/backend
docker build -t gcr.io/$PROJECT_ID/dashboard-backend:v1.0.0 .
docker push gcr.io/$PROJECT_ID/dashboard-backend:v1.0.0
cd ../../scripts

# Build frontend image
echo "Building React frontend image..."
cd ../react-dashboard
docker build -t gcr.io/$PROJECT_ID/react-dashboard:v1.0.0 .
docker push gcr.io/$PROJECT_ID/react-dashboard:v1.0.0
cd ../scripts

# Update deployment manifest with project ID
echo -e "${YELLOW}Updating deployment manifests...${NC}"
cp ../gke/dashboard-deployment.yaml dashboard-deployment-temp.yaml
sed -i "s/PROJECT_ID/$PROJECT_ID/g" dashboard-deployment-temp.yaml
sed -i "s/SERVICE_ACCOUNT_EMAIL/$SERVICE_ACCOUNT_EMAIL/g" dashboard-deployment-temp.yaml

# Deploy to GKE
echo -e "${YELLOW}Deploying applications to GKE...${NC}"
kubectl apply -f dashboard-deployment-temp.yaml

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n dashboard
kubectl wait --for=condition=available --timeout=300s deployment/dashboard-deployment -n dashboard

# Get service information
echo -e "${YELLOW}Getting service information...${NC}"
EXTERNAL_IP=""
while [ -z $EXTERNAL_IP ]; do
    echo "Waiting for external IP..."
    EXTERNAL_IP=$(kubectl get svc dashboard-service -n dashboard --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
    [ -z "$EXTERNAL_IP" ] && sleep 10
done

# Create management scripts
cat > manage_gke_cluster.sh << EOF
#!/bin/bash

ACTION=\${1:-"status"}
PROJECT_ID="$PROJECT_ID"
ZONE="$ZONE"
CLUSTER_NAME="$CLUSTER_NAME"

case \$ACTION in
    "start")
        echo "Starting GKE cluster: \$CLUSTER_NAME"
        gcloud container clusters resize \$CLUSTER_NAME --zone=\$ZONE --project=\$PROJECT_ID --num-nodes=2 --quiet
        ;;
    "stop")
        echo "Stopping GKE cluster: \$CLUSTER_NAME (resizing to 0 nodes)"
        gcloud container clusters resize \$CLUSTER_NAME --zone=\$ZONE --project=\$PROJECT_ID --num-nodes=0 --quiet
        ;;
    "delete")
        echo "Deleting GKE cluster: \$CLUSTER_NAME"
        gcloud container clusters delete \$CLUSTER_NAME --zone=\$ZONE --project=\$PROJECT_ID --quiet
        ;;
    "status")
        echo "Checking GKE cluster status:"
        gcloud container clusters describe \$CLUSTER_NAME --zone=\$ZONE --project=\$PROJECT_ID --format="value(status)"
        echo ""
        echo "Kubernetes resources:"
        kubectl get all -n dashboard
        ;;
    "logs")
        echo "Getting application logs:"
        echo "Backend logs:"
        kubectl logs -l app=backend -n dashboard --tail=50
        echo ""
        echo "Frontend logs:"
        kubectl logs -l app=dashboard -n dashboard --tail=50
        ;;
    "update")
        echo "Updating applications..."
        kubectl rollout restart deployment/backend-deployment -n dashboard
        kubectl rollout restart deployment/dashboard-deployment -n dashboard
        ;;
    *)
        echo "Usage: \$0 {start|stop|delete|status|logs|update}"
        echo "  start   - Start the cluster (resize to 2 nodes)"
        echo "  stop    - Stop the cluster (resize to 0 nodes)"
        echo "  delete  - Delete the cluster"
        echo "  status  - Show cluster and pod status"
        echo "  logs    - Show application logs"
        echo "  update  - Restart deployments"
        exit 1
        ;;
esac
EOF

chmod +x manage_gke_cluster.sh

# Create deployment update script
cat > update_gke_deployment.sh << EOF
#!/bin/bash

# Script to update GKE deployment with new images
IMAGE_TAG=\${1:-"latest"}
PROJECT_ID="$PROJECT_ID"

echo "Updating deployment with image tag: \$IMAGE_TAG"

# Build and push new images
echo "Building backend image..."
cd ../react-dashboard/backend
docker build -t gcr.io/\$PROJECT_ID/dashboard-backend:\$IMAGE_TAG .
docker push gcr.io/\$PROJECT_ID/dashboard-backend:\$IMAGE_TAG

echo "Building frontend image..."
cd ..
docker build -t gcr.io/\$PROJECT_ID/react-dashboard:\$IMAGE_TAG .
docker push gcr.io/\$PROJECT_ID/react-dashboard:\$IMAGE_TAG

cd ../scripts

# Update deployments
echo "Updating Kubernetes deployments..."
kubectl set image deployment/backend-deployment backend=gcr.io/\$PROJECT_ID/dashboard-backend:\$IMAGE_TAG -n dashboard
kubectl set image deployment/dashboard-deployment dashboard=gcr.io/\$PROJECT_ID/react-dashboard:\$IMAGE_TAG -n dashboard

# Wait for rollout
kubectl rollout status deployment/backend-deployment -n dashboard
kubectl rollout status deployment/dashboard-deployment -n dashboard

echo "Deployment update completed!"
EOF

chmod +x update_gke_deployment.sh

# Clean up temp file
rm dashboard-deployment-temp.yaml

echo -e "${GREEN}GKE setup completed successfully!${NC}"
echo "Cluster created: $CLUSTER_NAME"
echo "Zone: $ZONE"
echo "External IP: $EXTERNAL_IP"
echo ""
echo "Dashboard URL: http://$EXTERNAL_IP"
echo "API URL: http://$EXTERNAL_IP/api"
echo ""
echo "Management scripts created:"
echo "  - manage_gke_cluster.sh (start/stop/delete cluster)"
echo "  - update_gke_deployment.sh (update deployments)"
echo ""
echo "Cluster information:"
kubectl get nodes
echo ""
echo "Application status:"
kubectl get all -n dashboard
