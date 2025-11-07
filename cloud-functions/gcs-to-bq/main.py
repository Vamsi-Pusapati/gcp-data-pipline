import functions_framework
from google.cloud import bigquery, storage
import json
import logging
import os
import base64
from typing import Tuple, List, Dict, Any
from datetime import datetime
import pandas as pd  # Added pandas import

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Env config
PROJECT_ID = os.environ.get('GCP_PROJECT_ID', 'gcp-project-deliverable')
DATASET = os.environ.get('BQ_STAGING_DATASET', 'medicaid_staging')
TABLE = os.environ.get('BQ_STAGING_TABLE', 'nadac_drugs')
RAW_PREFIX = 'drug_data/raw/'
PROCESSED_PREFIX = 'drug_data/processed/'

# Clients (created once per instance)
bq_client = bigquery.Client(project=PROJECT_ID)
storage_client = storage.Client(project=PROJECT_ID)

def parse_cloud_event(cloud_event) -> Tuple[str, str]:
    """Extract bucket and object name from Pub/Sub CloudEvent."""
    data = cloud_event.data
    if not data or 'message' not in data or 'attributes' not in data['message']:
        raise ValueError('Unsupported event structure – missing message.attributes')
    attrs = data['message']['attributes']
    bucket = attrs.get('bucketId')
    name = attrs.get('objectId')
    if not bucket or not name:
        raise ValueError(f'Missing bucket/object in attributes: {attrs}')
    return bucket, name

def download_json(bucket_name: str, blob_name: str) -> Dict[str, Any]:
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(blob_name)
    if not blob.exists():
        raise FileNotFoundError(f'Blob not found: gs://{bucket_name}/{blob_name}')
    text = blob.download_as_text()
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        raise ValueError(f'Invalid JSON in {blob_name}: {e}')

def extract_records(payload: Dict[str, Any]) -> List[Dict[str, Any]]:
    # Updated to prefer 'data.results' (new response) over deprecated 'raw_response.results'
    if isinstance(payload, dict):
        # New structure
        if 'data' in payload and isinstance(payload['data'], dict):
            results = payload['data'].get('results', [])
            if isinstance(results, list):
                return results
        # Legacy structure fallback
        if 'raw_response' in payload and isinstance(payload['raw_response'], dict):
            results = payload['raw_response'].get('results', [])
            if isinstance(results, list):
                return results
        # Fallback to top-level results
        if 'results' in payload and isinstance(payload['results'], list):
            return payload['results']
    return []

def clean_ndc(ndc_val: Any) -> Any:
    if ndc_val is None:
        return None
    s = str(ndc_val).strip()
    if not s:
        return None
    # Remove non-digits
    digits = ''.join(c for c in s if c.isdigit())
    if not digits:
        return None
    try:
        return int(digits)
    except ValueError:
        return None

def parse_date(value: Any) -> Any:
    if value is None:
        return None
    s = str(value).strip()
    if s in ('', 'None', 'null'):
        return None
    # Try known formats
    for fmt in ('%Y-%m-%d', '%m/%d/%Y', '%Y/%m/%d'):
        try:
            return datetime.strptime(s, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    # If already looks ISO-like (e.g. 2025-01-01T00:00:00Z) take first 10 chars
    if len(s) >= 10 and s[4] == '-' and s[7] == '-':
        return s[:10]
    return None

def transform(records: List[Dict[str, Any]]) -> pd.DataFrame:
    """Convert raw records list into a cleaned pandas DataFrame matching table schema (ndc kept as STRING)."""
    if not records:
        return pd.DataFrame(columns=[
            'ndc_description','ndc','nadac_per_unit','effective_date','pricing_unit',
            'pharmacy_type_indicator','otc','explanation_code','classification_for_rate_setting',
            'corresponding_generic_drug_nadac_per_unit','corresponding_generic_drug_effective_date','as_of_date'
        ])
    df = pd.DataFrame(records)
    # Normalize NDC -> keep digits only as string (11-digit) but DO NOT convert to int
    if 'ndc' in df.columns:
        df['ndc'] = df['ndc'].apply(lambda v: ''.join(c for c in str(v) if c.isdigit()) if v is not None else None)
        # Drop if resulting string empty
        df.loc[df['ndc'].apply(lambda x: x is not None and len(x)==0), 'ndc'] = None
    start_rows = len(df)
    df = df.dropna(subset=['ndc'])
    df = df[df['ndc'] != '']
    logger.info(f'Removed {start_rows - len(df)} rows without valid ndc string')
    # Date parsing helper
    date_cols = ['effective_date','corresponding_generic_drug_effective_date','as_of_date']
    for col in date_cols:
        if col in df.columns:
            df[col] = df[col].apply(_parse_date)
        else:
            df[col] = None
    # Ensure all expected columns present
    expected_order = [
        'ndc_description','ndc','nadac_per_unit','effective_date','pricing_unit',
        'pharmacy_type_indicator','otc','explanation_code','classification_for_rate_setting',
        'corresponding_generic_drug_nadac_per_unit','corresponding_generic_drug_effective_date','as_of_date'
    ]
    for col in expected_order:
        if col not in df.columns:
            df[col] = None
    df = df[expected_order]
    logger.info(f'Transformed DataFrame shape: {df.shape} (ndc kept as STRING)')
    return df

def _to_float(val: Any) -> Any:
    try:
        return float(str(val).replace('$','').replace(',','').strip())
    except Exception:
        return None

def _parse_date(val: Any) -> Any:
    if val is None:
        return None
    s = str(val).strip()
    if s in ('','None','null'):
        return None
    for fmt in ('%Y-%m-%d','%m/%d/%Y','%Y/%m/%d'):
        try:
            return datetime.strptime(s, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    if len(s) >= 10 and s[4]=='-' and s[7]=='-':
        return s[:10]
    return None

def load_to_bigquery(df: pd.DataFrame):
    if df.empty:
        logger.info('No rows to load (empty DataFrame).')
        return
    table_id = f'{PROJECT_ID}.{DATASET}.{TABLE}'
    # Minimal date normalization to avoid pyarrow object conversion error
    date_cols = ['effective_date', 'corresponding_generic_drug_effective_date', 'as_of_date']
    for col in date_cols:
        if col in df.columns:
            # Clean non-scalar / empty values
            df[col] = df[col].apply(lambda v: None if (pd.isna(v) or v in ('', 'None', 'null') or isinstance(v, (list, dict))) else v)
            # Convert valid strings to date objects
            df[col] = pd.to_datetime(df[col], errors='coerce').dt.date
            logger.info(f'Normalized date column {col}: dtype={df[col].dtype}, nulls={df[col].isna().sum()}')
    logger.info(f'Appending {len(df)} rows to {table_id} (after date normalization)')
    try:
        job_config = bigquery.LoadJobConfig(write_disposition='WRITE_APPEND')
        load_job = bq_client.load_table_from_dataframe(df, table_id, job_config=job_config)
        load_job.result()
        logger.info(f'Load job completed. Loaded {df.shape[0]} rows.')
    except Exception as e:
        logger.error(f'Failed DataFrame load: {e}')
        raise

def move_to_processed(bucket_name: str, blob_name: str):
    """Move the processed file from raw to processed prefix with verification and detailed logging."""
    try:
        bucket = storage_client.bucket(bucket_name)
        source_blob = bucket.blob(blob_name)
        if not source_blob.exists():
            logger.warning(f'Source blob missing during move: gs://{bucket_name}/{blob_name}')
            return None
        if not blob_name.startswith(RAW_PREFIX):
            logger.info(f'Blob {blob_name} does not start with raw prefix; skipping move')
            return None
        dest_name = blob_name.replace(RAW_PREFIX, PROCESSED_PREFIX)
        logger.info(f'Initiating move: gs://{bucket_name}/{blob_name} -> gs://{bucket_name}/{dest_name}')
        # Copy using bucket.copy_blob (correct API)
        bucket.copy_blob(source_blob, bucket, dest_name)
        dest_blob = bucket.blob(dest_name)
        if not dest_blob.exists():
            logger.error(f'Copy verification failed: destination blob not found gs://{bucket_name}/{dest_name}')
            return None
        logger.info(f'Copied file to processed path; dest size: {dest_blob.size} bytes')
        # Delete original
        source_blob.delete()
        logger.info(f'Deleted original raw file: gs://{bucket_name}/{blob_name}')
        return dest_name
    except Exception as e:
        logger.error(f'Failed to move file {blob_name} to processed (copy/delete path). Attempting rewrite rename: {e}')
        try:
            # Fallback: use rewrite to new name then delete original if different
            bucket = storage_client.bucket(bucket_name)
            source_blob = bucket.blob(blob_name)
            dest_name = blob_name.replace(RAW_PREFIX, PROCESSED_PREFIX)
            dest_blob = bucket.blob(dest_name)
            token, bytes_rewritten, total_bytes = dest_blob.rewrite(source_blob)
            logger.info(f'Rewrite operation: {bytes_rewritten}/{total_bytes} bytes, token={token}')
            if dest_blob.exists():
                source_blob.delete()
                logger.info(f'Rewrite succeeded, original deleted: {blob_name}')
                return dest_name
        except Exception as e2:
            logger.error(f'Rewrite fallback failed for {blob_name}: {e2}')
        return None

@functions_framework.cloud_event
def process_medicaid_gcs_to_bq(cloud_event):
    try:
        bucket_name, blob_name = parse_cloud_event(cloud_event)
        if not blob_name.startswith(RAW_PREFIX):
            logger.info(f'Ignoring object outside raw prefix: {blob_name}')
            return 'Ignored'
        logger.info(f'Start processing gs://{bucket_name}/{blob_name}')
        payload = download_json(bucket_name, blob_name)
        records = extract_records(payload)
        if not records:
            logger.info('No records found in JSON')
            moved = move_to_processed(bucket_name, blob_name)
            logger.info(f'Move result (no data case): {moved}')
            return 'NoData'
        df = transform(records)
        load_to_bigquery(df)
        moved = move_to_processed(bucket_name, blob_name)
        logger.info(f'Move result: {moved}')
        return f'OK:{len(df)}'
    except Exception as e:
        logger.error(f'Processing failed: {e}')
        return f'Error:{e}'
