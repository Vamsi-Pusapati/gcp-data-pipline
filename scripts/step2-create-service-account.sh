#!/bin/bash

# Step 2: Create Service Account and Assign Required Roles
# This script creates a service account for the data pipeline with all necessary permissions

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}
SERVICE_ACCOUNT_NAME="data-pipeline-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="service-account-key.json"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 2: Create Service Account${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Check if service account already exists
echo -e "${YELLOW}Checking if service account exists...${NC}"
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}Service account already exists. Skipping creation.${NC}"
else
    echo -e "${YELLOW}Creating service account...${NC}"
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --description="Service account for data pipeline operations" \
        --display-name="Data Pipeline Service Account" \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✓ Service account created${NC}"
fi

echo ""
echo -e "${YELLOW}Assigning required roles to service account...${NC}"

# List of required roles for the data pipeline
ROLES=(
    "roles/storage.admin"                    # Cloud Storage admin
    "roles/pubsub.admin"                     # Pub/Sub admin
    "roles/cloudfunctions.admin"             # Cloud Functions admin
    "roles/bigquery.admin"                   # BigQuery admin
    "roles/dataproc.editor"                  # Dataproc editor
    "roles/container.admin"                  # GKE admin
    "roles/composer.worker"                  # Composer worker
    "roles/composer.admin"                   # Composer admin (for environment creation)
    "roles/iam.serviceAccountUser"           # Service account user
    "roles/cloudsql.client"                  # Cloud SQL client
    "roles/monitoring.editor"                # Monitoring editor
    "roles/logging.logWriter"                # Logging writer
    "roles/cloudbuild.builds.editor"         # Cloud Build editor
)

# Assign roles
for role in "${ROLES[@]}"; do
    echo -n "Assigning $role... "
    if gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role" \
        --quiet &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        echo -e "${RED}Error assigning $role${NC}"
        exit 1
    fi
done

echo ""
echo -e "${YELLOW}Creating service account key...${NC}"

# Create the service-account directory if it doesn't exist
mkdir -p ../service-account

# Create and download service account key
if gcloud iam service-accounts keys create "../service-account/$KEY_FILE" \
    --iam-account=$SERVICE_ACCOUNT_EMAIL \
    --project=$PROJECT_ID; then
    echo -e "${GREEN}✓ Service account key created${NC}"
else
    echo -e "${RED}✗ Failed to create service account key${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Service account setup completed!${NC}"
echo ""
echo "Service Account Details:"
echo "  Email: $SERVICE_ACCOUNT_EMAIL"
echo "  Key file: ../service-account/$KEY_FILE"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "1. The service account key has been saved to '../service-account/$KEY_FILE'"
echo "2. Keep this key file secure and never commit it to version control"
echo "3. Set the GOOGLE_APPLICATION_CREDENTIALS environment variable:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"\$(pwd)/../service-account/$KEY_FILE\""
echo ""
echo "Next step: Run './step3-setup-composer.sh' to create the Composer environment"
