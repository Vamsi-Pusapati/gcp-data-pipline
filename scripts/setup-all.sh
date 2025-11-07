#!/bin/bash

# Master Setup Script for Data Pipeline
# Orchestrates setup of all Google Cloud services

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
    echo -e "${YELLOW}You can override by passing a different project ID as first argument${NC}"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Data Pipeline Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Zone: $ZONE"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
MISSING_TOOLS=()

if ! command_exists gcloud; then
    MISSING_TOOLS+=("gcloud CLI")
fi

if ! command_exists docker; then
    MISSING_TOOLS+=("Docker")
fi

if ! command_exists kubectl; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command_exists bq; then
    MISSING_TOOLS+=("BigQuery CLI (bq)")
fi

if ! command_exists gsutil; then
    MISSING_TOOLS+=("Cloud Storage CLI (gsutil)")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required tools:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Please install the missing tools and try again."
    exit 1
fi

echo -e "${GREEN}All prerequisites are installed!${NC}"
echo ""

# Set gcloud project
echo -e "${YELLOW}Setting up gcloud configuration...${NC}"
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Enable required APIs
echo -e "${YELLOW}Enabling required Google Cloud APIs...${NC}"
APIS=(
    "compute.googleapis.com"
    "container.googleapis.com"
    "bigquery.googleapis.com"
    "storage.googleapis.com"
    "pubsub.googleapis.com"
    "cloudfunctions.googleapis.com"
    "dataproc.googleapis.com"
    "composer.googleapis.com"
    "iam.googleapis.com"
    "cloudbuild.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable $api
done

echo -e "${GREEN}APIs enabled successfully!${NC}"
echo ""

# Setup services in order
SERVICES=("service-account" "gcs" "pubsub" "bigquery" "cloud-functions" "dataproc" "gke" "composer")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Starting Service Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Setting up $service...${NC}"
    
    case $service in
        "service-account")
            cd ../service-account
            chmod +x setup-service-account.sh
            ./setup-service-account.sh $PROJECT_ID
            cd ../scripts
            ;;
        "gcs")
            chmod +x setup-gcs.sh
            ./setup-gcs.sh $PROJECT_ID $REGION
            ;;
        "pubsub")
            chmod +x setup-pubsub.sh
            ./setup-pubsub.sh $PROJECT_ID
            ;;
        "bigquery")
            chmod +x setup-bigquery.sh
            ./setup-bigquery.sh $PROJECT_ID $REGION
            ;;
        "cloud-functions")
            chmod +x setup-cloud-functions.sh
            ./setup-cloud-functions.sh $PROJECT_ID $REGION
            ;;
        "dataproc")
            chmod +x setup-dataproc.sh
            ./setup-dataproc.sh $PROJECT_ID $REGION $ZONE
            ;;
        "gke")
            chmod +x setup-gke.sh
            ./setup-gke.sh $PROJECT_ID $REGION $ZONE
            ;;
        "composer")
            echo -e "${YELLOW}Note: Composer setup takes 20-30 minutes. You can run this separately if needed.${NC}"
            read -p "Do you want to set up Composer now? (y/N): " setup_composer
            if [ "$setup_composer" = "y" ] || [ "$setup_composer" = "Y" ]; then
                chmod +x setup-composer.sh
                ./setup-composer.sh $PROJECT_ID $REGION
            else
                echo "Skipping Composer setup. You can run it later with:"
                echo "./setup-composer.sh $PROJECT_ID $REGION"
            fi
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $service setup completed${NC}"
    else
        echo -e "${RED}✗ $service setup failed${NC}"
        echo "Check the logs above for errors."
        exit 1
    fi
    echo ""
done

# Create a comprehensive status check script
cat > check_pipeline_status.sh << EOF
#!/bin/bash

# Comprehensive pipeline status check script
PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
ZONE="$ZONE"

echo "=========================================="
echo "  Data Pipeline Status Check"
echo "=========================================="
echo ""

echo "Project: \$PROJECT_ID"
echo "Region: \$REGION"
echo "Zone: \$ZONE"
echo ""

# Check GCS buckets
echo "=== Google Cloud Storage ==="
echo "Raw data bucket:"
gsutil ls gs://\${PROJECT_ID}-raw-data/ 2>/dev/null && echo "✓ Available" || echo "✗ Not found"
echo "Processed data bucket:"
gsutil ls gs://\${PROJECT_ID}-processed-data/ 2>/dev/null && echo "✓ Available" || echo "✗ Not found"
echo ""

# Check Pub/Sub
echo "=== Pub/Sub ==="
echo "Topics:"
gcloud pubsub topics list --format="value(name)" | grep -E "(data-ingestion-topic|dataproc-trigger-topic)" | wc -l | xargs echo "Found topics:"
echo "Subscriptions:"
gcloud pubsub subscriptions list --format="value(name)" | grep -E "(data-ingestion-subscription|dataproc-trigger-subscription)" | wc -l | xargs echo "Found subscriptions:"
echo ""

# Check BigQuery
echo "=== BigQuery ==="
echo "Datasets:"
bq ls -d | grep -E "(staging_dataset|final_dataset)" | wc -l | xargs echo "Found datasets:"
echo "Tables:"
bq ls staging_dataset 2>/dev/null | wc -l | xargs echo "Staging tables:"
bq ls final_dataset 2>/dev/null | wc -l | xargs echo "Final tables:"
echo ""

# Check Cloud Functions
echo "=== Cloud Functions ==="
gcloud functions list --regions=\$REGION --format="value(name)" | wc -l | xargs echo "Deployed functions:"
echo ""

# Check Dataproc
echo "=== Dataproc ==="
DATAPROC_STATUS=\$(gcloud dataproc clusters describe data-processing-cluster --region=\$REGION --format="value(status.state)" 2>/dev/null || echo "NOT_FOUND")
echo "Cluster status: \$DATAPROC_STATUS"
echo ""

# Check GKE
echo "=== Google Kubernetes Engine ==="
GKE_STATUS=\$(gcloud container clusters describe dashboard-cluster --zone=\$ZONE --format="value(status)" 2>/dev/null || echo "NOT_FOUND")
echo "Cluster status: \$GKE_STATUS"
if [ "\$GKE_STATUS" = "RUNNING" ]; then
    echo "Kubernetes resources:"
    kubectl get all -n dashboard 2>/dev/null || echo "Cannot connect to cluster"
fi
echo ""

# Check Composer
echo "=== Cloud Composer ==="
COMPOSER_STATUS=\$(gcloud composer environments describe data-pipeline-composer --location=\$REGION --format="value(state)" 2>/dev/null || echo "NOT_FOUND")
echo "Environment status: \$COMPOSER_STATUS"
if [ "\$COMPOSER_STATUS" = "RUNNING" ]; then
    echo "Airflow UI:"
    gcloud composer environments describe data-pipeline-composer --location=\$REGION --format="value(config.airflowUri)" 2>/dev/null || echo "Not available"
fi
echo ""

# Check service account
echo "=== Service Account ==="
SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@\${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts describe \$SERVICE_ACCOUNT_EMAIL >/dev/null 2>&1 && echo "✓ Service account exists" || echo "✗ Service account not found"
echo ""

echo "=========================================="
echo "Status check completed!"
echo "=========================================="
EOF

chmod +x check_pipeline_status.sh

# Create cleanup script
cat > cleanup_pipeline.sh << EOF
#!/bin/bash

# Pipeline cleanup script
PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
ZONE="$ZONE"

echo "=========================================="
echo "  Data Pipeline Cleanup Script"
echo "=========================================="
echo ""
echo "WARNING: This will delete ALL pipeline resources!"
echo "Project: \$PROJECT_ID"
echo ""

read -p "Are you sure you want to delete all resources? (type 'yes' to confirm): " confirm

if [ "\$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."

# Delete GKE cluster
echo "Deleting GKE cluster..."
gcloud container clusters delete dashboard-cluster --zone=\$ZONE --project=\$PROJECT_ID --quiet 2>/dev/null || echo "GKE cluster not found"

# Delete Dataproc cluster
echo "Deleting Dataproc cluster..."
gcloud dataproc clusters delete data-processing-cluster --region=\$REGION --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Dataproc cluster not found"

# Delete Composer environment
echo "Deleting Composer environment..."
gcloud composer environments delete data-pipeline-composer --location=\$REGION --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Composer environment not found"

# Delete Cloud Functions
echo "Deleting Cloud Functions..."
gcloud functions delete gcs-to-bq-processor --region=\$REGION --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Function gcs-to-bq-processor not found"
gcloud functions delete dataproc-job-trigger --region=\$REGION --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Function dataproc-job-trigger not found"

# Delete BigQuery datasets
echo "Deleting BigQuery datasets..."
bq rm -r -f staging_dataset 2>/dev/null || echo "Staging dataset not found"
bq rm -r -f final_dataset 2>/dev/null || echo "Final dataset not found"

# Delete Pub/Sub topics and subscriptions
echo "Deleting Pub/Sub resources..."
gcloud pubsub subscriptions delete data-ingestion-subscription --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Subscription not found"
gcloud pubsub subscriptions delete dataproc-trigger-subscription --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Subscription not found"
gcloud pubsub topics delete data-ingestion-topic --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Topic not found"
gcloud pubsub topics delete dataproc-trigger-topic --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Topic not found"

# Delete GCS buckets
echo "Deleting GCS buckets..."
gsutil rm -r gs://\${PROJECT_ID}-raw-data/ 2>/dev/null || echo "Raw data bucket not found"
gsutil rm -r gs://\${PROJECT_ID}-processed-data/ 2>/dev/null || echo "Processed data bucket not found"

# Delete VPC resources
echo "Deleting VPC resources..."
gcloud compute firewall-rules delete dataproc-internal --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Firewall rule not found"
gcloud compute firewall-rules delete dataproc-ssh --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Firewall rule not found"
gcloud compute networks subnets delete data-pipeline-subnet --region=\$REGION --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Subnet not found"
gcloud compute networks delete data-pipeline-vpc --project=\$PROJECT_ID --quiet 2>/dev/null || echo "VPC not found"

# Delete service account
echo "Deleting service account..."
gcloud iam service-accounts delete data-pipeline-sa@\${PROJECT_ID}.iam.gserviceaccount.com --project=\$PROJECT_ID --quiet 2>/dev/null || echo "Service account not found"

echo ""
echo "Cleanup completed!"
echo "Note: Some resources may take a few minutes to be fully deleted."
EOF

chmod +x cleanup_pipeline.sh

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Data pipeline setup completed successfully!${NC}"
echo ""
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo ""
echo "Management scripts created:"
echo "  ✓ check_pipeline_status.sh - Check status of all services"
echo "  ✓ cleanup_pipeline.sh - Clean up all resources"
echo ""
echo "Individual service management scripts:"
echo "  ✓ manage_dataproc_cluster.sh - Manage Dataproc cluster"
echo "  ✓ manage_gke_cluster.sh - Manage GKE cluster"
echo "  ✓ manage_composer.sh - Manage Composer environment"
echo "  ✓ submit_dataproc_job.sh - Submit Spark jobs"
echo "  ✓ update_gke_deployment.sh - Update GKE deployments"
echo ""
echo "Next steps:"
echo "1. Check pipeline status: ./check_pipeline_status.sh"
echo "2. Access dashboard at: http://\$(kubectl get svc dashboard-service -n dashboard -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
if [ "$setup_composer" != "y" ] && [ "$setup_composer" != "Y" ]; then
    echo "3. Set up Composer: ./setup-composer.sh $PROJECT_ID $REGION"
fi
echo ""
echo -e "${YELLOW}Important: If you set up Composer, it will take 20-30 minutes to be ready.${NC}"
echo ""
echo "For detailed documentation, see SETUP_GUIDE.md"
