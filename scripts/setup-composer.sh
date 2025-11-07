#!/bin/bash

# Composer Setup Script
# Creates Cloud Composer environment for Airflow DAGs

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

echo -e "${GREEN}Setting up Cloud Composer...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Set gcloud project
gcloud config set project $PROJECT_ID

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"
COMPOSER_ENV="data-pipeline-composer"

# Enable Composer API
echo -e "${YELLOW}Enabling Cloud Composer API...${NC}"
gcloud services enable composer.googleapis.com

# Create Composer environment (this takes 20-30 minutes)
echo -e "${YELLOW}Creating Composer environment: $COMPOSER_ENV${NC}"
echo -e "${RED}Warning: This will take 20-30 minutes to complete!${NC}"

gcloud composer environments create $COMPOSER_ENV \
    --location=$REGION \
    --python-version=3 \
    --node-count=3 \
    --machine-type=e2-medium \
    --disk-size=50GB \
    --service-account=$SERVICE_ACCOUNT_EMAIL \
    --env-variables=GCP_PROJECT_ID=$PROJECT_ID,RAW_BUCKET=${PROJECT_ID}-raw-data \
    --tags=composer \
    --enable-private-ip \
    --master-ipv4-cidr=172.16.0.0/28 \
    --enable-ip-alias

# Wait for environment to be ready
echo -e "${YELLOW}Waiting for Composer environment to be ready...${NC}"
while true; do
    STATUS=$(gcloud composer environments describe $COMPOSER_ENV --location=$REGION --format="value(state)" 2>/dev/null || echo "CREATING")
    if [ "$STATUS" = "RUNNING" ]; then
        echo -e "${GREEN}Composer environment is ready!${NC}"
        break
    elif [ "$STATUS" = "ERROR" ]; then
        echo -e "${RED}Error creating Composer environment!${NC}"
        exit 1
    else
        echo "Environment status: $STATUS (waiting...)"
        sleep 60
    fi
done

# Get the DAGs bucket
echo -e "${YELLOW}Getting Composer DAGs bucket...${NC}"
DAGS_BUCKET=$(gcloud composer environments describe $COMPOSER_ENV \
    --location=$REGION \
    --format="value(config.dagGcsPrefix)")

echo "DAGs bucket: $DAGS_BUCKET"

# Upload DAG files
echo -e "${YELLOW}Uploading DAG files to Composer...${NC}"

# Copy the main data collection DAG
gsutil cp ../composer/dags/data_collection_dag.py $DAGS_BUCKET/

# Create additional DAGs for the pipeline
mkdir -p ../composer/dags/additional

# Create a DAG for monitoring pipeline health
cat > ../composer/dags/additional/pipeline_monitoring_dag.py << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCheckOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor
import logging
import os

# Configuration
PROJECT_ID = os.getenv('GCP_PROJECT_ID', 'your-gcp-project-id')

# Default arguments
default_args = {
    'owner': 'data-engineering-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# DAG definition
dag = DAG(
    'pipeline_monitoring',
    default_args=default_args,
    description='Monitor data pipeline health and performance',
    schedule_interval=timedelta(hours=6),  # Run every 6 hours
    catchup=False,
    tags=['monitoring', 'pipeline-health'],
)

def check_data_freshness(**context):
    """Check if data is being processed regularly"""
    from google.cloud import bigquery
    
    client = bigquery.Client(project=PROJECT_ID)
    
    # Check staging table freshness
    staging_query = f"""
        SELECT 
            MAX(timestamp) as latest_staging,
            COUNT(*) as staging_count
        FROM `{PROJECT_ID}.staging_dataset.raw_data_staging`
        WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    """
    
    # Check final table freshness
    final_query = f"""
        SELECT 
            MAX(created_at) as latest_final,
            COUNT(*) as final_count
        FROM `{PROJECT_ID}.final_dataset.processed_data`
        WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    """
    
    staging_result = list(client.query(staging_query))[0]
    final_result = list(client.query(final_query))[0]
    
    logging.info(f"Staging data - Latest: {staging_result.latest_staging}, Count: {staging_result.staging_count}")
    logging.info(f"Final data - Latest: {final_result.latest_final}, Count: {final_result.final_count}")
    
    # Alert if no data in last 24 hours
    if staging_result.staging_count == 0:
        raise Exception("No new data in staging table in the last 24 hours!")
    
    if final_result.final_count == 0:
        raise Exception("No new data in final table in the last 24 hours!")

def check_error_rates(**context):
    """Check for high error rates in processed data"""
    from google.cloud import bigquery
    
    client = bigquery.Client(project=PROJECT_ID)
    
    query = f"""
        SELECT 
            status,
            COUNT(*) as count,
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
        FROM `{PROJECT_ID}.final_dataset.processed_data`
        WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
        GROUP BY status
    """
    
    results = client.query(query)
    
    error_percentage = 0
    for row in results:
        logging.info(f"Status: {row.status}, Count: {row.count}, Percentage: {row.percentage:.2f}%")
        if row.status == 'error':
            error_percentage = row.percentage
    
    # Alert if error rate > 10%
    if error_percentage > 10:
        raise Exception(f"High error rate detected: {error_percentage:.2f}%")

# Task definitions
freshness_check = PythonOperator(
    task_id='check_data_freshness',
    python_callable=check_data_freshness,
    dag=dag,
)

error_rate_check = PythonOperator(
    task_id='check_error_rates',
    python_callable=check_error_rates,
    dag=dag,
)

# BigQuery data quality checks
staging_quality_check = BigQueryCheckOperator(
    task_id='staging_data_quality_check',
    sql=f"""
        SELECT COUNT(*) 
        FROM `{PROJECT_ID}.staging_dataset.raw_data_staging`
        WHERE data IS NULL OR timestamp IS NULL
    """,
    use_legacy_sql=False,
    dag=dag,
)

final_quality_check = BigQueryCheckOperator(
    task_id='final_data_quality_check',
    sql=f"""
        SELECT COUNT(*) 
        FROM `{PROJECT_ID}.final_dataset.processed_data`
        WHERE processed_data IS NULL OR created_at IS NULL
    """,
    use_legacy_sql=False,
    dag=dag,
)

# Task dependencies
freshness_check >> error_rate_check
staging_quality_check >> final_quality_check
EOF

# Upload monitoring DAG
gsutil cp ../composer/dags/additional/pipeline_monitoring_dag.py $DAGS_BUCKET/

# Create requirements.txt for additional Python packages
echo -e "${YELLOW}Setting up Python packages for Composer...${NC}"

cat > composer_requirements.txt << 'EOF'
google-cloud-storage==2.10.0
google-cloud-bigquery==3.12.0
google-cloud-pubsub==2.18.1
requests==2.31.0
pandas==2.0.3
EOF

# Upload requirements to Composer
COMPOSER_BUCKET_ROOT=$(echo $DAGS_BUCKET | sed 's|/dags||')
gsutil cp composer_requirements.txt ${COMPOSER_BUCKET_ROOT}/requirements.txt

# Create scripts for managing Composer
cat > manage_composer.sh << EOF
#!/bin/bash

ACTION=\${1:-"status"}
PROJECT_ID="$PROJECT_ID"
REGION="$REGION"
COMPOSER_ENV="$COMPOSER_ENV"
DAGS_BUCKET="$DAGS_BUCKET"

case \$ACTION in
    "status")
        echo "Checking Composer environment status:"
        gcloud composer environments describe \$COMPOSER_ENV --location=\$REGION --format="value(state)"
        ;;
    "airflow-ui")
        echo "Getting Airflow UI URL:"
        gcloud composer environments describe \$COMPOSER_ENV --location=\$REGION --format="value(config.airflowUri)"
        ;;
    "upload-dag")
        DAG_FILE=\${2:-"../composer/dags/data_collection_dag.py"}
        if [ -f "\$DAG_FILE" ]; then
            echo "Uploading DAG file: \$DAG_FILE"
            gsutil cp \$DAG_FILE \$DAGS_BUCKET/
        else
            echo "Error: DAG file not found: \$DAG_FILE"
        fi
        ;;
    "list-dags")
        echo "Listing DAGs in bucket:"
        gsutil ls \$DAGS_BUCKET/
        ;;
    "logs")
        echo "Getting recent Composer logs:"
        gcloud logging read "resource.type=gce_instance AND resource.labels.instance_name:\$COMPOSER_ENV" --limit=50 --format="table(timestamp,severity,textPayload)"
        ;;
    "delete")
        echo "Deleting Composer environment: \$COMPOSER_ENV"
        echo "Warning: This will delete the entire environment!"
        read -p "Are you sure? (y/N): " confirm
        if [ "\$confirm" = "y" ] || [ "\$confirm" = "Y" ]; then
            gcloud composer environments delete \$COMPOSER_ENV --location=\$REGION --quiet
        fi
        ;;
    *)
        echo "Usage: \$0 {status|airflow-ui|upload-dag|list-dags|logs|delete}"
        echo "  status      - Show environment status"
        echo "  airflow-ui  - Get Airflow UI URL"
        echo "  upload-dag  - Upload a DAG file (specify file as second argument)"
        echo "  list-dags   - List DAGs in bucket"
        echo "  logs        - Show recent logs"
        echo "  delete      - Delete the environment"
        exit 1
        ;;
esac
EOF

chmod +x manage_composer.sh

# Clean up temp files
rm composer_requirements.txt

echo -e "${GREEN}Cloud Composer setup completed successfully!${NC}"
echo "Environment: $COMPOSER_ENV"
echo "Region: $REGION"
echo "DAGs bucket: $DAGS_BUCKET"
echo ""

# Get Airflow UI URL
AIRFLOW_UI=$(gcloud composer environments describe $COMPOSER_ENV --location=$REGION --format="value(config.airflowUri)" 2>/dev/null || echo "Not available yet")
echo "Airflow UI: $AIRFLOW_UI"
echo ""

echo "Management script created:"
echo "  - manage_composer.sh (manage environment and DAGs)"
echo ""
echo "DAGs uploaded:"
echo "  - data_collection_dag.py (main data collection)"
echo "  - pipeline_monitoring_dag.py (pipeline monitoring)"
echo ""
echo "To manage Composer:"
echo "  ./manage_composer.sh {status|airflow-ui|upload-dag|list-dags|logs|delete}"
echo ""
echo "To upload additional DAGs:"
echo "  ./manage_composer.sh upload-dag path/to/your/dag.py"
