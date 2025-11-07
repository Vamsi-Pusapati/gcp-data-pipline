# Pre-deployment verification script

param(
    [string]$ProjectId = "gcp-project-deliverable"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Pre-Deployment Verification ===" -ForegroundColor Cyan

$allChecks = $true

# Check 1: gcloud installed
Write-Host "`n[1/8] Checking gcloud installation..." -ForegroundColor Yellow
try {
    $gcloudVersion = gcloud version --format="value(core)" 2>&1
    Write-Host "  ✓ gcloud installed (version: $gcloudVersion)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ gcloud not found. Install from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Red
    $allChecks = $false
}

# Check 2: kubectl installed
Write-Host "`n[2/8] Checking kubectl installation..." -ForegroundColor Yellow
try {
    $kubectlVersion = kubectl version --client --short 2>&1 | Select-String "Client Version"
    Write-Host "  ✓ kubectl installed" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ kubectl not found. Install with: gcloud components install kubectl" -ForegroundColor Yellow
    Write-Host "  (Will be needed after cluster creation)" -ForegroundColor Gray
}

# Check 3: Authenticated with GCP
Write-Host "`n[3/8] Checking GCP authentication..." -ForegroundColor Yellow
try {
    $account = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1 | Select-Object -First 1
    if ($account) {
        Write-Host "  ✓ Authenticated as: $account" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Not authenticated. Run: gcloud auth login" -ForegroundColor Red
        $allChecks = $false
    }
} catch {
    Write-Host "  ✗ Authentication check failed. Run: gcloud auth login" -ForegroundColor Red
    $allChecks = $false
}

# Check 4: Project set
Write-Host "`n[4/8] Checking GCP project..." -ForegroundColor Yellow
try {
    $currentProject = gcloud config get-value project 2>&1
    if ($currentProject -eq $ProjectId) {
        Write-Host "  ✓ Project set to: $ProjectId" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Current project: $currentProject (expected: $ProjectId)" -ForegroundColor Yellow
        Write-Host "  Run: gcloud config set project $ProjectId" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠ Could not verify project" -ForegroundColor Yellow
}

# Check 5: Required files exist
Write-Host "`n[5/8] Checking required files..." -ForegroundColor Yellow
$requiredFiles = @(
    "app.py",
    "requirements.txt",
    "Dockerfile",
    ".dockerignore",
    "k8s\deployment.yaml",
    "k8s\service.yaml",
    "..\cloudbuild.yaml"
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $PSScriptRoot $file
    if (Test-Path $path) {
        Write-Host "  ✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file missing" -ForegroundColor Red
        $allChecks = $false
    }
}

# Check 6: Service account exists
Write-Host "`n[6/8] Checking service account..." -ForegroundColor Yellow
try {
    $saEmail = "data-pipeline-sa@$ProjectId.iam.gserviceaccount.com"
    gcloud iam service-accounts describe $saEmail --project=$ProjectId 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Service account exists: $saEmail" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Service account not found: $saEmail" -ForegroundColor Red
        Write-Host "  Create with: gcloud iam service-accounts create data-pipeline-sa" -ForegroundColor Gray
        $allChecks = $false
    }
} catch {
    Write-Host "  ⚠ Could not verify service account" -ForegroundColor Yellow
}

# Check 7: Required APIs
Write-Host "`n[7/8] Checking required APIs..." -ForegroundColor Yellow
$requiredApis = @(
    "cloudbuild.googleapis.com",
    "containerregistry.googleapis.com",
    "container.googleapis.com",
    "bigquery.googleapis.com"
)

foreach ($api in $requiredApis) {
    try {
        $enabled = gcloud services list --enabled --filter="name:$api" --format="value(name)" --project=$ProjectId 2>&1
        if ($enabled) {
            Write-Host "  ✓ $api enabled" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ $api not enabled (will be enabled during deployment)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠ Could not check $api" -ForegroundColor Yellow
    }
}

# Check 8: BigQuery dataset exists
Write-Host "`n[8/8] Checking BigQuery dataset..." -ForegroundColor Yellow
try {
    $dataset = bq show --project_id=$ProjectId medicaid_data 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Dataset 'medicaid_data' exists" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Dataset 'medicaid_data' not found" -ForegroundColor Yellow
        Write-Host "  (Dashboard may not have data to display)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠ Could not verify BigQuery dataset" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan

if ($allChecks) {
    Write-Host "✓ All critical checks passed! Ready to deploy." -ForegroundColor Green
    Write-Host "`nTo deploy, run:" -ForegroundColor Cyan
    Write-Host "  .\deploy-gke.ps1" -ForegroundColor White
    Write-Host "`nOr to just build the image:" -ForegroundColor Cyan
    Write-Host "  .\build-image.ps1" -ForegroundColor White
} else {
    Write-Host "✗ Some critical checks failed. Please fix the issues above." -ForegroundColor Red
    Write-Host "`nCommon fixes:" -ForegroundColor Yellow
    Write-Host "  gcloud auth login" -ForegroundColor White
    Write-Host "  gcloud config set project $ProjectId" -ForegroundColor White
    Write-Host "  gcloud components install kubectl" -ForegroundColor White
}

Write-Host "`nFor detailed deployment guide, see: DEPLOYMENT.md" -ForegroundColor Gray
