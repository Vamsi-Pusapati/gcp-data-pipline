#!/usr/bin/env python3
"""
Setup script for RAG system environment.
Checks prerequisites and prepares the environment.

Usage:
    python setup_rag.py
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def check_command(cmd):
    """Check if a command is available."""
    return shutil.which(cmd) is not None

def run_command(cmd, check=True):
    """Run a shell command."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=True,
            text=True
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        return False, "", str(e)

def check_python_version():
    """Check Python version."""
    version = sys.version_info
    if version.major >= 3 and version.minor >= 10:
        print(f"✅ Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"❌ Python {version.major}.{version.minor}.{version.micro} (need 3.10+)")
        return False

def check_gcloud():
    """Check if gcloud is installed and authenticated."""
    if not check_command("gcloud"):
        print("❌ gcloud CLI not found")
        print("   Install from: https://cloud.google.com/sdk/docs/install")
        return False
    
    print("✅ gcloud CLI installed")
    
    # Check authentication
    success, stdout, _ = run_command("gcloud auth list --filter=status:ACTIVE --format='value(account)'")
    if success and stdout.strip():
        print(f"✅ Authenticated as: {stdout.strip()}")
        return True
    else:
        print("⚠️  Not authenticated with gcloud")
        print("   Run: gcloud auth login")
        return False

def check_gcp_project():
    """Check if GCP project is configured."""
    success, stdout, _ = run_command("gcloud config get-value project")
    if success and stdout.strip() and stdout.strip() != "unset":
        project = stdout.strip()
        print(f"✅ GCP Project: {project}")
        return True, project
    else:
        print("❌ No GCP project configured")
        print("   Run: gcloud config set project YOUR-PROJECT-ID")
        return False, None

def check_apis(project):
    """Check if required APIs are enabled."""
    apis = [
        ("aiplatform.googleapis.com", "Vertex AI"),
        ("bigquery.googleapis.com", "BigQuery")
    ]
    
    all_enabled = True
    for api, name in apis:
        success, stdout, _ = run_command(
            f"gcloud services list --enabled --filter=name:{api} --format='value(name)' --project={project}"
        )
        if success and api in stdout:
            print(f"✅ {name} API enabled")
        else:
            print(f"❌ {name} API not enabled")
            print(f"   Run: gcloud services enable {api} --project={project}")
            all_enabled = False
    
    return all_enabled

def check_bigquery_table(project):
    """Check if BigQuery table exists."""
    cmd = f"bq show {project}:medicaid_enriched.nadac_drugs_enriched"
    success, _, _ = run_command(cmd, check=False)
    
    if success:
        print("✅ BigQuery table exists")
        return True
    else:
        print("⚠️  BigQuery table not found")
        print("   Make sure data pipeline has run first")
        return False

def setup_venv():
    """Setup Python virtual environment."""
    venv_path = Path("venv")
    
    if venv_path.exists():
        print("✅ Virtual environment exists")
        return True
    
    print("Creating virtual environment...")
    success, _, stderr = run_command(f"{sys.executable} -m venv venv")
    
    if success:
        print("✅ Virtual environment created")
        return True
    else:
        print(f"❌ Failed to create virtual environment: {stderr}")
        return False

def install_requirements():
    """Install Python requirements."""
    if not Path("requirements.txt").exists():
        print("❌ requirements.txt not found")
        return False
    
    print("Installing requirements (this may take a few minutes)...")
    
    # Determine pip command based on OS
    if sys.platform == "win32":
        pip_cmd = "venv\\Scripts\\pip.exe"
    else:
        pip_cmd = "venv/bin/pip"
    
    success, _, stderr = run_command(f"{pip_cmd} install -r requirements.txt")
    
    if success:
        print("✅ Requirements installed")
        return True
    else:
        print(f"⚠️  Some packages may have failed: {stderr}")
        return True  # Continue anyway

def create_output_dir():
    """Create output directory for vector store."""
    output_dir = Path("drug_rag_output")
    output_dir.mkdir(exist_ok=True)
    print("✅ Output directory created")
    return True

def main():
    print("="*80)
    print("Medicaid Drug RAG System - Setup")
    print("="*80)
    print()
    
    # Track overall status
    all_checks_passed = True
    
    print("Checking prerequisites...")
    print("-" * 80)
    
    # Required checks
    if not check_python_version():
        all_checks_passed = False
    
    if not check_gcloud():
        all_checks_passed = False
    
    project_ok, project = check_gcp_project()
    if not project_ok:
        all_checks_passed = False
    
    # Optional but recommended checks
    if project:
        if not check_apis(project):
            print("   (APIs can be enabled later)")
        
        if not check_bigquery_table(project):
            print("   (Table will be available after data pipeline runs)")
    
    print()
    print("-" * 80)
    
    if not all_checks_passed:
        print()
        print("❌ Some prerequisites are missing. Please fix them before continuing.")
        print()
        sys.exit(1)
    
    # Setup environment
    print()
    print("Setting up environment...")
    print("-" * 80)
    
    if not setup_venv():
        print("❌ Failed to setup virtual environment")
        sys.exit(1)
    
    if not install_requirements():
        print("⚠️  Installation had issues, but continuing...")
    
    create_output_dir()
    
    print()
    print("="*80)
    print("✅ Setup complete!")
    print("="*80)
    print()
    print("Next steps:")
    print()
    print("1. Activate virtual environment:")
    if sys.platform == "win32":
        print("   .\\venv\\Scripts\\Activate.ps1")
    else:
        print("   source venv/bin/activate")
    print()
    print("2. Start Jupyter:")
    print("   jupyter notebook drug_rag_system.ipynb")
    print()
    print("3. Follow the QUICKSTART.md guide")
    print()
    print("For deployment, see DEPLOYMENT_GUIDE.md")
    print()

if __name__ == "__main__":
    main()
