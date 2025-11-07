#!/bin/bash

# Step 5: Setup Pub/Sub Topics and Subscriptions
# This script creates Pub/Sub topics and subscriptions for the data pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 5: Setup Pub/Sub${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Define topics and their descriptions
TOPICS=(
    "sensor-data:Raw sensor data ingestion"
    "processed-data:Processed data notifications"
    "error-notifications:Error and alert notifications"
    "batch-job-status:Batch job status updates"
    "data-quality-alerts:Data quality monitoring alerts"
)

echo -e "${YELLOW}Creating Pub/Sub topics...${NC}"
echo ""

for topic_info in "${TOPICS[@]}"; do
    IFS=':' read -r topic_name description <<< "$topic_info"
    
    echo -n "Creating topic: $topic_name ($description)... "
    
    # Check if topic already exists
    if gcloud pubsub topics describe $topic_name --project=$PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}already exists${NC}"
    else
        if gcloud pubsub topics create $topic_name --project=$PROJECT_ID; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
            echo -e "${RED}Error creating topic: $topic_name${NC}"
            exit 1
        fi
    fi
done

echo ""
echo -e "${YELLOW}Creating Pub/Sub subscriptions...${NC}"
echo ""

# Define subscriptions with their topics and configurations
SUBSCRIPTIONS=(
    "sensor-data-processing:sensor-data:600:For processing sensor data"
    "sensor-data-archive:sensor-data:3600:For archiving sensor data"
    "processed-data-notification:processed-data:300:For notifying about processed data"
    "error-alerts:error-notifications:86400:For error monitoring"
    "batch-job-monitoring:batch-job-status:1800:For monitoring batch jobs"
    "data-quality-monitoring:data-quality-alerts:1800:For data quality alerts"
)

for sub_info in "${SUBSCRIPTIONS[@]}"; do
    IFS=':' read -r sub_name topic_name ack_deadline description <<< "$sub_info"
    
    echo -n "Creating subscription: $sub_name ($description)... "
    
    # Check if subscription already exists
    if gcloud pubsub subscriptions describe $sub_name --project=$PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}already exists${NC}"
    else
        if gcloud pubsub subscriptions create $sub_name \
            --topic=$topic_name \
            --ack-deadline=$ack_deadline \
            --project=$PROJECT_ID; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
            echo -e "${RED}Error creating subscription: $sub_name${NC}"
            exit 1
        fi
    fi
done

echo ""
echo -e "${YELLOW}Setting up dead letter queues for critical subscriptions...${NC}"

# Create dead letter topics
DLQ_TOPICS=(
    "sensor-data-dlq:Dead letter queue for sensor data"
    "processed-data-dlq:Dead letter queue for processed data"
)

for dlq_info in "${DLQ_TOPICS[@]}"; do
    IFS=':' read -r dlq_topic description <<< "$dlq_info"
    
    echo -n "Creating DLQ topic: $dlq_topic... "
    
    if gcloud pubsub topics describe $dlq_topic --project=$PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}already exists${NC}"
    else
        if gcloud pubsub topics create $dlq_topic --project=$PROJECT_ID; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    fi
done

# Create DLQ subscriptions
DLQ_SUBSCRIPTIONS=(
    "sensor-data-dlq-sub:sensor-data-dlq:86400"
    "processed-data-dlq-sub:processed-data-dlq:86400"
)

for dlq_sub_info in "${DLQ_SUBSCRIPTIONS[@]}"; do
    IFS=':' read -r dlq_sub dlq_topic ack_deadline <<< "$dlq_sub_info"
    
    echo -n "Creating DLQ subscription: $dlq_sub... "
    
    if gcloud pubsub subscriptions describe $dlq_sub --project=$PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}already exists${NC}"
    else
        if gcloud pubsub subscriptions create $dlq_sub \
            --topic=$dlq_topic \
            --ack-deadline=$ack_deadline \
            --project=$PROJECT_ID; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    fi
done

echo ""
echo -e "${YELLOW}Testing Pub/Sub setup...${NC}"

# Test by publishing a sample message
TEST_TOPIC="sensor-data"
echo -n "Publishing test message to $TEST_TOPIC... "

if echo '{"test": "message", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | \
   gcloud pubsub topics publish $TEST_TOPIC --message=- --project=$PROJECT_ID; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo ""
echo -e "${GREEN}Pub/Sub setup completed!${NC}"
echo ""
echo -e "${YELLOW}Created Topics:${NC}"
for topic_info in "${TOPICS[@]}"; do
    IFS=':' read -r topic_name description <<< "$topic_info"
    echo "  • $topic_name - $description"
done

echo ""
echo -e "${YELLOW}Created Subscriptions:${NC}"
for sub_info in "${SUBSCRIPTIONS[@]}"; do
    IFS=':' read -r sub_name topic_name ack_deadline description <<< "$sub_info"
    echo "  • $sub_name (topic: $topic_name) - $description"
done

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Publish message: gcloud pubsub topics publish TOPIC_NAME --message='MESSAGE'"
echo "  Pull messages: gcloud pubsub subscriptions pull SUBSCRIPTION_NAME --auto-ack"
echo "  View topics: gcloud pubsub topics list"
echo "  View subscriptions: gcloud pubsub subscriptions list"
echo ""
echo "Next step: Run './step6-setup-bigquery.sh' to create BigQuery datasets and tables"
