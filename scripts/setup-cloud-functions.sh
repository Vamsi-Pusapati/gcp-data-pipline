#!/bin/bash

# Cloud Functions Setup Script
# Deploys Cloud Functions for Medicaid data processing pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION=${2:-"us-central1"}
BUCKET_NAME="${PROJECT_ID}-medicaid-data-bucket"
PUBSUB_TOPIC="medicaid-data-notify"

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
fi

echo -e "${GREEN}Setting up Cloud Functions for Medicaid data pipeline...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "GCS Bucket: $BUCKET_NAME"
echo "Pub/Sub Topic: $PUBSUB_TOPIC"

# Set gcloud project
gcloud config set project $PROJECT_ID

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"
FUNCTION_NAME="medicaid-gcs-to-bq"

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"
FUNCTION_NAME="medicaid-gcs-to-bq"

# Create Medicaid GCS to BigQuery function (without deploying code)
echo -e "${YELLOW}Creating Cloud Function: $FUNCTION_NAME${NC}"
echo "Note: Function will be created with placeholder code. You can upload your code manually later."

# Create a minimal placeholder function
mkdir -p ../cloud-functions/temp-placeholder
cd ../cloud-functions/temp-placeholder

# Create minimal main.py placeholder
cat > main.py << 'EOF'
import functions_framework

@functions_framework.cloud_event
def process_medicaid_gcs_to_bq(cloud_event):
    """
    Placeholder function - upload your actual code manually
    """
    print("Placeholder function - replace with your actual implementation")
    return "OK"
EOF

# Create minimal requirements.txt
cat > requirements.txt << 'EOF'
functions-framework==3.*
google-cloud-bigquery==3.*
google-cloud-storage==2.*
EOF

# Deploy the placeholder function
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=python311 \
    --region=$REGION \
    --source=. \
    --entry-point=process_medicaid_gcs_to_bq \
    --trigger-topic=$PUBSUB_TOPIC \
    --service-account=$SERVICE_ACCOUNT_EMAIL \
    --set-env-vars="GCP_PROJECT_ID=$PROJECT_ID,BQ_STAGING_DATASET=medicaid_staging,BQ_STAGING_TABLE=nadac_drugs" \
    --memory=512MB \
    --timeout=540s \
    --max-instances=10

# Clean up placeholder files
cd ../..
rm -rf cloud-functions/temp-placeholder

cd scripts

# Grant necessary permissions for the Cloud Function
echo -e "${YELLOW}Setting up Cloud Function permissions...${NC}"

# Grant invoker role to service account
gcloud functions add-iam-policy-binding $FUNCTION_NAME \
    --region=$REGION \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/cloudfunctions.invoker"

# Grant Pub/Sub subscriber role to allow function to receive notifications
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/pubsub.subscriber"

# Grant necessary BigQuery permissions
echo -e "${YELLOW}Granting BigQuery permissions to service account...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.user"

# Grant IAM token creator role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/iam.serviceAccountTokenCreator"

echo -e "${GREEN}Medicaid Cloud Function created successfully!${NC}"
echo ""
echo "Function created:"
echo "  - Name: $FUNCTION_NAME"
echo "  - Trigger: Pub/Sub topic '$PUBSUB_TOPIC'"
echo "  - Runtime: Python 3.11"
echo "  - Entry point: process_medicaid_gcs_to_bq"
echo "  - Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "  - Status: Created with placeholder code"
echo ""
echo "Environment Variables:"
echo "  - GCP_PROJECT_ID: $PROJECT_ID"
echo "  - BQ_STAGING_DATASET: medicaid_staging"
echo "  - BQ_STAGING_TABLE: nadac_drugs"
echo ""
echo "Function Configuration:"
echo "  - Memory: 512MB"
echo "  - Timeout: 9 minutes"
echo "  - Max Instances: 10"
echo ""
echo "NEXT STEPS:"
echo "1. Upload your actual function code manually using:"
echo "   - Google Cloud Console Functions page"
echo "   - Or use 'gcloud functions deploy' with your source code"
echo ""
echo "2. The function is configured to be triggered by Pub/Sub topic: $PUBSUB_TOPIC"
echo "3. It will process files from: gs://$BUCKET_NAME/medicaid_data/raw/"
echo "4. And load data into: $PROJECT_ID.medicaid_staging.nadac_drugs"
