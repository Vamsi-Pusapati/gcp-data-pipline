#!/bin/bash

# Step 1: Enable Required Google Cloud APIs
# This script enables all necessary APIs for the data pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 1: Enable Google Cloud APIs${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# List of APIs to enable
APIS=(
    "compute.googleapis.com"                # Compute Engine (for VMs, networks)
    "container.googleapis.com"              # Google Kubernetes Engine
    "bigquery.googleapis.com"               # BigQuery
    "storage.googleapis.com"                # Cloud Storage
    "pubsub.googleapis.com"                 # Pub/Sub
    "cloudfunctions.googleapis.com"         # Cloud Functions
    "dataproc.googleapis.com"               # Dataproc
    "composer.googleapis.com"               # Cloud Composer
    "iam.googleapis.com"                    # Identity and Access Management
    "cloudbuild.googleapis.com"             # Cloud Build
    "logging.googleapis.com"                # Cloud Logging
    "monitoring.googleapis.com"             # Cloud Monitoring
    "cloudresourcemanager.googleapis.com"   # Cloud Resource Manager
)

echo -e "${YELLOW}Enabling APIs...${NC}"
echo "This may take a few minutes for all APIs to be enabled."
echo ""

for api in "${APIS[@]}"; do
    echo -n "Enabling $api... "
    if gcloud services enable $api --quiet; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        echo -e "${RED}Error enabling $api${NC}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}All APIs enabled successfully!${NC}"
echo ""

# Verify enabled APIs
echo -e "${YELLOW}Verifying enabled APIs...${NC}"
echo "Checking a few key APIs:"

KEY_APIS=("bigquery.googleapis.com" "composer.googleapis.com" "dataproc.googleapis.com")

for api in "${KEY_APIS[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo -e "$api: ${GREEN}✓ Enabled${NC}"
    else
        echo -e "$api: ${RED}✗ Not enabled${NC}"
    fi
done

echo ""
echo -e "${GREEN}API enablement completed!${NC}"
echo ""
echo "Next step: Run './step2-create-service-account.sh' to create the service account"
