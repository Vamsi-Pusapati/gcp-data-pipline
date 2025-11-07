#!/bin/bash

# Make all setup scripts executable
# This script should be run first to ensure all other scripts can be executed

echo "Making all setup scripts executable..."

# Make all step scripts executable
chmod +x step*.sh
chmod +x complete-setup.sh
chmod +x setup-*.sh
chmod +x quick-setup.sh

echo "✅ All scripts are now executable!"
echo ""
echo "Available scripts:"
echo ""
echo "🚀 RECOMMENDED: Complete automated setup"
echo "  ./complete-setup.sh gcp-project-deliverable"
echo ""
echo "🔢 Step-by-step setup (run in order):"
echo "  ./step1-enable-apis.sh gcp-project-deliverable"
echo "  ./step2-create-service-account.sh gcp-project-deliverable" 
echo "  ./step3-setup-composer.sh gcp-project-deliverable"
echo "  ./step4-setup-gcs.sh gcp-project-deliverable"
echo "  ./step5-setup-pubsub.sh gcp-project-deliverable"
echo "  ./step6-setup-bigquery.sh gcp-project-deliverable"
echo "  ./step7-setup-cloud-functions.sh gcp-project-deliverable"
echo "  ./step8-setup-dataproc.sh gcp-project-deliverable"
echo "  ./step9-setup-gke.sh gcp-project-deliverable"
echo "  ./step10-setup-react-dashboard.sh gcp-project-deliverable"
echo ""
echo "🛠️ Legacy scripts (individual services):"
echo "  ./setup-all.sh"
echo "  ./quick-setup.sh"
echo "  ./setup-gcs.sh"
echo "  ./setup-pubsub.sh"
echo "  ./setup-bigquery.sh"
echo "  ./setup-cloud-functions.sh"
echo "  ./setup-dataproc.sh"
echo "  ./setup-gke.sh"
echo "  ./setup-composer.sh"
echo ""
echo "Start with: ./complete-setup.sh gcp-project-deliverable"
