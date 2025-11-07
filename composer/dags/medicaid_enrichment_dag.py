"""Airflow DAG to run Medicaid NADAC enrichment Spark job on an existing Dataproc cluster.

This DAG triggers an on-demand NADAC enrichment job using a pre-existing Dataproc cluster.
It verifies the existence of the required PySpark script in the Google Cloud Storage (GCS) bucket
before submitting the job to the Dataproc cluster.
"""

import logging
from datetime import datetime, timedelta
from airflow import models
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.dataproc import DataprocSubmitJobOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor

# Configuration (edit to match your environment)
PROJECT_ID = "gcp-project-deliverable"  # GCP project
REGION = "us-central1"                 # Dataproc region
DATAPROC_CLUSTER = "medicaid-etl-cluster"  # Existing Dataproc cluster name
JOBS_BUCKET = f"{PROJECT_ID}-dataproc-jobs"  # Dedicated jobs bucket
PYSPARK_JOB_URI = f"gs://{JOBS_BUCKET}/jobs/data_processing_job.py"  # Updated GCS path to PySpark script

STAGING_DATASET = "medicaid_staging"
STAGING_TABLE = "nadac_drugs"
ENRICHED_DATASET = "medicaid_enriched"
ENRICHED_TABLE = "nadac_drugs_enriched"
DAG_ID = "medicaid_nadac_enrichment_on_demand"

# Service account to run Dataproc cluster jobs
SERVICE_ACCOUNT = "data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com"
# NOTE: For DataprocSubmitJobOperator against an existing cluster, the job runs under the cluster's service account.
# Ensure the cluster was created with --service-account=${SERVICE_ACCOUNT}. This DAG cannot override it per-job.
# If you need per-job service account override, switch to DataprocBatchOperator (serverless) with environmentConfig.executionConfig.serviceAccount.

# Default DAG arguments
default_args = {
    "owner": "data-eng",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 0,
    "retry_delay": timedelta(minutes=5),
    "start_date": datetime(2025, 11, 6),
}

# Initialize logging
logger = logging.getLogger(__name__)
logger.info("Starting to parse medicaid_enrichment_dag.py")

# Define tasks
def _start():
    """Dummy start task."""
    logger.info("DAG started")
    return "start"

def _end():
    """Dummy end task."""
    logger.info("DAG ended")
    return "end"

# Dataproc job definition per provider docs
DATAPROC_JOB = {
    "reference": {"project_id": PROJECT_ID},
    "placement": {"cluster_name": DATAPROC_CLUSTER},
    "pyspark_job": {
        "main_python_file_uri": PYSPARK_JOB_URI,
        # removed args to rely on script default parameters
        "properties": {
            "spark.sql.shuffle.partitions": "200",
            "spark.executor.memory": "4g",
            "spark.driver.memory": "2g",
        },
        # jar_file_uris removed per request
    },
    "labels": {"pipeline": "medicaid_nadac"},
}

# Define DAG
with models.DAG(
    dag_id=DAG_ID,
    default_args=default_args,
    description="On-demand NADAC enrichment job (Dataproc cluster)",
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    tags=["medicaid", "nadac", "enrichment"],
) as dag:
    logger.info("DAG object created successfully")

    start = PythonOperator(
        task_id="start",
        python_callable=_start,
    )

    # Verify PySpark script exists in jobs bucket before submitting
    wait_for_script = GCSObjectExistenceSensor(
        task_id="wait_for_pyspark_script",
        bucket=JOBS_BUCKET,
        object="jobs/data_processing_job.py",
        poke_interval=30,
        timeout=600,
        mode="poke",
    )
    logger.info("Created wait_for_script sensor")

    run_enrichment = DataprocSubmitJobOperator(
        task_id="run_nadac_enrichment",
        project_id=PROJECT_ID,
        region=REGION,
        job=DATAPROC_JOB,
    )
    logger.info("Created run_enrichment operator")

    end = PythonOperator(
        task_id="end",
        python_callable=_end,
    )

    start >> wait_for_script >> run_enrichment >> end
    logger.info("Task dependencies set successfully")

logger.info("DAG parsing completed successfully")
