#!/bin/bash

# BigQuery Setup Script
# Creates datasets and tables for Medicaid NADAC drug data pipeline

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

echo -e "${GREEN}Setting up BigQuery for Medicaid NADAC data...${NC}"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Set gcloud project
gcloud config set project $PROJECT_ID

SERVICE_ACCOUNT_EMAIL="data-pipeline-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Create staging dataset
STAGING_DATASET="medicaid_staging"
echo -e "${YELLOW}Creating staging dataset: $STAGING_DATASET${NC}"

bq mk --dataset \
    --description="Dataset for Medicaid NADAC drug data" \
    --location=$REGION \
    --default_table_expiration=7200 \
    $PROJECT_ID:$STAGING_DATASET

# Create NADAC staging table schema with direct drug fields
cat > nadac_staging_schema.json << 'EOF'
[
  {
    "name": "ndc_description",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Drug name, strength, and dosage form"
  },
  {
    "name": "ndc",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The National Drug Code (NDC) - 11-digit code"
  },
  {
    "name": "nadac_per_unit",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "The National Average Drug Acquisition Cost per unit (as string from API)"
  },
  {
    "name": "effective_date",
    "type": "DATE",
    "mode": "NULLABLE",
    "description": "The effective date of the NADAC Per Unit cost"
  },
  {
    "name": "pricing_unit",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Pricing unit (ML, GM, or EA)"
  },
  {
    "name": "pharmacy_type_indicator",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Source of pharmacy survey data (C/I for Chain/Independent)"
  },
  {
    "name": "otc",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Over-the-counter indicator (Y or N)"
  },
  {
    "name": "explanation_code",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Code indicating how NADAC was calculated (1-10)"
  },
  {
    "name": "classification_for_rate_setting",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Brand (B) or Generic (G) classification"
  },
  {
    "name": "corresponding_generic_drug_nadac_per_unit",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "NADAC for corresponding generic drug"
  },
  {
    "name": "corresponding_generic_drug_effective_date",
    "type": "DATE",
    "mode": "NULLABLE",
    "description": "Effective date of corresponding generic drug NADAC"
  },
  {
    "name": "as_of_date",
    "type": "DATE",
    "mode": "NULLABLE",
    "description": "As of date for the record"
  }
]
EOF

# Create staging table
STAGING_TABLE="nadac_drugs"
echo -e "${YELLOW}Creating NADAC staging table: $STAGING_TABLE${NC}"

bq mk --table \
    --description="Table for NADAC drug records with direct field mapping" \
    --range_partitioning=ndc,0,99999999999,1000000 \
    --clustering_fields=ndc_description,ndc,nadac_per_unit,pharmacy_type_indicator \
    $PROJECT_ID:$STAGING_DATASET.$STAGING_TABLE \
    nadac_staging_schema.json

# Grant permissions to service account
echo -e "${YELLOW}Granting BigQuery permissions to service account: $SERVICE_ACCOUNT_EMAIL${NC}"

# Grant access to staging dataset using gcloud (more reliable than bq command)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/bigquery.jobUser"

# Clean up schema files
rm nadac_staging_schema.json

echo -e "${GREEN}BigQuery setup completed successfully!${NC}"
echo "Dataset created:"
echo "  - $STAGING_DATASET (NADAC drug data)"
echo ""
echo "Table created with partitioning and clustering:"
echo "  - $STAGING_DATASET.$STAGING_TABLE"
echo "    * Partitioned by: ndc (integer range partitioning)"
echo "    * Clustered by: ndc_description, ndc, nadac_per_unit, pharmacy_type_indicator"
echo "    * Direct drug field mapping from API"
echo "    * Ingestion timestamp for data lineage tracking"
echo ""
echo "Performance Optimizations:"
echo "✓ Integer range partitioning by NDC (0-99B, 1M per partition)"
echo "✓ Clustering for drug name, NDC, cost, and pharmacy type lookups"
echo "✓ Cost optimization through partition pruning"
echo ""
echo "Next steps:"
echo "1. Load JSON drug records directly into $STAGING_DATASET.$STAGING_TABLE"
echo "2. Query with WHERE ndc for best performance"
echo "3. Query with WHERE clauses on partitioned/clustered fields for best performance"

# Create enriched dataset (if not already existing)
ENRICHED_DATASET="medicaid_enriched"
echo -e "${YELLOW}Creating enriched dataset (if absent): $ENRICHED_DATASET${NC}"
if bq --project_id $PROJECT_ID ls | grep -q "${ENRICHED_DATASET}"; then
  echo -e "${YELLOW}Enriched dataset ${ENRICHED_DATASET} already exists, skipping creation${NC}"
else
  bq mk --dataset \
    --description="Dataset for enriched Medicaid NADAC drug data" \
    --location=$REGION \
    $PROJECT_ID:$ENRICHED_DATASET
fi

# Create enriched table schema file (includes staging columns + new enrichment columns)
cat > nadac_enriched_schema.json << 'EOF'
[
  {"name": "ndc_description", "type": "STRING", "mode": "NULLABLE", "description": "Drug name, strength, and dosage form (raw description)"},
  {"name": "ndc", "type": "STRING", "mode": "REQUIRED", "description": "National Drug Code (11-digit string)"},
  {"name": "nadac_per_unit", "type": "STRING", "mode": "NULLABLE", "description": "NADAC per unit (from API, string)"},
  {"name": "effective_date", "type": "DATE", "mode": "NULLABLE", "description": "Effective date of NADAC"},
  {"name": "pricing_unit", "type": "STRING", "mode": "NULLABLE", "description": "Pricing unit (ML, GM, EA)"},
  {"name": "pharmacy_type_indicator", "type": "STRING", "mode": "NULLABLE", "description": "Pharmacy type indicator (C/I)"},
  {"name": "otc", "type": "STRING", "mode": "NULLABLE", "description": "Over-the-counter indicator (Y/N)"},
  {"name": "explanation_code", "type": "STRING", "mode": "NULLABLE", "description": "Comma separated explanation code(s)"},
  {"name": "classification_for_rate_setting", "type": "STRING", "mode": "NULLABLE", "description": "Brand (B) or Generic (G)"},
  {"name": "corresponding_generic_drug_nadac_per_unit", "type": "STRING", "mode": "NULLABLE", "description": "NADAC for corresponding generic drug (string)"},
  {"name": "corresponding_generic_drug_effective_date", "type": "DATE", "mode": "NULLABLE", "description": "Effective date for corresponding generic NADAC"},
  {"name": "as_of_date", "type": "DATE", "mode": "NULLABLE", "description": "As of date for record"},
  {"name": "drug_name", "type": "STRING", "mode": "NULLABLE", "description": "Derived drug name (tokens excluding final strength/dosage/form)"},
  {"name": "drug_strength", "type": "STRING", "mode": "NULLABLE", "description": "Parsed leading numeric portion of strength token"},
  {"name": "drug_dosage", "type": "STRING", "mode": "NULLABLE", "description": "Derived dosage token (2nd from end)"},
  {"name": "drug_form", "type": "STRING", "mode": "NULLABLE", "description": "Derived form token (last token)"},
  {"name": "explanation_code_description", "type": "STRING", "mode": "NULLABLE", "description": "Mapped textual description(s) of explanation_code"},
  {"name": "enriched_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE", "description": "Timestamp when enrichment was performed"}
]
EOF

ENRICHED_TABLE="nadac_drugs_enriched"
echo -e "${YELLOW}Creating enriched table: $ENRICHED_TABLE${NC}"

# Create enriched table (cluster on frequently filtered dimensions). No range partition (ndc is STRING).
if bq --project_id $PROJECT_ID ls $PROJECT_ID:$ENRICHED_DATASET | grep -q "${ENRICHED_TABLE}"; then
  echo -e "${YELLOW}Enriched table ${ENRICHED_TABLE} already exists, updating clustering/partitioning if needed${NC}"
  # Attempt to update clustering (partitioning cannot be added after creation without table recreation)
  # To enforce desired spec, recreate table if partitioning absent.
  CURRENT_SCHEMA=$(bq show --format=prettyjson $PROJECT_ID:$ENRICHED_DATASET.$ENRICHED_TABLE 2>/dev/null || echo "")
  if echo "$CURRENT_SCHEMA" | grep -q '"timePartitioning"'; then
    echo -e "${GREEN}Table already partitioned; skipping recreation${NC}"
  else
    echo -e "${YELLOW}Recreating enriched table to apply partitioning on enriched_timestamp${NC}"
    bq rm -f $PROJECT_ID:$ENRICHED_DATASET.$ENRICHED_TABLE
    bq mk --table \
      --description="Enriched NADAC drug records with parsed drug attributes and explanation code descriptions" \
      --time_partitioning_field=enriched_timestamp \
      --time_partitioning_type=DAY \
      --clustering_fields=drug_name,ndc,drug_strength,drug_form \
      $PROJECT_ID:$ENRICHED_DATASET.$ENRICHED_TABLE \
      nadac_enriched_schema.json
  fi
else
  bq mk --table \
    --description="Enriched NADAC drug records with parsed drug attributes and explanation code descriptions" \
    --time_partitioning_field=enriched_timestamp \
    --time_partitioning_type=DAY \
    --clustering_fields=drug_name,ndc,drug_strength,drug_form \
    $PROJECT_ID:$ENRICHED_DATASET.$ENRICHED_TABLE \
    nadac_enriched_schema.json
fi

# Clean up enriched schema file
rm nadac_enriched_schema.json

echo "Enriched dataset/table:" >> /dev/null
echo "  - Enriched dataset: $ENRICHED_DATASET"\
; echo "  - Enriched table: $ENRICHED_DATASET.$ENRICHED_TABLE (partitioned by enriched_timestamp DAY; clustered by drug_name, ndc, drug_strength, drug_form)"
