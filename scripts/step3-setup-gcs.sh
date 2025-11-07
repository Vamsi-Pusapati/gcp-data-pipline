#!/bin/bash

# Google Cloud Storage Setup Script
# Creates buckets for raw and processed data

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION=${2:-"us-central1"}

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
fi

echo -e "${GREEN}Setting up Google Cloud Storage and Pub/Sub...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Set gcloud project
gcloud config set project $PROJECT_ID

# Step 4: Setup Service Account (if needed)
SERVICE_ACCOUNT_NAME="data-pipeline-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${YELLOW}Step 4: Checking service account setup...${NC}"

# Check if service account exists
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL --project=$PROJECT_ID >/dev/null 2>&1; then
    echo -e "${GREEN}Service account $SERVICE_ACCOUNT_EMAIL already exists${NC}"
else
    echo -e "${YELLOW}Creating service account: $SERVICE_ACCOUNT_EMAIL${NC}"
    
    # Create service account
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --description="Service account for data pipeline operations" \
        --display-name="Data Pipeline Service Account" \
        --project=$PROJECT_ID
    
    echo -e "${YELLOW}Assigning required roles to service account...${NC}"
    
    # Assign necessary roles
    ROLES=(
        "roles/storage.admin"
        "roles/pubsub.admin"
        "roles/cloudfunctions.admin"
        "roles/bigquery.admin"
        "roles/dataproc.editor"
        "roles/container.admin"
        "roles/composer.worker"
        "roles/iam.serviceAccountUser"
    )
    
    for role in "${ROLES[@]}"; do
        echo "Assigning role: $role"
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
            --role="$role" \
            --quiet
    done
    
    echo -e "${GREEN}Service account created and configured${NC}"
fi

echo -e "${YELLOW}Step 5: Setting up infrastructure...${NC}"

# Create raw data bucket
RAW_BUCKET="${PROJECT_ID}-raw-data"
echo -e "${YELLOW}Creating raw data bucket: $RAW_BUCKET${NC}"

gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$RAW_BUCKET/

# Set lifecycle policy for raw data bucket (delete after 30 days)
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 30
        }
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://$RAW_BUCKET/
rm lifecycle.json

# Enable versioning on raw data bucket
gsutil versioning set on gs://$RAW_BUCKET/

# Set uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://$RAW_BUCKET/

# Grant access to service account
echo -e "${YELLOW}Granting access to service account: $SERVICE_ACCOUNT_EMAIL${NC}"
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectAdmin gs://$RAW_BUCKET/

echo -e "${GREEN}Setup completed successfully!${NC}"
echo "✓ Step 4: Service account configured"
echo "✓ Step 5: Infrastructure deployed"
echo ""
echo "Resources created:"
echo "- Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "- Raw data bucket: gs://$RAW_BUCKET"
echo "- Pub/Sub topic: $PUBSUB_TOPIC"
echo "- Bucket notification configured for: drug_data/raw/ uploads"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Deploy the Medicaid DAG to Cloud Composer"
echo "2. Enable the DAG in Airflow UI"
echo "3. Monitor data ingestion and Pub/Sub notifications"

# Create directory structure in raw data bucket
echo -e "${YELLOW}Creating directory structure...${NC}"
echo "" | gsutil cp - gs://$RAW_BUCKET/drug_data/raw/.keep
echo "" | gsutil cp - gs://$RAW_BUCKET/drug_data/processed/.keep

# Create Pub/Sub topic for GCS notifications
PUBSUB_TOPIC="medicaid-data-notify"
echo -e "${YELLOW}Creating Pub/Sub topic: $PUBSUB_TOPIC${NC}"

if gcloud pubsub topics describe $PUBSUB_TOPIC --project=$PROJECT_ID >/dev/null 2>&1; then
    echo -e "${YELLOW}Topic $PUBSUB_TOPIC already exists, skipping creation${NC}"
else
    gcloud pubsub topics create $PUBSUB_TOPIC --project=$PROJECT_ID
    echo -e "${GREEN}Created Pub/Sub topic: $PUBSUB_TOPIC${NC}"
fi

# Create bucket notification for raw data uploads
echo -e "${YELLOW}Setting up bucket notification for drug data uploads...${NC}"

# Check if notification already exists
EXISTING_NOTIFICATIONS=$(gcloud storage buckets notifications list gs://$RAW_BUCKET --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$EXISTING_NOTIFICATIONS" ]]; then
    echo -e "${YELLOW}Bucket notifications already exist, skipping creation${NC}"
    gcloud storage buckets notifications list gs://$RAW_BUCKET
else
    gcloud storage buckets notifications create gs://$RAW_BUCKET \
        --topic=$PUBSUB_TOPIC \
        --event-types=OBJECT_FINALIZE \
        --object-prefix=drug_data/raw/ \
        --payload-format=json \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}Created bucket notification for drug data uploads${NC}"
fi