# Google Cloud Data Pipeline Setup Scripts

This directory contains shell scripts to set up a complete Google Cloud data pipeline including GCS, Pub/Sub, BigQuery, Cloud Functions, Dataproc, GKE, Composer, and a React dashboard. All scripts use the project ID "gcp-project-deliverable" by default.

## Prerequisites

Before running any scripts, ensure you have:

- [Google Cloud CLI (gcloud)](https://cloud.google.com/sdk/docs/install) installed and authenticated
- [Docker](https://docs.docker.com/get-docker/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [BigQuery CLI (bq)](https://cloud.google.com/bigquery/docs/bq-command-line-tool) installed
- Valid Google Cloud Project with billing enabled
- Project ID: **gcp-project-deliverable** (or customize in scripts)

## 🚀 Quick Start Options

### Option 1: Complete Automated Setup (Recommended)

```bash
cd scripts
chmod +x complete-setup.sh
./complete-setup.sh gcp-project-deliverable
```

This runs all 10 steps automatically and takes approximately 30-45 minutes.

### Option 2: Step-by-Step Setup

Run the numbered scripts in order for full control:

```bash
cd scripts
chmod +x step*.sh

# Step 1: Enable all required APIs (2-3 minutes)
./step1-enable-apis.sh gcp-project-deliverable

# Step 2: Create service account with all permissions (1 minute)
./step2-create-service-account.sh gcp-project-deliverable

# Step 3: Set up Cloud Composer environment (15-25 minutes)
./step3-setup-composer.sh gcp-project-deliverable

# Step 4: Create GCS buckets (2-3 minutes)
./step4-setup-gcs.sh gcp-project-deliverable

# Step 5: Set up Pub/Sub topics and subscriptions (2-3 minutes)
./step5-setup-pubsub.sh gcp-project-deliverable

# Step 6: Create BigQuery datasets and tables (3-5 minutes)
./step6-setup-bigquery.sh gcp-project-deliverable

# Step 7: Deploy Cloud Functions (5-7 minutes)
./step7-setup-cloud-functions.sh gcp-project-deliverable

# Step 8: Create Dataproc cluster (3-5 minutes)
./step8-setup-dataproc.sh gcp-project-deliverable

# Step 9: Set up GKE cluster (5-7 minutes)
./step9-setup-gke.sh gcp-project-deliverable

# Step 10: Deploy React dashboard (2-3 minutes)
./step10-setup-react-dashboard.sh gcp-project-deliverable
```

### Option 3: Individual Service Setup

Use the individual service scripts for specific components:

1. **Enable APIs**
   ```bash
   ./step1-enable-apis.sh gcp-project-deliverable
   ```

2. **Service Account Setup**
   ```bash
   ./step2-create-service-account.sh gcp-project-deliverable
   ```

3. **Cloud Composer**
   ```bash
   ./step3-setup-composer.sh gcp-project-deliverable
   ```

4. **Google Cloud Storage**
   ```bash
   ./step4-setup-gcs.sh gcp-project-deliverable
   ```

5. **Pub/Sub**
   ```bash
   ./step5-setup-pubsub.sh gcp-project-deliverable
   ```

6. **BigQuery**
   ```bash
   ./step6-setup-bigquery.sh gcp-project-deliverable
   ```

7. **Cloud Functions**
   ```bash
   ./step7-setup-cloud-functions.sh gcp-project-deliverable
   ```

8. **Dataproc**
   ```bash
   ./step8-setup-dataproc.sh gcp-project-deliverable
   ```

9. **Google Kubernetes Engine (GKE)**
   ```bash
   ./step9-setup-gke.sh gcp-project-deliverable
   ```

10. **React Dashboard**
    ```bash
    ./step10-setup-react-dashboard.sh gcp-project-deliverable
    ```

## 📋 Script Descriptions

### Step-by-Step Scripts

| Script | Purpose | Time to Complete | Dependencies |
|--------|---------|------------------|--------------|
| `step1-enable-apis.sh` | Enable all required Google Cloud APIs | 2-3 minutes | None |
| `step2-create-service-account.sh` | Create service account with all permissions | 1 minute | Step 1 |
| `step3-setup-composer.sh` | Create Cloud Composer environment | 15-25 minutes | Steps 1-2 |
| `step4-setup-gcs.sh` | Create GCS buckets with proper configuration | 2-3 minutes | Steps 1-2 |
| `step5-setup-pubsub.sh` | Create Pub/Sub topics and subscriptions | 2-3 minutes | Steps 1-2 |
| `step6-setup-bigquery.sh` | Create BigQuery datasets, tables, and views | 3-5 minutes | Steps 1-2 |
| `step7-setup-cloud-functions.sh` | Deploy Cloud Functions for data processing | 5-7 minutes | Steps 1-6 |
| `step8-setup-dataproc.sh` | Create Dataproc cluster for Spark jobs | 3-5 minutes | Steps 1-4 |
| `step9-setup-gke.sh` | Create GKE cluster with configurations | 5-7 minutes | Steps 1-2 |
| `step10-setup-react-dashboard.sh` | Deploy React dashboard and backend | 2-3 minutes | Steps 1-9 |

### Legacy Individual Service Scripts

| Script | Purpose | Notes |
|--------|---------|-------|
| `setup-all.sh` | Legacy all-in-one script | Use `complete-setup.sh` instead |
| `quick-setup.sh` | Legacy quick setup | Use `complete-setup.sh` instead |
| `setup-gcs.sh` | Individual GCS setup | Use `step4-setup-gcs.sh` instead |
| `setup-pubsub.sh` | Individual Pub/Sub setup | Use `step5-setup-pubsub.sh` instead |
| `setup-bigquery.sh` | Individual BigQuery setup | Use `step6-setup-bigquery.sh` instead |
| `setup-cloud-functions.sh` | Individual Functions setup | Use `step7-setup-cloud-functions.sh` instead |
| `setup-dataproc.sh` | Individual Dataproc setup | Use `step8-setup-dataproc.sh` instead |
| `setup-gke.sh` | Individual GKE setup | Use `step9-setup-gke.sh` instead |
| `setup-composer.sh` | Individual Composer setup | Use `step3-setup-composer.sh` instead |

## 🛠️ What Gets Created

### Step 1: APIs
- 13 Google Cloud APIs enabled
- Project configuration set

### Step 2: Service Account
- Service account: `data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com`
- Key file: `../service-account/service-account-key.json`
- 13 IAM roles assigned

### Step 3: Cloud Composer
- Environment: `data-pipeline-composer`
- Airflow UI with workflow orchestration
- DAGs uploaded from `../composer/dags/`

### Step 4: Cloud Storage
- 6 buckets created:
  - `gcp-project-deliverable-raw-data` (raw data storage)
  - `gcp-project-deliverable-processed-data` (processed data)
  - `gcp-project-deliverable-temp-data` (temporary storage)
  - `gcp-project-deliverable-cloud-functions` (function source code)
  - `gcp-project-deliverable-dataproc-staging` (Dataproc staging)
  - `gcp-project-deliverable-backup` (backup storage)

### Step 5: Pub/Sub
- 5 topics: `sensor-data`, `processed-data`, `error-notifications`, `batch-job-status`, `data-quality-alerts`
- 6 subscriptions with different ack deadlines
- Dead letter queues for critical topics

### Step 6: BigQuery
- 4 datasets: `raw_data`, `processed_data`, `analytics`, `monitoring`
- 10+ tables for different data types
- 2 views for dashboard queries
- Sample scheduled query templates

### Step 7: Cloud Functions
- 3 functions deployed:
  - `data-processor` (Pub/Sub trigger)
  - `data-validator` (HTTP trigger)
  - `notification-sender` (Pub/Sub trigger)

### Step 8: Dataproc
- Cluster: `data-processing-cluster`
- 2 worker nodes (auto-scaling to 10)
- Sample PySpark jobs uploaded
- Integration with BigQuery and GCS

### Step 9: GKE
- Cluster: `data-pipeline-gke`
- 3 namespaces: `data-pipeline`, `monitoring`, `staging`
- Deployment configurations for applications
- Prometheus monitoring setup

### Step 10: React Dashboard
- Static website hosted on GCS
- Backend API on App Engine (optional)
- Basic monitoring dashboard
- Integration with BigQuery for data visualization

## 📊 Usage Examples

### Check Pipeline Status
```bash
./check_pipeline_status.sh
```

### Manage Dataproc Cluster
### Test the Pipeline

```bash
# Send test data to Pub/Sub
gcloud pubsub topics publish sensor-data --message='{"sensor_id": "test-001", "temperature": 23.5, "humidity": 65.0}'

# Check Cloud Functions logs
gcloud functions logs read data-processor --project=gcp-project-deliverable

# Query BigQuery data
bq query --use_legacy_sql=false 'SELECT * FROM `gcp-project-deliverable.raw_data.sensor_data` LIMIT 10'

# Submit Dataproc job
gcloud dataproc jobs submit pyspark gs://gcp-project-deliverable-dataproc-staging/dataproc/jobs/process_sensor_data.py \
  --cluster=data-processing-cluster --region=us-central1

# Check GKE pods
kubectl get pods --all-namespaces

# View dashboard
open https://storage.googleapis.com/gcp-project-deliverable-dashboard/index.html
```

### Monitor the Pipeline

```bash
# Check service status
gcloud composer environments list --locations=us-central1
gcloud dataproc clusters list --region=us-central1
gcloud container clusters list
gcloud functions list

# View logs
gcloud functions logs read FUNCTION_NAME
gcloud dataproc jobs list --region=us-central1
kubectl logs -f deployment/DEPLOYMENT_NAME -n data-pipeline

# Monitor metrics
gcloud logging read 'resource.type="cloud_function"' --limit=10
gcloud logging read 'resource.type="dataproc_cluster"' --limit=10
```

## 🛡️ Security Features

### Service Account Permissions
- Minimal required permissions for each service
- Service account key stored securely
- IAM roles properly scoped

### Network Security
- VPC native clusters for GKE
- Private IP addresses where possible
- Firewall rules configured
- Network policies in Kubernetes

### Data Security
- Uniform bucket-level access for GCS
- BigQuery dataset permissions
- Pub/Sub topic access controls
- SSL/TLS encryption in transit

## 💰 Cost Optimization

### Auto-scaling
- GKE cluster: 1-10 nodes
- Dataproc cluster: 2-10 workers
- Cloud Functions: automatic scaling

### Resource Management
- Lifecycle policies for temp data (7 days)
- Efficient machine types
- Regional resources to reduce data transfer costs
- Proper resource limits

### Cost Monitoring
- Budget alerts can be set up in Google Cloud Console
- Resource labels for cost tracking
- Scheduled scaling based on usage patterns

## 🚨 Troubleshooting

### Common Issues

1. **API Not Enabled Error**
   ```bash
   # Run step 1 again
   ./step1-enable-apis.sh gcp-project-deliverable
   ```

2. **Insufficient Permissions**
   ```bash
   # Check current user permissions
   gcloud auth list
   gcloud projects get-iam-policy gcp-project-deliverable
   ```

3. **Quota Exceeded**
   ```bash
   # Check quotas in Console
   # Request quota increases if needed
   gcloud compute project-info describe --project=gcp-project-deliverable
   ```

4. **Composer Environment Creation Timeout**
   ```bash
   # Composer can take 20-30 minutes, check status:
   gcloud composer environments describe data-pipeline-composer --location=us-central1
   ```

5. **Cloud Function Deployment Failed**
   ```bash
   # Check source bucket exists
   gsutil ls gs://gcp-project-deliverable-cloud-functions
   
   # Redeploy specific function
   ./step7-setup-cloud-functions.sh gcp-project-deliverable
   ```

### Getting Help

- Check Google Cloud Console for detailed error messages
- Review Cloud Logging for service-specific issues
- Use `gcloud` commands with `--verbosity=debug` for detailed output
- Check the [Google Cloud Status page](https://status.cloud.google.com/) for service issues

## 🔄 Cleanup

To delete all resources created by these scripts:

```bash
# Delete GKE cluster
gcloud container clusters delete data-pipeline-gke --zone=us-central1-a --quiet

# Delete Dataproc cluster
gcloud dataproc clusters delete data-processing-cluster --region=us-central1 --quiet

# Delete Composer environment (takes 10-15 minutes)
gcloud composer environments delete data-pipeline-composer --location=us-central1 --quiet

# Delete Cloud Functions
gcloud functions delete data-processor --region=us-central1 --quiet
gcloud functions delete data-validator --region=us-central1 --quiet
gcloud functions delete notification-sender --region=us-central1 --quiet

# Delete BigQuery datasets
bq rm -r -f gcp-project-deliverable:raw_data
bq rm -r -f gcp-project-deliverable:processed_data
bq rm -r -f gcp-project-deliverable:analytics
bq rm -r -f gcp-project-deliverable:monitoring

# Delete Pub/Sub topics and subscriptions
gcloud pubsub topics delete sensor-data processed-data error-notifications batch-job-status data-quality-alerts
gcloud pubsub topics delete sensor-data-dlq processed-data-dlq

# Delete GCS buckets
gsutil rm -r gs://gcp-project-deliverable-raw-data
gsutil rm -r gs://gcp-project-deliverable-processed-data
gsutil rm -r gs://gcp-project-deliverable-temp-data
gsutil rm -r gs://gcp-project-deliverable-cloud-functions
gsutil rm -r gs://gcp-project-deliverable-dataproc-staging
gsutil rm -r gs://gcp-project-deliverable-backup
gsutil rm -r gs://gcp-project-deliverable-dashboard

# Delete service account
gcloud iam service-accounts delete data-pipeline-sa@gcp-project-deliverable.iam.gserviceaccount.com --quiet
```

## 📚 Additional Resources

- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Cloud Composer Documentation](https://cloud.google.com/composer/docs)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Cloud Functions Documentation](https://cloud.google.com/functions/docs)
- [Dataproc Documentation](https://cloud.google.com/dataproc/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Pub/Sub Documentation](https://cloud.google.com/pubsub/docs)

---

**Note**: These scripts are designed for the project ID "gcp-project-deliverable". To use a different project ID, update the scripts or pass the project ID as a parameter to each script.

## Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   # Ensure you're authenticated and have necessary roles
   gcloud auth login
   gcloud auth application-default login
   ```

2. **API Not Enabled**
   ```bash
   # Each script enables required APIs, but you can manually enable:
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   # ... etc
   ```

3. **Quota Limits**
   ```bash
   # Check quotas in Google Cloud Console
   gcloud compute project-info describe --project=YOUR_PROJECT_ID
   ```

4. **Resource Already Exists**
   - Scripts are designed to handle existing resources
   - Check script output for warnings about existing resources

### Logs and Monitoring

- Check script output for detailed logs
- Use Google Cloud Console for service-specific logs
- Run `check_pipeline_status.sh` for overall health check

## Cleanup

To remove all resources created by these scripts:

```bash
./cleanup_pipeline.sh
```

**Warning**: This will delete ALL pipeline resources and cannot be undone.

## Support

For issues with individual scripts:
1. Check the script output for error messages
2. Verify prerequisites are installed
3. Ensure you have sufficient permissions
4. Check Google Cloud Console for service-specific errors

## Contributing

When modifying scripts:
1. Maintain error handling with `set -e`
2. Use color-coded output for consistency
3. Add appropriate comments
4. Test with both new and existing resources
5. Update this README with any changes
