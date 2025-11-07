#!/bin/bash

# Dataproc Setup Script
# Creates Dataproc cluster for data processing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=${1:-"gcp-project-deliverable"}
REGION=${2:-"us-central1"}
ZONE=${3:-"us-central1-a"}

if [ "$PROJECT_ID" = "gcp-project-deliverable" ]; then
    echo -e "${YELLOW}Using default project ID: gcp-project-deliverable${NC}"
fi

echo -e "${GREEN}Setting up Dataproc...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"

# Set gcloud project
gcloud config set project $PROJECT_ID

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CLUSTER_NAME="medicaid-etl-cluster"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"  # Updated staging bucket per new command
JOBS_BUCKET="${PROJECT_ID}-dataproc-jobs"

# Ensure staging bucket exists for cluster (used by --bucket flag)
echo -e "${YELLOW}Ensuring staging bucket exists: gs://$STAGING_BUCKET${NC}"
if ! gsutil ls -p $PROJECT_ID gs://$STAGING_BUCKET >/dev/null 2>&1; then
  gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$STAGING_BUCKET/
  echo -e "${GREEN}Created staging bucket gs://$STAGING_BUCKET${NC}"
else
  echo -e "${YELLOW}Staging bucket already exists, skipping creation${NC}"
fi

# Remove custom VPC creation – use default network
echo -e "${YELLOW}Using default VPC network (default) and auto-created firewall rules${NC}"

# Grant missing Dataproc Worker role to service account (idempotent)
echo -e "${YELLOW}Granting Dataproc Worker role to service account (if not already granted)...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/dataproc.worker" >/dev/null || true

# Create Dataproc cluster with updated parameters
echo -e "${YELLOW}Creating Dataproc cluster with specified configuration: $CLUSTER_NAME${NC}"

gcloud dataproc clusters create $CLUSTER_NAME \
  --enable-component-gateway \
  --bucket $STAGING_BUCKET \
  --region $REGION \
  --no-address \
  --master-machine-type n4-standard-2 \
  --master-boot-disk-type hyperdisk-balanced \
  --master-boot-disk-size 100 \
  --num-workers 2 \
  --worker-machine-type n4-standard-2 \
  --worker-boot-disk-type hyperdisk-balanced \
  --worker-boot-disk-size 200 \
  --image-version 2.2-debian12 \
  --scopes https://www.googleapis.com/auth/cloud-platform \
  --service-account $SERVICE_ACCOUNT_EMAIL \
  --project $PROJECT_ID

# Create jobs bucket (if not exists)
echo -e "${YELLOW}Ensuring Dataproc jobs bucket exists: gs://$JOBS_BUCKET${NC}"
if ! gsutil ls -p $PROJECT_ID gs://$JOBS_BUCKET >/dev/null 2>&1; then
  gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$JOBS_BUCKET/
  echo -e "${GREEN}Created jobs bucket gs://$JOBS_BUCKET${NC}"
else
  echo -e "${YELLOW}Jobs bucket already exists, skipping creation${NC}"
fi
# Create jobs directory placeholder
echo "" | gsutil cp - gs://$JOBS_BUCKET/jobs/.keep

# Upload Spark job to GCS (jobs bucket)
echo -e "${YELLOW}Uploading Spark job to jobs bucket...${NC}"

gsutil cp ../dataproc/data_processing_job.py gs://$JOBS_BUCKET/jobs/data_processing_job.py

# Create a script to submit jobs easily
cat > submit_dataproc_job.sh << EOF
#!/bin/bash

# Script to submit Dataproc jobs easily
PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
CLUSTER_NAME="$CLUSTER_NAME"
JOB_NAME="data-processing-job-\$(date +%Y%m%d-%H%M%S)"
JOBS_BUCKET="$JOBS_BUCKET"

echo "Submitting Dataproc job: \$JOB_NAME"

gcloud dataproc jobs submit pyspark \
    gs://\$JOBS_BUCKET/jobs/data_processing_job.py \
    --cluster=\$CLUSTER_NAME \
    --region=\$REGION \
    --project=\$PROJECT_ID \
    --jars=gs://spark-lib/bigquery/spark-bigquery-latest_2.12.jar \
    --job-id=\$JOB_NAME \
    -- \
    --project-id=\$PROJECT_ID \
    --staging-dataset=medicaid_staging \
    --staging-table=nadac_drugs \
    --enriched-dataset=medicaid_enriched \
    --enriched-table=nadac_drugs_enriched

echo "Job submitted successfully: \$JOB_NAME"
echo "Monitor at: https://console.cloud.google.com/dataproc/jobs?project=\$PROJECT_ID"
EOF

chmod +x submit_dataproc_job.sh

# Create cluster management scripts
cat > manage_dataproc_cluster.sh << EOF
#!/bin/bash

ACTION=\${1:-"status"}
PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
CLUSTER_NAME="$CLUSTER_NAME"

case \$ACTION in
    "start")
        echo "Starting Dataproc cluster: \$CLUSTER_NAME"
        gcloud dataproc clusters start \$CLUSTER_NAME --region=\$REGION --project=\$PROJECT_ID
        ;;
    "stop")
        echo "Stopping Dataproc cluster: \$CLUSTER_NAME"
        gcloud dataproc clusters stop \$CLUSTER_NAME --region=\$REGION --project=\$PROJECT_ID
        ;;
    "delete")
        echo "Deleting Dataproc cluster: \$CLUSTER_NAME"
        gcloud dataproc clusters delete \$CLUSTER_NAME --region=\$REGION --project=\$PROJECT_ID --quiet
        ;;
    "status")
        echo "Checking Dataproc cluster status:"
        gcloud dataproc clusters describe \$CLUSTER_NAME --region=\$REGION --project=\$PROJECT_ID --format="value(status.state)"
        ;;
    "list-jobs")
        echo "Listing recent Dataproc jobs:"
        gcloud dataproc jobs list --region=\$REGION --project=\$PROJECT_ID --limit=10
        ;;
    *)
        echo "Usage: \$0 {start|stop|delete|status|list-jobs}"
        echo "  start      - Start the cluster"
        echo "  stop       - Stop the cluster"
        echo "  delete     - Delete the cluster"
        echo "  status     - Show cluster status"
        echo "  list-jobs  - List recent jobs"
        exit 1
        ;;
esac
EOF

chmod +x manage_dataproc_cluster.sh

echo -e "${GREEN}Dataproc setup completed successfully!${NC}"
echo "Cluster created: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo ""
echo "Management scripts created:"
echo "  - submit_dataproc_job.sh (submit processing jobs)"
echo "  - manage_dataproc_cluster.sh (start/stop/delete cluster)"
echo ""
echo "Cluster details:"
gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --format="table(clusterName,status.state,config.masterConfig.numInstances,config.workerConfig.numInstances)"
echo ""
echo "To submit a job:"
echo "  ./submit_dataproc_job.sh"
echo ""
echo "To manage cluster:"
echo "  ./manage_dataproc_cluster.sh {start|stop|delete|status|list-jobs}"
echo "Jobs bucket: gs://$JOBS_BUCKET"
