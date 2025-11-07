#!/bin/bash

# Quick Setup Script for gcp-project-deliverable
# This script sets up the entire data pipeline with your project configuration

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Data Pipeline Setup${NC}"
echo -e "${BLUE}  Project: gcp-project-deliverable${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

PROJECT_ID="gcp-project-deliverable"
REGION="us-central1"
ZONE="us-central1-a"

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"  
echo "  Zone: $ZONE"
echo ""

# Check if user wants to proceed
read -p "Do you want to set up the data pipeline with this configuration? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Setup cancelled."
    exit 0
fi

# Make sure we're in the scripts directory
cd "$(dirname "$0")"

# Run the main setup script
echo -e "${YELLOW}Starting automated setup...${NC}"
./setup-all.sh $PROJECT_ID $REGION $ZONE

echo ""
echo -e "${GREEN}Setup completed for project: $PROJECT_ID${NC}"
echo ""
echo "Next steps:"
echo "1. Check pipeline status: ./check_pipeline_status.sh"
echo "2. Access your dashboard once GKE is ready"
echo "3. Monitor logs and services as needed"
echo ""
echo "Your data pipeline is now ready to use!"
