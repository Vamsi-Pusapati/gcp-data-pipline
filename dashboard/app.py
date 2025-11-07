import os
import pandas as pd
import plotly.express as px
import streamlit as st
from google.cloud import bigquery
from google.oauth2 import service_account
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT", "gcp-project-deliverable")
DATASET = "medicaid_enriched"
TABLE = "nadac_drugs_enriched"

def _build_client():
    """
    Build BigQuery client with authentication priority:
    1. Workload Identity (GKE) - uses Application Default Credentials (ADC)
    2. GOOGLE_APPLICATION_CREDENTIALS - path to service account key
    3. SERVICE_ACCOUNT_SECRET - service account JSON (string or file path)
    4. Local key file - for development only
    """
    
    # Method 1: Try Workload Identity / ADC first (recommended for GKE)
    # This works automatically in GKE when Workload Identity is configured
    try:
        # Don't specify credentials - let google.auth detect them automatically
        client = bigquery.Client(project=PROJECT)
        # Test the connection
        client.query("SELECT 1").result()
        logger.info("✓ Using Application Default Credentials (Workload Identity or gcloud auth)")
        return client
    except Exception as e:
        logger.warning(f"ADC/Workload Identity not available: {e}")
    
    # Method 2: GOOGLE_APPLICATION_CREDENTIALS (standard GCP env var)
    key_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if key_path and os.path.isfile(key_path):
        try:
            creds = service_account.Credentials.from_service_account_file(key_path)
            client = bigquery.Client(project=PROJECT, credentials=creds)
            logger.info(f"✓ Using GOOGLE_APPLICATION_CREDENTIALS: {key_path}")
            return client
        except Exception as e:
            logger.warning(f"Failed to use GOOGLE_APPLICATION_CREDENTIALS: {e}")
    
    # Method 3: SERVICE_ACCOUNT_SECRET (custom env var for flexibility)
    secret = os.getenv("SERVICE_ACCOUNT_SECRET")
    if secret:
        try:
            # Check if it's raw JSON
            if secret.strip().startswith('{'):
                info = json.loads(secret)
                creds = service_account.Credentials.from_service_account_info(info)
                client = bigquery.Client(project=info.get('project_id', PROJECT), credentials=creds)
                logger.info("✓ Using SERVICE_ACCOUNT_SECRET (JSON string)")
                return client
            # Otherwise treat as file path
            elif os.path.isfile(secret):
                creds = service_account.Credentials.from_service_account_file(secret)
                client = bigquery.Client(project=PROJECT, credentials=creds)
                logger.info(f"✓ Using SERVICE_ACCOUNT_SECRET (file): {secret}")
                return client
        except Exception as e:
            logger.warning(f"Failed to use SERVICE_ACCOUNT_SECRET: {e}")
    
    # Method 4: Local key file (development only - NOT for production)
    default_key_path = os.path.join(
        os.path.dirname(__file__), 
        "service_account_secret", 
        "gcp-project-deliverable-c6b076e690d1.json"
    )
    if os.path.isfile(default_key_path):
        try:
            creds = service_account.Credentials.from_service_account_file(default_key_path)
            with open(default_key_path, 'r') as f:
                project_from_key = json.load(f).get('project_id', PROJECT)
            client = bigquery.Client(project=project_from_key, credentials=creds)
            logger.warning(f"⚠ Using local key file (DEV ONLY): {default_key_path}")
            return client
        except Exception as e:
            logger.warning(f"Failed to use local key file: {e}")
    
    # If all methods fail, raise error
    raise RuntimeError(
        "Failed to authenticate with BigQuery. Please ensure one of the following:\n"
        "  - Running in GKE with Workload Identity configured\n"
        "  - GOOGLE_APPLICATION_CREDENTIALS env var set\n"
        "  - SERVICE_ACCOUNT_SECRET env var set\n"
        "  - Local key file exists (development only)"
    )

# Initialize BigQuery client
try:
    client = _build_client()
    logger.info(f"✓ BigQuery client initialized for project: {PROJECT}")
except Exception as e:
    logger.error(f"✗ Failed to initialize BigQuery client: {e}")
    st.error(f"Failed to connect to BigQuery: {e}")
    st.stop()

st.set_page_config(page_title="Medicaid Drug Dashboard", layout="wide")
st.title("Medicaid Drug Dashboard")

@st.cache_data(ttl=600)
def run_query(sql, params=None):
    job = client.query(sql, job_config=bigquery.QueryJobConfig(query_parameters=params or []))
    return job.result().to_dataframe()

# Sidebar Filters
st.sidebar.header("Filters")
days = st.sidebar.slider("Trend window (days)", 30, 365, 90)
limit_top = st.sidebar.slider("Top drugs limit", 5, 50, 20)
form_filter = st.sidebar.text_input("Form filter (exact)")
ndc_filter = st.sidebar.text_input("NDC filter (exact)")

form_clause = "AND drug_form = @form" if form_filter else ""
ndc_clause = "AND ndc = @ndc" if ndc_filter else ""

params_top = []
if form_filter:
    params_top.append(bigquery.ScalarQueryParameter("form", "STRING", form_filter))

params_trend = []
if ndc_filter:
    params_trend.append(bigquery.ScalarQueryParameter("ndc", "STRING", ndc_filter))

# Top drugs (bar)
top_sql = f"""
SELECT drug_name, COUNT(*) record_count
FROM `{PROJECT}.{DATASET}.{TABLE}`
WHERE drug_name IS NOT NULL AND drug_name!=''
{form_clause}
GROUP BY drug_name
ORDER BY record_count DESC
LIMIT {limit_top}
"""
top_df = run_query(top_sql, params_top)
col1, col2 = st.columns([2,1])
col1.subheader("Top Drugs by Record Count")
if not top_df.empty:
    col1.plotly_chart(px.bar(top_df, x="drug_name", y="record_count", height=450), use_container_width=True)
else:
    col1.info("No data for selected filters")

# Form distribution (pie) - Top 10 + Other
form_sql = f"""
WITH ranked AS (
  SELECT drug_form, COUNT(*) cnt,
         ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) rn
  FROM `{PROJECT}.{DATASET}.{TABLE}`
  WHERE drug_form IS NOT NULL AND drug_form!=''
  GROUP BY drug_form
)
SELECT 
  CASE WHEN rn <= 10 THEN drug_form ELSE 'Other' END AS drug_form,
  SUM(cnt) AS cnt
FROM ranked
GROUP BY drug_form
ORDER BY cnt DESC
"""
form_df = run_query(form_sql)
col2.subheader("Form Distribution (Top 10)")
if not form_df.empty:
    col2.plotly_chart(px.pie(form_df, names="drug_form", values="cnt", height=450), use_container_width=True)
else:
    col2.info("No form data")

# Price trend (line)
trend_sql = f"""
SELECT DATE(effective_date) d,
       AVG(CAST(REGEXP_REPLACE(nadac_per_unit, r'[^0-9.]', '') AS FLOAT64)) avg_nadac
FROM `{PROJECT}.{DATASET}.{TABLE}`
WHERE effective_date >= DATE_SUB(CURRENT_DATE(), INTERVAL {days} DAY)
{ndc_clause}
GROUP BY d
ORDER BY d
"""
trend_df = run_query(trend_sql, params_trend)
st.subheader("Average NADAC Price Trend")
if not trend_df.empty:
    st.plotly_chart(px.line(trend_df, x="d", y="avg_nadac", markers=True, height=400), use_container_width=True)
else:
    st.info("No trend data for selected filters")

# Scatter (optional)
scatter_sql = f"""
SELECT SAFE_CAST(drug_strength AS FLOAT64) strength_val,
       CAST(REGEXP_REPLACE(nadac_per_unit, r'[^0-9.]', '') AS FLOAT64) nadac_value,
       drug_form, drug_name
FROM `{PROJECT}.{DATASET}.{TABLE}`
WHERE drug_strength IS NOT NULL AND nadac_per_unit IS NOT NULL
LIMIT 2000
"""
scatter_df = run_query(scatter_sql)
st.subheader("Strength vs NADAC ")
if not scatter_df.empty:
    st.plotly_chart(px.scatter(scatter_df, x="strength_val", y="nadac_value", color="drug_form", hover_data=["drug_name"], height=450), use_container_width=True)
else:
    st.info("No scatter data")

st.caption("Data source: BigQuery enriched Medicaid table")
