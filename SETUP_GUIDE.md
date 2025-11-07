# Data Pipeline Setup Guide

This guide will help you set up and deploy the complete data pipeline on Google Cloud Platform.

## Prerequisites

Before starting, ensure you have:

1. **Google Cloud Platform Account** with billing enabled
2. **gcloud CLI** installed and configured
3. **Docker** installed
4. **kubectl** installed
5. **Node.js** installed (v16+)

## Step-by-Step Setup

### 1. Initial Project Setup

```bash
# Clone the repository and navigate to the project
cd GCS_Project

# Copy environment template
cp .env.template .env

# Edit .env with your project details
# Replace 'your-gcp-project-id' with your actual GCP project ID
```

### 2. Create Google Cloud Project (if needed)

```bash
# Create new project
gcloud projects create YOUR_PROJECT_ID

# Set billing account (replace with your billing account ID)
gcloud billing projects link YOUR_PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID

# Set as default project
gcloud config set project YOUR_PROJECT_ID
```

### 3. Enable Required APIs

```bash
gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    bigquery.googleapis.com \
    storage.googleapis.com \
    pubsub.googleapis.com \
    cloudfunctions.googleapis.com \
    dataproc.googleapis.com \
    composer.googleapis.com \
    iam.googleapis.com
```

### 4. Setup Service Account

```bash
cd service-account
chmod +x setup-service-account.sh
./setup-service-account.sh YOUR_PROJECT_ID
cd ..
```

### 5. Deploy Infrastructure

Choose one of the following options:

**Option 1: Automated Setup (Recommended)**
```bash
cd scripts
chmod +x setup-all.sh
./setup-all.sh YOUR_PROJECT_ID us-central1 us-central1-a
```

**Option 2: Manual Setup (Individual Services)**
```bash
cd scripts

# Run in this order:
./setup-service-account.sh YOUR_PROJECT_ID
./setup-gcs.sh YOUR_PROJECT_ID us-central1
./setup-pubsub.sh YOUR_PROJECT_ID
./setup-bigquery.sh YOUR_PROJECT_ID us-central1
./setup-cloud-functions.sh YOUR_PROJECT_ID us-central1
./setup-dataproc.sh YOUR_PROJECT_ID us-central1 us-central1-a
./setup-gke.sh YOUR_PROJECT_ID us-central1 us-central1-a
./setup-composer.sh YOUR_PROJECT_ID us-central1  # Optional - takes 20-30 minutes
```

### 6. Deploy Cloud Functions

```bash
cd cloud-functions/gcs-to-bq

gcloud functions deploy gcs-to-bq-processor \
    --runtime python39 \
    --trigger-resource YOUR_PROJECT_ID-raw-data \
    --trigger-event google.storage.object.finalize \
    --set-env-vars GCP_PROJECT_ID=YOUR_PROJECT_ID,BQ_STAGING_DATASET=staging_dataset,BQ_STAGING_TABLE=raw_data_staging

cd ../..
```

### 7. Setup Composer Environment

```bash
# Create Composer environment (takes 20-30 minutes)
gcloud composer environments create data-pipeline-composer \
    --location us-central1 \
    --python-version 3

# Get bucket name for DAG uploads
export COMPOSER_BUCKET=$(gcloud composer environments describe data-pipeline-composer \
    --location us-central1 \
    --format="get(config.dagGcsPrefix)")

# Upload DAG file
gsutil cp composer/dags/data_collection_dag.py $COMPOSER_BUCKET/
```

### 8. Build and Deploy Dashboard

```bash
cd react-dashboard

# Build FastAPI backend Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/dashboard-backend:v1.0.0 ./backend/

# Build frontend Docker image  
docker build -t gcr.io/YOUR_PROJECT_ID/react-dashboard:v1.0.0 .

# Push to Container Registry
docker push gcr.io/YOUR_PROJECT_ID/dashboard-backend:v1.0.0
docker push gcr.io/YOUR_PROJECT_ID/react-dashboard:v1.0.0

cd ..
```

### Local Development

For local development of the FastAPI backend:

```bash
cd react-dashboard/backend

# On Linux/Mac
chmod +x run_dev.sh
./run_dev.sh

# On Windows
run_dev.bat
```

The FastAPI server will start on http://localhost:8080 with automatic API documentation at http://localhost:8080/docs

### 9. Deploy to GKE

```bash
# Get cluster credentials
gcloud container clusters get-credentials dashboard-cluster \
    --zone us-central1-a \
    --project YOUR_PROJECT_ID

# Update deployment manifest
sed -i "s/PROJECT_ID/YOUR_PROJECT_ID/g" gke/dashboard-deployment.yaml
sed -i "s/SERVICE_ACCOUNT_EMAIL/data-pipeline-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com/g" gke/dashboard-deployment.yaml

# Deploy to Kubernetes
kubectl apply -f gke/dashboard-deployment.yaml

# Get external IP
kubectl get service dashboard-service -n dashboard
```

### 10. Submit Dataproc Job (when needed)

The Dataproc setup script creates management tools for you:

```bash
# Submit a data processing job
./scripts/submit_dataproc_job.sh

# Manage the cluster
./scripts/manage_dataproc_cluster.sh status
./scripts/manage_dataproc_cluster.sh stop    # To save costs
./scripts/manage_dataproc_cluster.sh start   # To restart
```

## Testing the Pipeline

### 1. Trigger Data Collection
The Composer DAG will automatically collect data every hour. To trigger manually:
- Go to Composer UI in GCP Console
- Find the `data_collection_pipeline` DAG
- Click "Trigger DAG"

### 2. Verify Data Flow
- **GCS**: Check raw data bucket for JSON files
- **BigQuery**: Query staging table for raw data
- **BigQuery**: Query final table for processed data
- **Dashboard**: Access external IP from GKE service

### 3. Monitor Pipeline
- **Composer**: DAG execution logs
- **Cloud Functions**: Function logs
- **Dataproc**: Job logs
- **GKE**: Pod logs

## Useful Commands

```bash
# Check Composer DAGs
gcloud composer dags list --location us-central1

# Check Cloud Function logs
gcloud functions logs read gcs-to-bq-processor

# Check Dataproc jobs
gcloud dataproc jobs list --region us-central1

# Check GKE pods
kubectl get pods -n dashboard

# Query BigQuery data
bq query --use_legacy_sql=false 'SELECT COUNT(*) FROM `YOUR_PROJECT_ID.final_dataset.processed_data`'
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure service account has all required roles
2. **API Not Enabled**: Check all required APIs are enabled
3. **Quota Limits**: Check GCP quotas for your region
4. **Composer Timeout**: Environment creation can take 30+ minutes

### Logs and Monitoring

- **Composer**: Airflow UI for DAG logs
- **Cloud Functions**: Cloud Console Logs
- **Dataproc**: Job details in Console
- **GKE**: `kubectl logs` command
- **BigQuery**: Job history in Console

## Management and Monitoring

After setup, you'll have several management scripts:

### Pipeline Management
```bash
# Check status of all services
./scripts/check_pipeline_status.sh

# Clean up all resources
./scripts/cleanup_pipeline.sh
```

### Service-Specific Management
```bash
# Manage Dataproc cluster
./scripts/manage_dataproc_cluster.sh {start|stop|status|delete|list-jobs}

# Manage GKE cluster
./scripts/manage_gke_cluster.sh {start|stop|status|logs|update}

# Manage Composer environment
./scripts/manage_composer.sh {status|airflow-ui|upload-dag|list-dags|logs|delete}

# Submit Dataproc jobs
./scripts/submit_dataproc_job.sh

# Update GKE deployments
./scripts/update_gke_deployment.sh v1.1.0
```

## Cost Optimization

1. **Preemptible Instances**: Used in Dataproc and GKE
2. **Autoscaling**: Enabled for GKE cluster
3. **Data Lifecycle**: GCS bucket lifecycle rules
4. **Scheduled Jobs**: Only run when needed

## Security Best Practices

1. **Service Account**: Least privilege principle
2. **Network Security**: VPC and firewall rules
3. **Secrets Management**: Use Secret Manager for sensitive data
4. **Workload Identity**: Enabled for GKE pods

## Next Steps

1. **Custom APIs**: Replace example API with your data source
2. **Data Validation**: Add data quality checks
3. **Alerting**: Set up monitoring and alerts
4. **CI/CD**: Implement automated deployment
5. **Backup**: Set up data backup strategies
