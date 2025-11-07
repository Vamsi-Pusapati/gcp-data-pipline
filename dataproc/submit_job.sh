#!/bin/bash

# Dataproc job submission script
# This script submits the PySpark job to the Dataproc cluster

set -e

# Configuration
PROJECT_ID=${1:-"your-gcp-project-id"}
REGION=${2:-"us-central1"}
CLUSTER_NAME=${3:-"data-processing-cluster"}
JOB_NAME="data-processing-job-$(date +%Y%m%d-%H%M%S)"

# Validate inputs
if [ "$PROJECT_ID" = "your-gcp-project-id" ]; then
    echo "Error: Please provide a valid PROJECT_ID"
    echo "Usage: $0 <PROJECT_ID> [REGION] [CLUSTER_NAME]"
    exit 1
fi

echo "Submitting Dataproc job..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Job Name: $JOB_NAME"

# Submit the PySpark job
gcloud dataproc jobs submit pyspark \
    data_processing_job.py \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --jars=gs://spark-lib/bigquery/spark-bigquery-latest_2.12.jar \
    -- \
    --project-id=$PROJECT_ID \
    --staging-dataset=staging_dataset \
    --staging-table=raw_data_staging \
    --final-dataset=final_dataset \
    --final-table=processed_data

echo "Job submitted successfully: $JOB_NAME"
echo "Monitor the job at: https://console.cloud.google.com/dataproc/jobs"
