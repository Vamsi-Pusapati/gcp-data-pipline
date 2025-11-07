# Simple script to build Docker image using Cloud Build (no local Docker needed)

param(
    [string]$ProjectId = "gcp-project-deliverable",
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Building Docker Image with Cloud Build ===" -ForegroundColor Cyan

# Set project
Write-Host "Setting project: $ProjectId" -ForegroundColor Yellow
gcloud config set project $ProjectId

# Enable APIs if needed
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable containerregistry.googleapis.com --quiet

# Navigate to project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

try {
    Write-Host "`nBuilding image remotely on GCP..." -ForegroundColor Yellow
    Write-Host "This will take a few minutes..." -ForegroundColor Gray
    
    gcloud builds submit `
        --config=cloudbuild.yaml `
        --substitutions=TAG_NAME=$ImageTag `
        --timeout=20m
    
    Write-Host "`n=== Build Complete ===" -ForegroundColor Green
    Write-Host "Image: gcr.io/$ProjectId/medicaid-dashboard:$ImageTag" -ForegroundColor White
    
} catch {
    Write-Host "`nBuild failed: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
