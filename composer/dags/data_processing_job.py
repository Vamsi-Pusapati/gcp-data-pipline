"""
Medicaid NADAC enrichment Spark job.
Reads staging table medicaid_staging.nadac_drugs, derives drug_name components and explanation_code descriptions,
writes enriched data to medicaid_enriched.nadac_drugs_enriched.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, trim, split, size, element_at, array_join, slice, when, lit,
    regexp_extract, current_timestamp, udf, array, transform
)
from pyspark.sql.types import StringType, IntegerType
import argparse
import logging

EXPLANATION_CODE_MAP = {
    '1': 'Calculated from most recent pharmacy survey',
    '2': 'Average acquisition cost within ±2% of current NADAC; carried forward',
    '3': 'Survey NADAC adjusted due to pricing changes or help desk inquiry',
    '4': 'NADAC carried forward from previous file',
    '5': 'NADAC calculated based on package size',
    '6': 'CMS S/I/N designation modified per State Medicaid reimbursement practices',
    '7': 'Reserved',
    '8': 'Reserved',
    '9': 'Reserved',
    '10': 'Reserved'
}

# UDF to map comma separated explanation_code to concatenated descriptions
@udf(returnType=StringType())
def map_explanation_codes(codes_str):
    if not codes_str:
        return None
    parts = [p.strip() for p in str(codes_str).split(',') if p.strip()]
    mapped = [EXPLANATION_CODE_MAP.get(p) for p in parts if EXPLANATION_CODE_MAP.get(p)]
    return ' | '.join(mapped) if mapped else None


def create_spark_session(app_name="MedicaidNADACEnrichment"):
    return SparkSession.builder \
        .appName(app_name) \
        .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.32.0") \
        .getOrCreate()


def read_staging(spark, project_id, dataset, table):
    table_id = f"{project_id}.{dataset}.{table}"
    df = spark.read.format("bigquery") \
        .option("table", table_id) \
        .option("project", project_id) \
        .option("parentProject", project_id) \
        .option("temporaryGcsBucket", f"{project_id}-dataproc-staging") \
        .load()
    logging.info(f"Loaded {df.count()} staging rows from {table_id}")
    return df


def enrich(df):
    # Clean ndc_description
    df = df.withColumn("ndc_description", trim(col("ndc_description")))

    # Tokenize description by single space
    tokens = split(col("ndc_description"), " ")

    # Derive components (ensure sufficient length)
    token_count = size(tokens)

    drug_form = when(token_count >= 1, element_at(tokens, -1))
    drug_dosage = when(token_count >= 2, element_at(tokens, -2))
    drug_strength_token = when(token_count >= 3, element_at(tokens, -3))

    # Drug name: all tokens except last 3 (if length >=4) else all except what used
    drug_name = when(token_count >= 4, array_join(slice(tokens, 1, token_count - 3), ' ')) \
        .otherwise(when(token_count >= 3, array_join(slice(tokens, 1, token_count - 2), ' '))
                   .otherwise(when(token_count >= 2, array_join(slice(tokens, 1, token_count - 1), ' '))
                              .otherwise(col("ndc_description"))))

    # Extract numeric portion of drug strength (leading integer) if present
    drug_strength_int = regexp_extract(drug_strength_token, r'^(\\d+)', 1)
    drug_strength_int = when(drug_strength_int == '', None).otherwise(drug_strength_int.cast(IntegerType()))

    df_enriched = df \
        .withColumn("drug_form", drug_form) \
        .withColumn("drug_dosage", drug_dosage) \
        .withColumn("drug_strength", drug_strength_int) \
        .withColumn("drug_name", drug_name) \
        .withColumn("explanation_code_description", map_explanation_codes(col("explanation_code"))) \
        .withColumn("enriched_timestamp", current_timestamp())

    logging.info(f"Enriched rows: {df_enriched.count()}")
    return df_enriched


def write_enriched(df, project_id, dataset, table):
    table_id = f"{project_id}.{dataset}.{table}"
    df.write \
        .format("bigquery") \
        .option("table", table_id) \
        .option("project", project_id) \
        .option("parentProject", project_id) \
        .option("temporaryGcsBucket", f"{project_id}-dataproc-staging") \
        .option("writeMethod", "direct") \
        .mode("append") \
        .save()
    logging.info(f"Written {df.count()} enriched rows to {table_id}")


def main():
    parser = argparse.ArgumentParser(description='Medicaid NADAC enrichment job')
    parser.add_argument('--project-id', default="gcp-project-deliverable", help='GCP Project ID')
    parser.add_argument('--staging-dataset', default='medicaid_staging', help='Staging dataset name')
    parser.add_argument('--staging-table', default='nadac_drugs', help='Staging table name')
    parser.add_argument('--enriched-dataset', default='medicaid_enriched', help='Enriched dataset name')
    parser.add_argument('--enriched-table', default='nadac_drugs_enriched', help='Enriched table name')
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    spark = create_spark_session()

    try:
        staging_df = read_staging(spark, args.project_id, args.staging_dataset, args.staging_table)
        enriched_df = enrich(staging_df)
        write_enriched(enriched_df, args.project_id, args.enriched_dataset, args.enriched_table)
        logging.info("Enrichment completed successfully")
    except Exception as e:
        logging.error(f"Enrichment failed: {e}")
        raise
    finally:
        spark.stop()


if __name__ == '__main__':
    main()
