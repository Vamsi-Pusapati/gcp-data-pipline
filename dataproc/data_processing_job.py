"""
Medicaid NADAC enrichment Spark job.
Reads staging table medicaid_staging.nadac_drugs, derives drug_name components and explanation_code descriptions,
writes enriched data to medicaid_enriched.nadac_drugs_enriched.
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, trim, current_timestamp, udf
)
from pyspark.sql.types import StringType, StructType, StructField  # restore struct types
import argparse
import logging
import re

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

@udf(returnType=StringType())
def map_explanation_codes(codes_str):
    if not codes_str:
        return None
    parts = [p.strip() for p in str(codes_str).split(',') if p.strip()]
    mapped = [EXPLANATION_CODE_MAP.get(p) for p in parts if EXPLANATION_CODE_MAP.get(p)]
    return ' | '.join(mapped) if mapped else None

_NUM_REGEX = re.compile(r'(\d+(?:\.\d+)?)')
_UNIT_SUFFIX = re.compile(r'(MG|MCG|ML|GM|G|%)$', re.IGNORECASE)
_SPLITTER = re.compile(r'[/-]')

# Helper to extract first numeric string value from a token
def _extract_strength_str(token):
    if not token or not any(ch.isdigit() for ch in token):
        return None
    for part in _SPLITTER.split(token):
        cleaned = part.replace('%', '')
        cleaned = _UNIT_SUFFIX.sub('', cleaned)
        m = _NUM_REGEX.search(cleaned)
        if m:
            return m.group(1)
    return None

# Struct schema for parsed components
_components_schema = StructType([
    StructField("drug_name", StringType(), True),
    StructField("drug_strength", StringType(), True),
    StructField("drug_dosage", StringType(), True),
    StructField("drug_form", StringType(), True)
])

@udf(returnType=_components_schema)
def parse_drug_components(desc):
    if not desc:
        return (None, None, None, None)
    text = str(desc).strip()
    if not text:
        return (None, None, None, None)
    tokens = text.split()
    strength_idx = None
    strength_str = None
    strength_token = None
    for i, tok in enumerate(tokens):
        strength_candidate = _extract_strength_str(tok)
        if strength_candidate is not None:
            strength_idx = i
            strength_str = strength_candidate
            strength_token = tok
            break
    if strength_idx is None:
        return (text, None, None, None)
    drug_name = ' '.join(tokens[:strength_idx]) if strength_idx > 0 else tokens[0]

    # Percent rule: if the strength token contains a '%' then that whole token is the dosage and the next token is the form
    if strength_token and '%' in strength_token:
        drug_dosage = strength_token  # keep full token with %
        drug_form = tokens[strength_idx + 1] if len(tokens) > strength_idx + 1 else None
    else:
        # Normal rule: next token dosage, following token form
        drug_dosage = tokens[strength_idx + 1] if len(tokens) > strength_idx + 1 else None
        drug_form = tokens[strength_idx + 2] if len(tokens) > strength_idx + 2 else None

    return (drug_name, strength_str, drug_dosage, drug_form)


def create_spark_session(app_name="MedicaidNADACEnrichment"):
    return SparkSession.builder \
        .appName(app_name) \
        .getOrCreate()


def read_staging(spark, project_id, dataset, table):
    table_id = f"{project_id}.{dataset}.{table}"
    logging.info(f"Loading staging table {table_id}")
    return spark.read.format("bigquery") \
        .option("table", table_id) \
        .option("project", project_id) \
        .option("parentProject", project_id) \
        .option("temporaryGcsBucket", f"{project_id}-dataproc-staging") \
        .load()


def enrich(df):
    df = df.withColumn("ndc_description", trim(col("ndc_description")))
    comps = parse_drug_components(col("ndc_description"))  # struct with fields
    return df \
        .withColumn("drug_name", comps.getField("drug_name")) \
        .withColumn("drug_strength", comps.getField("drug_strength")) \
        .withColumn("drug_dosage", comps.getField("drug_dosage")) \
        .withColumn("drug_form", comps.getField("drug_form")) \
        .withColumn("explanation_code_description", map_explanation_codes(col("explanation_code"))) \
        .withColumn("enriched_timestamp", current_timestamp())


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
        logging.info(f"Loaded {staging_df.count()} staging rows")
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
