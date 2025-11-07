#!/bin/bash

# Set your project ID
PROJECT_ID="gcp-project-deliverable"
SERVICE_ACCOUNT_NAME="data-pipeline-sa"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Creating service account for data pipeline..."

# Create service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --description="Service account for data pipeline operations" \
    --display-name="Data Pipeline Service Account" \
    --project=$PROJECT_ID

echo "Assigning required roles to service account..."

# Assign necessary roles
ROLES=(
    "roles/storage.admin"
    "roles/pubsub.admin"
    "roles/cloudfunctions.admin"
    "roles/bigquery.admin"
    "roles/dataproc.editor"
    "roles/container.admin"
    "roles/composer.worker"
    "roles/iam.serviceAccountUser"
    "roles/cloudsql.client"
)

for role in "${ROLES[@]}"; do
    echo "Assigning role: $role"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role"
done

echo "Creating and downloading service account key..."
gcloud iam service-accounts keys create ./service-account-key.json \
    --iam-account=$SERVICE_ACCOUNT_EMAIL \
    --project=$PROJECT_ID

echo "Service account setup completed!"
echo "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
echo "Key file saved as: ./service-account-key.json"

# Export environment variable for local development
export GOOGLE_APPLICATION_CREDENTIALS="./service-account-key.json"
echo "Set GOOGLE_APPLICATION_CREDENTIALS environment variable to: ./service-account-key.json"
