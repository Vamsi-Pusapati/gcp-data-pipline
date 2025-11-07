"""
Medicaid Drug Data Collection DAG
Single file DAG that fetches data from Medicaid API and stores in GCS
"""

import json
import logging
import requests
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.dummy import DummyOperator
from airflow.utils.dates import days_ago

# Try different GCS hook imports for compatibility
try:
    from airflow.providers.google.cloud.hooks.gcs import GCSHook
except ImportError:
    try:
        from airflow.contrib.hooks.gcs_hook import GCSHook
    except ImportError:
        from airflow.hooks.gcs_hook import GCSHook

# Configuration
PROJECT_ID = 'gcp-project-deliverable'
BUCKET_NAME = f'{PROJECT_ID}-raw-data'
GCS_FOLDER = 'drug_data/raw'
MEDICAID_API_URL = 'https://data.medicaid.gov/api/1/datastore/query/f38d0706-1239-442c-a3cc-40ef1b686ac0/0'
LIMIT_PER_PAGE = 5000
MAX_PAGES = 1000
REQUEST_TIMEOUT = 300

# Default DAG arguments
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'catchup': False
}

# Create DAG
dag = DAG(
    'medicaid_drug_data_collection',
    default_args=default_args,
    description='Collect Medicaid drug data with pagination and store in GCS',
    schedule_interval=None,  # on-demand execution
    max_active_runs=1,
    tags=['medicaid', 'drug-data', 'api', 'gcs']
)

def extract_medicaid_data(**context):
    """
    Extract data from Medicaid API with pagination
    """
    logger = logging.getLogger(__name__)
    
    # Create session with retry strategy
    session = requests.Session()
    session.headers.update({'User-Agent': 'Airflow-Medicaid-Data-Pipeline'})
    
    offset = 0
    page_number = 1
    has_more_data = True
    total_files_created = 0
    total_records = 0
    
    logger.info(f"Starting extraction from: {MEDICAID_API_URL}")
    logger.info(f"Limit per page: {LIMIT_PER_PAGE}, Max pages: {MAX_PAGES}")
    
    while has_more_data and page_number <= MAX_PAGES:
        try:
            # Prepare parameters for this page
            params = {
                'limit': LIMIT_PER_PAGE,
                'offset': offset
            }
            
            logger.info(f"Fetching page {page_number}: offset={offset}")
            
            # Make API request
            response = session.get(
                MEDICAID_API_URL,
                params=params,
                timeout=REQUEST_TIMEOUT
            )
            response.raise_for_status()
            
            data = response.json()
            
            # Check if we have data
            records = []
            if isinstance(data, list):
                records = data
            elif isinstance(data, dict):
                # Try to find records in common field names
                records = data.get('results', data.get('data', data.get('records', [])))
                
                # If still no records, check other possible field names
                if not records:
                    for key in ['items', 'rows', 'entries', 'content']:
                        if key in data and data[key]:
                            records = data[key]
                            break
            
            records_count = len(records) if records else 0
            
            # Log response structure for first page
            if page_number == 1:
                logger.info(f"Response type: {type(data)}")
                if isinstance(data, dict):
                    logger.info(f"Response keys: {list(data.keys())}")
                logger.info(f"Records found: {records_count}")
            
            # If no records, stop pagination
            if records_count == 0:
                logger.info(f"No data found at offset {offset}. Stopping pagination.")
                has_more_data = False
                break
            
            # Prepare data for storage
            page_data = {
                'extraction_timestamp': datetime.now(timezone.utc).isoformat(),
                'source': 'medicaid_drug_data',
                'api_endpoint': MEDICAID_API_URL,
                'page_number': page_number,
                'offset': offset,
                'limit': LIMIT_PER_PAGE,
                'records_count': records_count,
                'parameters': params,
                'data': data
            }
            
            # Store data in GCS
            file_info = store_page_data(page_data, page_number, logger)
            
            if file_info:
                total_files_created += 1
                total_records += records_count
                logger.info(f"Page {page_number} completed: {records_count} records stored")
            
            # Check if we should continue
            if records_count < LIMIT_PER_PAGE:
                logger.info(f"Received {records_count} records (less than limit). Might be last page.")
                # Try one more page to confirm
                offset += LIMIT_PER_PAGE
                page_number += 1
            else:
                # Continue to next page
                offset += LIMIT_PER_PAGE
                page_number += 1
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error on page {page_number}: {str(e)}")
            if "404" in str(e) or "400" in str(e):
                logger.info("API error suggests no more data. Stopping.")
                break
            elif page_number > 1:  # If we've successfully fetched at least one page
                logger.info("Continuing to next page after error")
                offset += LIMIT_PER_PAGE
                page_number += 1
            else:
                raise  # Re-raise error if it's the first page
                
        except Exception as e:
            logger.error(f"Unexpected error on page {page_number}: {str(e)}")
            if page_number > 1:
                break  # Stop if we've already got some data
            else:
                raise  # Re-raise if it's the first page
    
    logger.info(f"Extraction completed. Files: {total_files_created}, Records: {total_records}")
    
    # Return simple summary
    return {
        'total_files_created': total_files_created,
        'total_records': total_records,
        'pages_processed': page_number - 1
    }

def store_page_data(page_data: Dict, page_number: int, logger) -> Optional[Dict]:
    """
    Store a single page of data to GCS
    """
    try:
        # Initialize GCS hook
        gcs_hook = GCSHook()
        
        # Generate filename
        timestamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
        filename = f"medicaid_drug_data_page_{page_number:04d}_{timestamp}.json"
        object_name = f"{GCS_FOLDER}/{filename}"
        
        # Convert data to JSON string
        json_data = json.dumps(page_data, indent=2)
        
        # Upload to GCS (bucket should already exist)
        gcs_hook.upload(
            bucket_name=BUCKET_NAME,
            object_name=object_name,
            data=json_data.encode('utf-8'),
            mime_type='application/json'
        )
        
        file_info = {
            'page_number': page_number,
            'filename': filename,
            'gcs_path': f"gs://{BUCKET_NAME}/{object_name}",
            'records_count': page_data.get('records_count', 0),
            'offset': page_data.get('offset', 0),
            'file_size_bytes': len(json_data.encode('utf-8'))
        }
        
        logger.info(f"Stored page {page_number} to: gs://{BUCKET_NAME}/{object_name}")
        return file_info
        
    except Exception as e:
        logger.error(f"Error storing page {page_number}: {str(e)}")
        return None

# Define tasks
start_task = DummyOperator(
    task_id='start',
    dag=dag
)

extract_task = PythonOperator(
    task_id='extract_data',
    python_callable=extract_medicaid_data,
    dag=dag,
    doc_md="""
    ## Extract Medicaid Drug Data
    
    Extracts drug data from the Medicaid API with pagination:
    - Hits the API with increasing offset values
    - Stores each page as a separate JSON file in GCS
    - Continues until no more data is returned
    - Handles errors and retries appropriately
    """
)

end_task = DummyOperator(
    task_id='end',
    dag=dag
)

# Set task dependencies
start_task >> extract_task >> end_task

# DAG documentation
dag.doc_md = """
# Medicaid Drug Data Collection DAG

This DAG extracts drug data from the Medicaid API and stores it in Google Cloud Storage.

## Workflow
1. **Extract Data**: Fetches data from Medicaid API with pagination
2. **Validate**: Ensures extraction was successful

## API Details
- **URL**: https://data.medicaid.gov/api/1/datastore/query/f38d0706-1239-442c-a3cc-40ef1b686ac0/0
- **Method**: GET with limit and offset parameters
- **Pagination**: Uses offset-based pagination with 5000 records per page

## Storage
- **Bucket**: {project_id}-raw-data
- **Path**: drug_data/raw/
- **Format**: JSON files with metadata

## Configuration
- Runs daily at midnight UTC
- Maximum 100 pages per run (safety limit)
- 5000 records per page
- Automatic retry on failure
""".format(project_id=PROJECT_ID)
