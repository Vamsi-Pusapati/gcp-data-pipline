#!/bin/bash

# Complete Data Pipeline Setup Script
# This script runs all setup steps in sequence to create a complete Google Cloud data pipeline

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}

echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}  🚀 COMPLETE DATA PIPELINE SETUP${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""
echo -e "${CYAN}Project ID: $PROJECT_ID${NC}"
echo -e "${CYAN}Setup Date: $(date)${NC}"
echo ""
echo -e "${YELLOW}This script will set up a complete Google Cloud data pipeline including:${NC}"
echo "  • Google Cloud APIs"
echo "  • Service Account with required permissions"
echo "  • Cloud Composer environment"
echo "  • Cloud Storage buckets"
echo "  • Pub/Sub topics and subscriptions"
echo "  • BigQuery datasets and tables"
echo "  • Cloud Functions"
echo "  • Dataproc cluster"
echo "  • Google Kubernetes Engine cluster"
echo "  • React dashboard"
echo ""

# Confirmation prompt
read -p "$(echo -e ${CYAN}"Do you want to proceed with the complete setup? (y/N): "${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Starting complete data pipeline setup...${NC}"
echo ""

# Track start time
START_TIME=$(date +%s)
STEP_COUNT=10
CURRENT_STEP=0

# Function to display step progress
step_header() {
    local step_num=$1
    local step_name="$2"
    local description="$3"
    
    CURRENT_STEP=$step_num
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}  Step $step_num/$STEP_COUNT: $step_name${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${CYAN}$description${NC}"
    echo ""
}

# Function to check if step completed successfully
check_step() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Step $CURRENT_STEP completed successfully${NC}"
    else
        echo -e "${RED}❌ Step $CURRENT_STEP failed${NC}"
        echo "Please check the error above and fix the issue."
        echo "You can resume from this step by running: ./step$CURRENT_STEP-*.sh"
        exit 1
    fi
}

# Step 1: Enable APIs
step_header 1 "Enable Google Cloud APIs" "Enabling all required Google Cloud APIs for the data pipeline"
./step1-enable-apis.sh $PROJECT_ID
check_step

# Step 2: Create Service Account
step_header 2 "Create Service Account" "Creating service account with required permissions for all services"
./step2-create-service-account.sh $PROJECT_ID
check_step

# Step 3: Setup Composer
step_header 3 "Setup Cloud Composer" "Creating Cloud Composer environment for workflow orchestration"
./step3-setup-composer.sh $PROJECT_ID
check_step

# Step 4: Setup GCS
step_header 4 "Setup Cloud Storage" "Creating GCS buckets for data storage and processing"
./step4-setup-gcs.sh $PROJECT_ID
check_step

# Step 5: Setup Pub/Sub
step_header 5 "Setup Pub/Sub" "Creating Pub/Sub topics and subscriptions for real-time messaging"
./step5-setup-pubsub.sh $PROJECT_ID
check_step

# Step 6: Setup BigQuery
step_header 6 "Setup BigQuery" "Creating BigQuery datasets and tables for analytics"
./step6-setup-bigquery.sh $PROJECT_ID
check_step

# Step 7: Setup Cloud Functions
step_header 7 "Setup Cloud Functions" "Deploying Cloud Functions for data processing"
./step7-setup-cloud-functions.sh $PROJECT_ID
check_step

# Step 8: Setup Dataproc
step_header 8 "Setup Dataproc" "Creating Dataproc cluster for big data processing"
./step8-setup-dataproc.sh $PROJECT_ID
check_step

# Step 9: Setup GKE
step_header 9 "Setup Google Kubernetes Engine" "Creating GKE cluster for containerized applications"
./step9-setup-gke.sh $PROJECT_ID
check_step

# Step 10: Setup React Dashboard
step_header 10 "Setup React Dashboard" "Deploying React dashboard for data visualization"
./step10-setup-react-dashboard.sh $PROJECT_ID
check_step

# Calculate total time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}  🎉 SETUP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""
echo -e "${GREEN}All 10 steps completed successfully in ${MINUTES}m ${SECONDS}s${NC}"
echo ""

# Display summary
echo -e "${YELLOW}📋 SETUP SUMMARY${NC}"
echo -e "${YELLOW}================${NC}"
echo ""
echo -e "${CYAN}Project:${NC} $PROJECT_ID"
echo -e "${CYAN}Services Created:${NC}"
echo "  ✅ Google Cloud APIs (enabled)"
echo "  ✅ Service Account (data-pipeline-sa)"
echo "  ✅ Cloud Composer (data-pipeline-composer)"
echo "  ✅ Cloud Storage (6 buckets)"
echo "  ✅ Pub/Sub (5 topics + subscriptions)"
echo "  ✅ BigQuery (4 datasets + tables)"
echo "  ✅ Cloud Functions (3 functions)"
echo "  ✅ Dataproc (data-processing-cluster)"
echo "  ✅ GKE (data-pipeline-gke)"
echo "  ✅ React Dashboard (deployed)"
echo ""

# Display important URLs
echo -e "${YELLOW}🔗 IMPORTANT URLS${NC}"
echo -e "${YELLOW}===============${NC}"
echo ""
echo -e "${CYAN}Google Cloud Console:${NC}"
echo "  • Project Overview: https://console.cloud.google.com/home/dashboard?project=$PROJECT_ID"
echo "  • Cloud Composer: https://console.cloud.google.com/composer/environments?project=$PROJECT_ID"
echo "  • BigQuery: https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
echo "  • Cloud Storage: https://console.cloud.google.com/storage/browser?project=$PROJECT_ID"
echo "  • Pub/Sub: https://console.cloud.google.com/cloudpubsub?project=$PROJECT_ID"
echo "  • Cloud Functions: https://console.cloud.google.com/functions/list?project=$PROJECT_ID"
echo "  • Dataproc: https://console.cloud.google.com/dataproc/clusters?project=$PROJECT_ID"
echo "  • GKE: https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID"
echo ""
echo -e "${CYAN}Dashboard:${NC}"
echo "  • Main Dashboard: https://storage.googleapis.com/${PROJECT_ID}-dashboard/index.html"
echo "  • Monitoring: https://storage.googleapis.com/${PROJECT_ID}-dashboard/monitoring.html"
echo ""

# Display next steps
echo -e "${YELLOW}🚀 NEXT STEPS${NC}"
echo -e "${YELLOW}============${NC}"
echo ""
echo "1. 🔐 Set up authentication:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"\$(pwd)/../service-account/service-account-key.json\""
echo ""
echo "2. 🧪 Test the pipeline:"
echo "   • Send test data to Pub/Sub topics"
echo "   • Check Cloud Functions logs"
echo "   • Verify data in BigQuery"
echo ""
echo "3. 📊 Customize the dashboard:"
echo "   • Update React components"
echo "   • Connect to BigQuery APIs"
echo "   • Add real-time monitoring"
echo ""
echo "4. 🔄 Schedule data workflows:"
echo "   • Configure Composer DAGs"
echo "   • Set up data ingestion schedules"
echo "   • Create monitoring alerts"
echo ""
echo "5. 🛡️ Secure the environment:"
echo "   • Review IAM permissions"
echo "   • Set up VPC network security"
echo "   • Configure SSL certificates"
echo ""

# Display useful commands
echo -e "${YELLOW}💻 USEFUL COMMANDS${NC}"
echo -e "${YELLOW}=================${NC}"
echo ""
echo -e "${CYAN}Test Pub/Sub:${NC}"
echo "  gcloud pubsub topics publish sensor-data --message='{\"sensor_id\": \"test-001\", \"temperature\": 23.5}'"
echo ""
echo -e "${CYAN}Query BigQuery:${NC}"
echo "  bq query --use_legacy_sql=false 'SELECT * FROM \`$PROJECT_ID.raw_data.sensor_data\` LIMIT 10'"
echo ""
echo -e "${CYAN}Check Cloud Functions:${NC}"
echo "  gcloud functions logs read data-processor --project=$PROJECT_ID"
echo ""
echo -e "${CYAN}Monitor Dataproc:${NC}"
echo "  gcloud dataproc jobs list --region=us-central1 --project=$PROJECT_ID"
echo ""
echo -e "${CYAN}Check GKE:${NC}"
echo "  kubectl get pods --all-namespaces"
echo ""

echo -e "${GREEN}🎊 Congratulations! Your Google Cloud data pipeline is ready to use!${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Save this output for reference and bookmark the console URLs.${NC}"
echo ""
