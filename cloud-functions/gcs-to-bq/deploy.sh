#!/bin/bash

# Deploy Medicaid GCS to BigQuery Cloud Function
# This function is triggered by Pub/Sub when GCS files are created

set -e

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
FUNCTION_NAME="medicaid-gcs-to-bq"
REGION=${2:-"us-central1"}
PUBSUB_TOPIC="gcs-medicaid-bucket-notifications"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Deploying Cloud Function: $FUNCTION_NAME${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Trigger: Pub/Sub topic $PUBSUB_TOPIC"

# Set gcloud project
gcloud config set project $PROJECT_ID

# Deploy the function
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=python311 \
    --region=$REGION \
    --source=. \
    --entry-point=process_medicaid_gcs_to_bq \
    --trigger-topic=$PUBSUB_TOPIC \
    --set-env-vars="GCP_PROJECT_ID=$PROJECT_ID,BQ_STAGING_DATASET=medicaid_staging,BQ_STAGING_TABLE=nadac_drugs" \
    --memory=512MB \
    --timeout=540s \
    --max-instances=10

echo -e "${GREEN}Cloud Function deployed successfully!${NC}"
echo ""
echo "Function details:"
echo "  - Name: $FUNCTION_NAME"
echo "  - Trigger: Pub/Sub topic '$PUBSUB_TOPIC'"
echo "  - Runtime: Python 3.11"
echo "  - Memory: 512MB"
echo "  - Timeout: 9 minutes"
echo ""
echo "Environment variables:"
echo "  - GCP_PROJECT_ID: $PROJECT_ID"
echo "  - BQ_STAGING_DATASET: medicaid_staging"
echo "  - BQ_STAGING_TABLE: nadac_drugs"
echo ""
echo "The function will process Medicaid JSON files from GCS and load them into BigQuery."
