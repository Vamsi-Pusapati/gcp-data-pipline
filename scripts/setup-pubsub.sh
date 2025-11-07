#!/bin/bash

# Pub/Sub Setup Script
# Creates topics and subscriptions for data pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
fi

echo -e "${GREEN}Setting up Pub/Sub...${NC}"
echo "Project: $PROJECT_ID"

# Set gcloud project
gcloud config set project $PROJECT_ID

# Create data ingestion topic
TOPIC_NAME="data-ingestion-topic"
echo -e "${YELLOW}Creating Pub/Sub topic: $TOPIC_NAME${NC}"

gcloud pubsub topics create $TOPIC_NAME

# Create subscription for data ingestion
SUBSCRIPTION_NAME="data-ingestion-subscription"
echo -e "${YELLOW}Creating Pub/Sub subscription: $SUBSCRIPTION_NAME${NC}"

gcloud pubsub subscriptions create $SUBSCRIPTION_NAME \
    --topic=$TOPIC_NAME \
    --message-retention-duration=600s \
    --expiration-period=never

# Create Dataproc trigger topic (for triggering Dataproc jobs)
DATAPROC_TOPIC="dataproc-trigger-topic"
echo -e "${YELLOW}Creating Dataproc trigger topic: $DATAPROC_TOPIC${NC}"

gcloud pubsub topics create $DATAPROC_TOPIC

# Create subscription for Dataproc trigger
DATAPROC_SUBSCRIPTION="dataproc-trigger-subscription"
echo -e "${YELLOW}Creating Dataproc trigger subscription: $DATAPROC_SUBSCRIPTION${NC}"

gcloud pubsub subscriptions create $DATAPROC_SUBSCRIPTION \
    --topic=$DATAPROC_TOPIC \
    --message-retention-duration=3600s \
    --expiration-period=never

# Grant permissions to service account
SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${YELLOW}Granting Pub/Sub permissions to service account: $SERVICE_ACCOUNT_EMAIL${NC}"

# Grant publisher role on topics
gcloud pubsub topics add-iam-policy-binding $TOPIC_NAME \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/pubsub.publisher"

gcloud pubsub topics add-iam-policy-binding $DATAPROC_TOPIC \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/pubsub.publisher"

# Grant subscriber role on subscriptions
gcloud pubsub subscriptions add-iam-policy-binding $SUBSCRIPTION_NAME \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/pubsub.subscriber"

gcloud pubsub subscriptions add-iam-policy-binding $DATAPROC_SUBSCRIPTION \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/pubsub.subscriber"

echo -e "${GREEN}Pub/Sub setup completed successfully!${NC}"
echo "Topics created:"
echo "  - $TOPIC_NAME"
echo "  - $DATAPROC_TOPIC"
echo "Subscriptions created:"
echo "  - $SUBSCRIPTION_NAME"
echo "  - $DATAPROC_SUBSCRIPTION"
