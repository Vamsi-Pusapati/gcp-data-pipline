#!/usr/bin/env python3
"""
Extract RAG system classes from Jupyter notebook.
This creates a standalone rag_system.py module from the notebook.

Usage:
    python extract_notebook_code.py
"""

import json
import sys
from pathlib import Path

def extract_classes_from_notebook(notebook_path: str, output_path: str):
    """
    Extract Python classes and functions from Jupyter notebook.
    
    Args:
        notebook_path: Path to .ipynb file
        output_path: Path to output .py file
    """
    # Read notebook
    with open(notebook_path, 'r', encoding='utf-8') as f:
        notebook = json.load(f)
    
    # Extract code cells
    code_cells = []
    for cell in notebook['cells']:
        if cell['cell_type'] == 'code':
            # Skip cells that are just imports or examples
            source = ''.join(cell['source'])
            
            # Skip cells with just comments or examples
            if (source.strip() and 
                not source.strip().startswith('#') and
                not source.strip().startswith('!pip') and
                'test_retrieval' not in source and
                'ask_question' not in source and
                'example' not in source.lower()):
                
                code_cells.append(source)
    
    # Build output file
    output_lines = [
        '"""',
        'RAG System for Medicaid Drug Information',
        'Extracted from drug_rag_system.ipynb',
        '',
        'This module contains the core classes for the RAG system:',
        '- EmbeddingGenerator: Generate embeddings using Vertex AI',
        '- DrugVectorStore: FAISS-based vector store',
        '- DrugRAGSystem: Complete RAG system with LLM',
        '- ConversationalRAG: Multi-turn conversation interface',
        '"""',
        '',
        'import os',
        'import pandas as pd',
        'import numpy as np',
        'from typing import List, Dict, Any',
        'from google.cloud import bigquery',
        'import vertexai',
        'from vertexai.language_models import TextEmbeddingModel',
        'from vertexai.generative_models import GenerativeModel',
        'import faiss',
        'import pickle',
        'import logging',
        '',
        'logging.basicConfig(level=logging.INFO)',
        'logger = logging.getLogger(__name__)',
        '',
        '# Constants',
        'EMBEDDING_DIMENSION = 768',
        'EXPLANATION_CODE_MAP = {',
        "    '1': 'Calculated from most recent pharmacy survey',",
        "    '2': 'Average acquisition cost within ±2% of current NADAC; carried forward',",
        "    '3': 'Survey NADAC adjusted due to pricing changes or help desk inquiry',",
        "    '4': 'NADAC carried forward from previous file',",
        "    '5': 'NADAC calculated based on package size',",
        "    '6': 'CMS S/I/N designation modified per State Medicaid reimbursement practices',",
        "    '7': 'Reserved',",
        "    '8': 'Reserved',",
        "    '9': 'Reserved',",
        "    '10': 'Reserved'",
        '}',
        '',
    ]
    
    # Add key functions and classes
    # You'll need to manually identify which cells contain the classes
    # For now, we'll provide a template
    
    output_lines.extend([
        '# ============================================================================',
        '# CORE FUNCTIONS',
        '# ============================================================================',
        '',
        'def load_drug_data(project_id: str, dataset_id: str, table_id: str, limit: int = None) -> pd.DataFrame:',
        '    """Load enriched drug data from BigQuery."""',
        '    client = bigquery.Client(project=project_id)',
        '    ',
        '    query = f"""',
        '    SELECT *',
        '    FROM `{project_id}.{dataset_id}.{table_id}`',
        '    WHERE ndc_description IS NOT NULL AND drug_name IS NOT NULL',
        '    {f"LIMIT {limit}" if limit else ""}',
        '    """',
        '    ',
        '    logger.info(f"Loading data from {project_id}.{dataset_id}.{table_id}...")',
        '    df = client.query(query).to_dataframe()',
        '    logger.info(f"✓ Loaded {len(df)} drug records")',
        '    return df',
        '',
        '',
        'def create_rich_text_description(row: pd.Series) -> str:',
        '    """Create a rich text description for each drug."""',
        '    parts = []',
        '    if pd.notna(row["ndc_description"]):',
        '        parts.append(f"Drug: {row[\'ndc_description\']}")',
        '    if pd.notna(row["drug_name"]):',
        '        parts.append(f"Name: {row[\'drug_name\']}")',
        '    if pd.notna(row["drug_strength"]):',
        '        parts.append(f"Strength: {row[\'drug_strength\']}")',
        '    if pd.notna(row["drug_dosage"]):',
        '        parts.append(f"Dosage: {row[\'drug_dosage\']}")',
        '    if pd.notna(row["drug_form"]):',
        '        parts.append(f"Form: {row[\'drug_form\']}")',
        '    if pd.notna(row["nadac_per_unit"]):',
        '        parts.append(f"Price: ${row[\'nadac_per_unit\']} per {row.get(\'pricing_unit\', \'unit\')}")',
        '    return ". ".join(parts) + "."',
        '',
        '',
        '# ============================================================================',
        '# COPY THE FOLLOWING CLASSES FROM THE NOTEBOOK:',
        '# - EmbeddingGenerator',
        '# - DrugVectorStore',
        '# - DrugRAGSystem',
        '# - ConversationalRAG (optional)',
        '# ============================================================================',
        '',
        '# TODO: Copy class definitions from cells in the notebook',
        '# You can find them in sections 5, 6, 8, and 11',
        '',
    ])
    
    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output_lines))
    
    print(f"✓ Created {output_path}")
    print("\n⚠ IMPORTANT: You need to manually copy the following classes from the notebook:")
    print("  - EmbeddingGenerator (Section 5)")
    print("  - DrugVectorStore (Section 6)")
    print("  - DrugRAGSystem (Section 8)")
    print("  - ConversationalRAG (Section 11, optional)")
    print("\nOpen the notebook and copy these class definitions into the TODO section.")

def main():
    notebook_path = "drug_rag_system.ipynb"
    output_path = "rag_system.py"
    
    if not Path(notebook_path).exists():
        print(f"Error: {notebook_path} not found!")
        print("Make sure you're running this script in the notebooks/ directory.")
        sys.exit(1)
    
    extract_classes_from_notebook(notebook_path, output_path)
    
    print("\n" + "="*80)
    print("Next steps:")
    print("="*80)
    print("1. Edit rag_system.py and copy the class definitions from the notebook")
    print("2. Test locally: python -c 'from rag_system import DrugRAGSystem'")
    print("3. Run the API: python rag_api.py")
    print("4. Build Docker image: docker build -t drug-rag-api .")

if __name__ == "__main__":
    main()
