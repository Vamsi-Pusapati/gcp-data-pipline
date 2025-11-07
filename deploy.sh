#!/bin/bash

# Deployment script for the entire data pipeline
# This script sets up the infrastructure and deploys all components

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"your-gcp-project-id"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}

if [ "$PROJECT_ID" = "your-gcp-project-id" ]; then
    echo -e "${RED}Error: Please provide a valid PROJECT_ID${NC}"
    echo "Usage: $0 <PROJECT_ID> [REGION] [ZONE]"
    exit 1
fi

echo -e "${GREEN}Starting deployment of data pipeline...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    exit 1
fi

if ! command_exists terraform; then
    echo -e "${RED}Error: terraform not found${NC}"
    exit 1
fi

if ! command_exists kubectl; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Set gcloud project
echo -e "${YELLOW}Setting up gcloud configuration...${NC}"
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Enable required APIs
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    pubsub.googleapis.com \
    cloudfunctions.googleapis.com \
    dataproc.googleapis.com \
    composer.googleapis.com \
    iam.googleapis.com

# Create service account
echo -e "${YELLOW}Setting up service account...${NC}"
cd service-account
chmod +x setup-service-account.sh
./setup-service-account.sh $PROJECT_ID
cd ..

# Deploy infrastructure with Terraform
echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd terraform
terraform init
terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE" -var="service_account_email=data-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com"
terraform apply -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE" -var="service_account_email=data-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com"
cd ..

# Build and deploy React dashboard
echo -e "${YELLOW}Building and deploying React dashboard...${NC}"
cd react-dashboard

# Build backend Docker image (FastAPI)
echo "Building FastAPI backend Docker image..."
docker build -t gcr.io/$PROJECT_ID/dashboard-backend:v1.0.0 ./backend/

# Build frontend Docker image
echo "Building frontend Docker image..."
docker build -t gcr.io/$PROJECT_ID/react-dashboard:v1.0.0 .

# Push images to Container Registry
echo "Pushing images to Container Registry..."
docker push gcr.io/$PROJECT_ID/dashboard-backend:v1.0.0
docker push gcr.io/$PROJECT_ID/react-dashboard:v1.0.0

cd ..

# Deploy to GKE
echo -e "${YELLOW}Deploying to GKE...${NC}"
gcloud container clusters get-credentials dashboard-cluster --zone=$ZONE --project=$PROJECT_ID

# Update deployment manifests with project ID
sed -i "s/PROJECT_ID/$PROJECT_ID/g" gke/dashboard-deployment.yaml
sed -i "s/SERVICE_ACCOUNT_EMAIL/data-pipeline-sa@$PROJECT_ID.iam.gserviceaccount.com/g" gke/dashboard-deployment.yaml

kubectl apply -f gke/dashboard-deployment.yaml

# Deploy Cloud Functions
echo -e "${YELLOW}Deploying Cloud Functions...${NC}"
cd cloud-functions/gcs-to-bq
gcloud functions deploy gcs-to-bq-processor \
    --runtime python39 \
    --trigger-resource $PROJECT_ID-raw-data \
    --trigger-event google.storage.object.finalize \
    --set-env-vars GCP_PROJECT_ID=$PROJECT_ID,BQ_STAGING_DATASET=staging_dataset,BQ_STAGING_TABLE=raw_data_staging
cd ../..

# Upload Composer DAG
echo -e "${YELLOW}Setting up Composer environment...${NC}"
# Note: Composer environment creation takes 20-30 minutes, so this is commented out
# gcloud composer environments create data-pipeline-composer --location $REGION

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Wait for Composer environment to be created (20-30 minutes)"
echo "2. Upload DAG files to Composer"
echo "3. Configure API endpoints in your DAG"
echo "4. Test the pipeline end-to-end"
echo ""
echo "Access your dashboard at:"
kubectl get service dashboard-service -n dashboard -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
