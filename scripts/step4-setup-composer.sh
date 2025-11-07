#!/bin/bash

# Step 3: Setup Cloud Composer Environment
# This script creates a Cloud Composer environment for orchestrating the data pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}
COMPOSER_ENV_NAME="data-pipeline-composer"
REGION="us-central1"
ZONE="us-central1-a"
NODE_COUNT=3
MACHINE_TYPE="n1-standard-1"
DISK_SIZE="30GB"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 3: Setup Cloud Composer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Environment Name: $COMPOSER_ENV_NAME"
echo "Region: $REGION"
echo "Machine Type: $MACHINE_TYPE"
echo "Node Count: $NODE_COUNT"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Check if Composer environment already exists
echo -e "${YELLOW}Checking if Composer environment exists...${NC}"
if gcloud composer environments describe $COMPOSER_ENV_NAME --location=$REGION --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}Composer environment already exists. Skipping creation.${NC}"
    echo ""
    echo -e "${GREEN}Composer environment is ready!${NC}"
else
    echo -e "${YELLOW}Creating Cloud Composer environment...${NC}"
    echo "This will take approximately 15-25 minutes. Please be patient."
    echo ""
    echo -e "${BLUE}Running creation in background to prevent Cloud Shell timeout...${NC}"
    echo "You can monitor progress with: gcloud composer environments list --locations=$REGION"
    echo ""
    
    # Create log file for background process
    LOG_FILE="/tmp/composer-setup-$COMPOSER_ENV_NAME.log"
    echo "Logs will be written to: $LOG_FILE"
    echo ""
    
    # Create Composer environment in background
    echo "Starting Composer environment creation..."
    nohup gcloud composer environments create $COMPOSER_ENV_NAME \
        --location=$REGION \
        --zone=$ZONE \
        --machine-type=$MACHINE_TYPE \
        --node-count=$NODE_COUNT \
        --disk-size=$DISK_SIZE \
        --python-version=3 \
        --project=$PROJECT_ID > $LOG_FILE 2>&1 &
    
    COMPOSER_PID=$!
    echo "Background process PID: $COMPOSER_PID"
    echo "Creation started. You can:"
    echo "1. Check logs: tail -f $LOG_FILE"
    echo "2. Check status: gcloud composer environments list --locations=$REGION"
    echo "3. Wait for completion (this script will continue monitoring)..."
    echo ""
    
    # Monitor the creation process
    echo "Monitoring creation progress..."
    TIMEOUT=1800  # 30 minutes timeout
    ELAPSED=0
    SLEEP_INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if gcloud composer environments describe $COMPOSER_ENV_NAME --location=$REGION --project=$PROJECT_ID &>/dev/null; then
            echo -e "${GREEN}✓ Composer environment created successfully${NC}"
            break
        fi
        
        echo "Still creating... ($((ELAPSED/60)) minutes elapsed)"
        sleep $SLEEP_INTERVAL
        ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
        
        # Keep Cloud Shell alive by sending a simple command
        echo -n "." > /dev/null
    done
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "${RED}✗ Timeout waiting for Composer environment creation${NC}"
        echo "Check the status manually: gcloud composer environments list --locations=$REGION"
        echo "Check logs: cat $LOG_FILE"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Getting Composer environment details...${NC}"

# Get Composer environment details
COMPOSER_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format="value(config.dagGcsPrefix)" | sed 's|/dags||')

AIRFLOW_URI=$(gcloud composer environments describe $COMPOSER_ENV_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format="value(config.airflowUri)")

echo ""
echo -e "${GREEN}Composer Environment Details:${NC}"
echo "  Environment Name: $COMPOSER_ENV_NAME"
echo "  Region: $REGION"
echo "  Airflow URI: $AIRFLOW_URI"
echo "  GCS Bucket: $COMPOSER_BUCKET"
echo ""

# Upload DAGs to Composer environment
echo -e "${YELLOW}Uploading DAGs to Composer environment...${NC}"

DAG_SOURCE_DIR="../composer/dags"
if [ -d "$DAG_SOURCE_DIR" ]; then
    echo "Uploading DAG files..."
    if gsutil -m cp -r $DAG_SOURCE_DIR/* ${COMPOSER_BUCKET}/dags/; then
        echo -e "${GREEN}✓ DAGs uploaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to upload DAGs${NC}"
        echo "You can manually upload them later using:"
        echo "gsutil -m cp -r $DAG_SOURCE_DIR/* ${COMPOSER_BUCKET}/dags/"
    fi
else
    echo -e "${YELLOW}DAGs directory not found at $DAG_SOURCE_DIR${NC}"
    echo "DAGs can be uploaded later using:"
    echo "gsutil -m cp -r path/to/dags/* ${COMPOSER_BUCKET}/dags/"
fi

echo ""
echo -e "${GREEN}Cloud Composer setup completed!${NC}"
echo ""
echo -e "${YELLOW}Important Information:${NC}"
echo "1. Airflow UI: $AIRFLOW_URI"
echo "2. GCS Bucket: $COMPOSER_BUCKET"
echo "3. To upload additional DAGs:"
echo "   gsutil cp your_dag.py ${COMPOSER_BUCKET}/dags/"
echo "4. To update environment variables:"
echo "   gcloud composer environments update $COMPOSER_ENV_NAME --location=$REGION --update-env-variables KEY=VALUE"
echo ""
echo "Next step: Run './step4-setup-gcs.sh' to create GCS buckets"
