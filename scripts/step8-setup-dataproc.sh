#!/bin/bash

# Step 8: Setup Dataproc Cluster
# This script creates a Dataproc cluster for big data processing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID=${1:-"gcp-project-deliverable"}
CLUSTER_NAME="data-processing-cluster"
REGION="us-central1"
ZONE="us-central1-a"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 8: Setup Dataproc Cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo "Staging Bucket: gs://$STAGING_BUCKET"
echo ""

# Set the project
echo -e "${YELLOW}Setting gcloud project...${NC}"
gcloud config set project $PROJECT_ID

# Check if staging bucket exists
echo -e "${YELLOW}Checking if staging bucket exists...${NC}"
if ! gsutil ls -b gs://$STAGING_BUCKET &>/dev/null; then
    echo -e "${RED}Staging bucket gs://$STAGING_BUCKET does not exist.${NC}"
    echo "Please run step4-setup-gcs.sh first to create the bucket."
    exit 1
fi

# Check if cluster already exists
echo -e "${YELLOW}Checking if Dataproc cluster exists...${NC}"
if gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID &>/dev/null; then
    echo -e "${YELLOW}Dataproc cluster already exists.${NC}"
    
    # Get cluster status
    CLUSTER_STATUS=$(gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.state)")
    echo "Cluster status: $CLUSTER_STATUS"
    
    if [ "$CLUSTER_STATUS" = "RUNNING" ]; then
        echo -e "${GREEN}Cluster is running and ready to use.${NC}"
    else
        echo -e "${YELLOW}Cluster exists but is not running. Current status: $CLUSTER_STATUS${NC}"
    fi
else
    echo -e "${YELLOW}Creating Dataproc cluster...${NC}"
    echo "This will take approximately 2-5 minutes."
    echo ""
    
    # Create Dataproc cluster
    if gcloud dataproc clusters create $CLUSTER_NAME \
        --region=$REGION \
        --zone=$ZONE \
        --num-masters=1 \
        --master-machine-type=n1-standard-2 \
        --master-boot-disk-size=50GB \
        --num-workers=2 \
        --worker-machine-type=n1-standard-2 \
        --worker-boot-disk-size=50GB \
        --image-version=2.0-debian10 \
        --enable-autoscaling \
        --max-workers=10 \
        --staging-bucket=$STAGING_BUCKET \
        --initialization-actions=gs://goog-dataproc-initialization-actions-us-central1/python/pip-install.sh \
        --metadata=PIP_PACKAGES="google-cloud-bigquery google-cloud-storage google-cloud-pubsub pandas numpy" \
        --enable-ip-alias \
        --metadata="enable-cloud-sql-hive-metastore=false" \
        --project=$PROJECT_ID; then
        echo -e "${GREEN}✓ Dataproc cluster created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to create Dataproc cluster${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Preparing Dataproc job files...${NC}"

# Create Dataproc jobs directory
DATAPROC_DIR="../dataproc"
mkdir -p $DATAPROC_DIR/jobs
mkdir -p $DATAPROC_DIR/scripts

# Create sample PySpark job for data processing
cat > $DATAPROC_DIR/jobs/process_sensor_data.py << 'EOF'
#!/usr/bin/env python3

"""
PySpark job to process sensor data from GCS and load into BigQuery
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import sys

def main():
    # Initialize Spark session
    spark = SparkSession.builder \
        .appName("ProcessSensorData") \
        .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.28.0") \
        .getOrCreate()
    
    # Configuration
    project_id = "gcp-project-deliverable"
    input_bucket = f"{project_id}-raw-data"
    output_dataset = "processed_data"
    output_table = "processed_sensor_data"
    
    print(f"Processing sensor data from gs://{input_bucket}/sensor-data/")
    
    # Define schema for sensor data
    sensor_schema = StructType([
        StructField("sensor_id", StringType(), True),
        StructField("timestamp", TimestampType(), True),
        StructField("temperature", DoubleType(), True),
        StructField("humidity", DoubleType(), True),
        StructField("pressure", DoubleType(), True),
        StructField("location", StringType(), True)
    ])
    
    # Read data from GCS (assuming JSON format)
    try:
        df = spark.read \
            .option("multiline", "true") \
            .schema(sensor_schema) \
            .json(f"gs://{input_bucket}/sensor-data/*.json")
        
        print(f"Read {df.count()} records from GCS")
        
        # Data processing and cleaning
        processed_df = df \
            .filter(col("temperature").isNotNull()) \
            .filter(col("temperature").between(-50, 100)) \
            .withColumn("quality_score", 
                       when(col("temperature").between(0, 40) & 
                            col("humidity").between(0, 100) & 
                            col("pressure").between(900, 1100), 1.0)
                       .otherwise(0.8)) \
            .withColumn("anomaly_detected", 
                       when(col("temperature") > 35, True)
                       .otherwise(False)) \
            .withColumn("processing_timestamp", current_timestamp()) \
            .withColumnRenamed("temperature", "avg_temperature") \
            .withColumnRenamed("humidity", "avg_humidity") \
            .withColumnRenamed("pressure", "avg_pressure")
        
        print(f"Processed {processed_df.count()} records")
        
        # Write to BigQuery
        processed_df.write \
            .format("bigquery") \
            .option("project", project_id) \
            .option("dataset", output_dataset) \
            .option("table", output_table) \
            .option("writeMethod", "append") \
            .mode("append") \
            .save()
        
        print(f"Data written to BigQuery: {project_id}.{output_dataset}.{output_table}")
        
    except Exception as e:
        print(f"Error processing data: {str(e)}")
        sys.exit(1)
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
EOF

# Create a batch processing script
cat > $DATAPROC_DIR/jobs/batch_aggregation.py << 'EOF'
#!/usr/bin/env python3

"""
PySpark job for batch aggregation of processed data
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime, timedelta

def main():
    # Initialize Spark session
    spark = SparkSession.builder \
        .appName("BatchAggregation") \
        .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.28.0") \
        .getOrCreate()
    
    project_id = "gcp-project-deliverable"
    
    print("Starting batch aggregation job")
    
    # Read processed sensor data from BigQuery
    processed_df = spark.read \
        .format("bigquery") \
        .option("project", project_id) \
        .option("dataset", "processed_data") \
        .option("table", "processed_sensor_data") \
        .load()
    
    # Filter for yesterday's data
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    daily_data = processed_df.filter(date_format(col("timestamp"), "yyyy-MM-dd") == yesterday)
    
    # Create daily aggregations
    daily_agg = daily_data \
        .groupBy("location", date_format(col("timestamp"), "yyyy-MM-dd").alias("date")) \
        .agg(
            avg("avg_temperature").alias("daily_avg_temperature"),
            max("avg_temperature").alias("daily_max_temperature"),
            min("avg_temperature").alias("daily_min_temperature"),
            avg("avg_humidity").alias("daily_avg_humidity"),
            avg("avg_pressure").alias("daily_avg_pressure"),
            sum(when(col("anomaly_detected") == True, 1).otherwise(0)).alias("anomaly_count"),
            count("*").alias("total_readings")
        ) \
        .withColumn("metric_name", lit("daily_sensor_summary")) \
        .withColumn("category", lit("sensors")) \
        .withColumn("subcategory", col("location")) \
        .withColumn("metadata", to_json(struct(
            col("daily_avg_temperature"),
            col("daily_max_temperature"),
            col("daily_min_temperature"),
            col("daily_avg_humidity"),
            col("daily_avg_pressure"),
            col("anomaly_count"),
            col("total_readings")
        ))) \
        .select(
            to_date(col("date")).alias("date"),
            col("metric_name"),
            col("daily_avg_temperature").alias("metric_value"),
            col("category"),
            col("subcategory"),
            col("metadata")
        )
    
    # Write aggregations to BigQuery
    daily_agg.write \
        .format("bigquery") \
        .option("project", project_id) \
        .option("dataset", "processed_data") \
        .option("table", "daily_aggregates") \
        .option("writeMethod", "append") \
        .mode("append") \
        .save()
    
    print(f"Daily aggregation completed for {yesterday}")
    spark.stop()

if __name__ == "__main__":
    main()
EOF

# Upload job files to GCS
echo "Uploading Dataproc job files to staging bucket..."
if gsutil -m cp -r $DATAPROC_DIR/* gs://$STAGING_BUCKET/dataproc/; then
    echo -e "${GREEN}✓ Job files uploaded${NC}"
else
    echo -e "${RED}✗ Failed to upload job files${NC}"
fi

echo ""
echo -e "${YELLOW}Creating sample data for testing...${NC}"

# Create sample sensor data for testing
SAMPLE_DATA='[
  {"sensor_id": "sensor-001", "timestamp": "2024-01-01T12:00:00Z", "temperature": 23.5, "humidity": 65.2, "pressure": 1013.25, "location": "office-1"},
  {"sensor_id": "sensor-002", "timestamp": "2024-01-01T12:01:00Z", "temperature": 24.1, "humidity": 63.8, "pressure": 1012.95, "location": "office-2"},
  {"sensor_id": "sensor-003", "timestamp": "2024-01-01T12:02:00Z", "temperature": 22.8, "humidity": 67.1, "pressure": 1013.45, "location": "office-1"}
]'

echo "$SAMPLE_DATA" | gsutil cp - gs://${PROJECT_ID}-raw-data/sensor-data/sample_data.json
echo -e "${GREEN}✓ Sample data created${NC}"

echo ""
echo -e "${YELLOW}Testing Dataproc cluster with a simple job...${NC}"

# Submit a simple test job
echo -n "Submitting test job... "
if gcloud dataproc jobs submit pyspark \
    gs://$STAGING_BUCKET/dataproc/jobs/process_sensor_data.py \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --async; then
    echo -e "${GREEN}✓${NC}"
    echo "Job submitted successfully. Check the Dataproc console for status."
else
    echo -e "${RED}✗ Failed${NC}"
fi

echo ""
echo -e "${GREEN}Dataproc setup completed!${NC}"
echo ""
echo -e "${YELLOW}Cluster Details:${NC}"
echo "  • Cluster Name: $CLUSTER_NAME"
echo "  • Region: $REGION"
echo "  • Master: 1x n1-standard-2"
echo "  • Workers: 2x n1-standard-2 (auto-scaling up to 10)"
echo "  • Staging Bucket: gs://$STAGING_BUCKET"

echo ""
echo -e "${YELLOW}Available Jobs:${NC}"
echo "  • process_sensor_data.py - Process raw sensor data"
echo "  • batch_aggregation.py - Create daily aggregations"

echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  Submit PySpark job: gcloud dataproc jobs submit pyspark gs://$STAGING_BUCKET/dataproc/jobs/JOB_FILE.py --cluster=$CLUSTER_NAME --region=$REGION"
echo "  List jobs: gcloud dataproc jobs list --region=$REGION --cluster=$CLUSTER_NAME"
echo "  View job output: gcloud dataproc jobs wait JOB_ID --region=$REGION"
echo "  Delete cluster: gcloud dataproc clusters delete $CLUSTER_NAME --region=$REGION"

echo ""
echo -e "${YELLOW}Console URLs:${NC}"
echo "  Dataproc Console: https://console.cloud.google.com/dataproc/clusters?project=$PROJECT_ID"
echo "  Job History: https://console.cloud.google.com/dataproc/jobs?project=$PROJECT_ID"

echo ""
echo "Next step: Run './step9-setup-gke.sh' to create GKE cluster"
