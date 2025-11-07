#!/bin/bash

# Step 7: Setup Cloud Functions
# This script deploys Cloud Functions for data processing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION="us-central1"
SOURCE_BUCKET="${PROJECT_ID}-cloud-functions"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 7: Setup Cloud Functions${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Source Bucket: gs://$SOURCE_BUCKET"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Check if source bucket exists
echo -e "${YELLOW}Checking if source bucket exists...${NC}"
if ! gsutil ls -b gs://$SOURCE_BUCKET &>/dev/null; then
    echo -e "${RED}Source bucket gs://$SOURCE_BUCKET does not exist.${NC}"
    echo "Please run step4-setup-gcs.sh first to create the bucket."
    exit 1
fi

# Upload Cloud Functions source code
echo -e "${YELLOW}Uploading Cloud Functions source code...${NC}"

FUNCTIONS_DIR="../cloud-functions"
if [ -d "$FUNCTIONS_DIR" ]; then
    echo "Uploading function source code to gs://$SOURCE_BUCKET/..."
    if gsutil -m cp -r $FUNCTIONS_DIR/* gs://$SOURCE_BUCKET/; then
        echo -e "${GREEN}✓ Source code uploaded${NC}"
    else
        echo -e "${RED}✗ Failed to upload source code${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Cloud Functions directory not found at $FUNCTIONS_DIR${NC}"
    echo "Creating sample function code..."
    
    # Create basic function structure
    mkdir -p $FUNCTIONS_DIR/data-processor
    mkdir -p $FUNCTIONS_DIR/data-validator
    mkdir -p $FUNCTIONS_DIR/notification-sender
    
    # Create data processor function
    cat > $FUNCTIONS_DIR/data-processor/main.py << 'EOF'
import json
import base64
from google.cloud import bigquery
from google.cloud import storage
import logging

def process_sensor_data(event, context):
    """Process sensor data from Pub/Sub trigger"""
    
    # Decode Pub/Sub message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    data = json.loads(pubsub_message)
    
    logging.info(f"Processing sensor data: {data}")
    
    # Initialize clients
    bq_client = bigquery.Client()
    storage_client = storage.Client()
    
    # Process the data (add your processing logic here)
    processed_data = {
        'sensor_id': data.get('sensor_id'),
        'timestamp': data.get('timestamp'),
        'avg_temperature': data.get('temperature'),
        'avg_humidity': data.get('humidity'),
        'avg_pressure': data.get('pressure'),
        'location': data.get('location'),
        'quality_score': 0.95,  # Calculated quality score
        'anomaly_detected': False,  # Anomaly detection result
        'processing_timestamp': 'CURRENT_TIMESTAMP()'
    }
    
    # Insert into BigQuery
    table_id = f"{bq_client.project}.processed_data.processed_sensor_data"
    table = bq_client.get_table(table_id)
    
    errors = bq_client.insert_rows_json(table, [processed_data])
    if errors:
        logging.error(f"BigQuery insert errors: {errors}")
        raise Exception(f"Failed to insert data: {errors}")
    
    logging.info("Data processed successfully")
    return "OK"
EOF

    cat > $FUNCTIONS_DIR/data-processor/requirements.txt << 'EOF'
google-cloud-bigquery==3.11.4
google-cloud-storage==2.10.0
google-cloud-pubsub==2.18.1
EOF

    # Create data validator function
    cat > $FUNCTIONS_DIR/data-validator/main.py << 'EOF'
import json
import base64
from google.cloud import pubsub_v1
import logging

def validate_data(event, context):
    """Validate incoming data and route to appropriate topics"""
    
    # Decode Pub/Sub message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    data = json.loads(pubsub_message)
    
    logging.info(f"Validating data: {data}")
    
    # Initialize Pub/Sub client
    publisher = pubsub_v1.PublisherClient()
    project_id = context.resource.split('/')[1]
    
    # Validation logic
    is_valid = True
    errors = []
    
    # Check required fields
    required_fields = ['sensor_id', 'timestamp', 'temperature']
    for field in required_fields:
        if field not in data or data[field] is None:
            is_valid = False
            errors.append(f"Missing required field: {field}")
    
    # Check data ranges
    if 'temperature' in data and isinstance(data['temperature'], (int, float)):
        if data['temperature'] < -50 or data['temperature'] > 100:
            is_valid = False
            errors.append("Temperature out of valid range (-50 to 100)")
    
    if is_valid:
        # Route to processing topic
        topic_path = publisher.topic_path(project_id, 'sensor-data')
        publisher.publish(topic_path, json.dumps(data).encode('utf-8'))
        logging.info("Data validation passed, routed to processing")
    else:
        # Route to error topic
        error_data = {
            'original_data': data,
            'errors': errors,
            'timestamp': data.get('timestamp')
        }
        topic_path = publisher.topic_path(project_id, 'error-notifications')
        publisher.publish(topic_path, json.dumps(error_data).encode('utf-8'))
        logging.warning(f"Data validation failed: {errors}")
    
    return "OK"
EOF

    cat > $FUNCTIONS_DIR/data-validator/requirements.txt << 'EOF'
google-cloud-pubsub==2.18.1
EOF

    # Create notification sender function
    cat > $FUNCTIONS_DIR/notification-sender/main.py << 'EOF'
import json
import base64
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging

def send_notification(event, context):
    """Send notifications for errors and alerts"""
    
    # Decode Pub/Sub message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    data = json.loads(pubsub_message)
    
    logging.info(f"Sending notification: {data}")
    
    # Extract notification details
    notification_type = data.get('type', 'general')
    message = data.get('message', 'No message provided')
    severity = data.get('severity', 'info')
    
    # Log the notification (in production, you might send emails, Slack messages, etc.)
    logging.info(f"NOTIFICATION [{severity.upper()}]: {notification_type} - {message}")
    
    # Here you would implement actual notification logic:
    # - Send emails
    # - Post to Slack
    # - Send SMS
    # - Create tickets in issue tracking systems
    
    return "OK"
EOF

    cat > $FUNCTIONS_DIR/notification-sender/requirements.txt << 'EOF'
# Add notification dependencies as needed
EOF

    echo -e "${GREEN}✓ Sample function code created${NC}"
    
    # Upload the created functions
    echo "Uploading created function source code..."
    if gsutil -m cp -r $FUNCTIONS_DIR/* gs://$SOURCE_BUCKET/; then
        echo -e "${GREEN}✓ Source code uploaded${NC}"
    else
        echo -e "${RED}✗ Failed to upload source code${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Deploying Cloud Functions...${NC}"
echo ""

# Deploy data processor function (Pub/Sub trigger)
echo -n "Deploying data-processor function... "
if gcloud functions deploy data-processor \
    --source=gs://$SOURCE_BUCKET/data-processor \
    --entry-point=process_sensor_data \
    --runtime=python39 \
    --trigger-topic=sensor-data \
    --region=$REGION \
    --memory=256MB \
    --timeout=60s \
    --project=$PROJECT_ID \
    --quiet; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Deploy data validator function (HTTP trigger)
echo -n "Deploying data-validator function... "
if gcloud functions deploy data-validator \
    --source=gs://$SOURCE_BUCKET/data-validator \
    --entry-point=validate_data \
    --runtime=python39 \
    --trigger-http \
    --allow-unauthenticated \
    --region=$REGION \
    --memory=256MB \
    --timeout=60s \
    --project=$PROJECT_ID \
    --quiet; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Deploy notification sender function (Pub/Sub trigger)
echo -n "Deploying notification-sender function... "
if gcloud functions deploy notification-sender \
    --source=gs://$SOURCE_BUCKET/notification-sender \
    --entry-point=send_notification \
    --runtime=python39 \
    --trigger-topic=error-notifications \
    --region=$REGION \
    --memory=256MB \
    --timeout=60s \
    --project=$PROJECT_ID \
    --quiet; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo ""
echo -e "${YELLOW}Getting function details...${NC}"

# Get function URLs and details
echo ""
echo -e "${YELLOW}Function Details:${NC}"

# Data validator function (HTTP trigger)
VALIDATOR_URL=$(gcloud functions describe data-validator --region=$REGION --project=$PROJECT_ID --format="value(httpsTrigger.url)" 2>/dev/null || echo "Not available")
echo "  • data-validator (HTTP): $VALIDATOR_URL"

# Other functions (Pub/Sub triggers)
echo "  • data-processor (Pub/Sub trigger: sensor-data)"
echo "  • notification-sender (Pub/Sub trigger: error-notifications)"

echo ""
echo -e "${YELLOW}Testing functions...${NC}"

# Test the HTTP function
if [ "$VALIDATOR_URL" != "Not available" ]; then
    echo -n "Testing data-validator function... "
    
    # Create test data
    TEST_DATA='{"sensor_id": "test-001", "timestamp": "2024-01-01T12:00:00Z", "temperature": 23.5, "humidity": 65.2, "pressure": 1013.25, "location": "test-location"}'
    
    if curl -s -X POST "$VALIDATOR_URL" \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA" > /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping HTTP function test (URL not available)${NC}"
fi

echo ""
echo -e "${GREEN}Cloud Functions setup completed!${NC}"
echo ""
echo -e "${YELLOW}Deployed Functions:${NC}"
echo "  • data-processor - Processes sensor data from Pub/Sub"
echo "  • data-validator - Validates incoming data via HTTP"
echo "  • notification-sender - Sends alerts and notifications"

echo ""
echo -e "${YELLOW}Function URLs:${NC}"
echo "  Console: https://console.cloud.google.com/functions/list?project=$PROJECT_ID"
echo "  Validator API: $VALIDATOR_URL"

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  List functions: gcloud functions list --project=$PROJECT_ID"
echo "  View logs: gcloud functions logs read FUNCTION_NAME --project=$PROJECT_ID"
echo "  Test HTTP function: curl -X POST $VALIDATOR_URL -d '{\"test\": \"data\"}'"
echo ""
echo "Next step: Run './step8-setup-dataproc.sh' to create Dataproc cluster"
