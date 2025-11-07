# Helper script for common dashboard operations

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("status", "logs", "restart", "scale", "url", "delete", "help")]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [int]$Replicas = 2
)

$ErrorActionPreference = "Stop"

$ProjectId = "gcp-project-deliverable"
$ClusterName = "medicaid-dashboard-cluster"
$Region = "us-central1"
$Namespace = "default"

function Show-Help {
    Write-Host "`n=== Dashboard Management Helper ===" -ForegroundColor Cyan
    Write-Host "`nUsage: .\manage-dashboard.ps1 -Action <action> [-Replicas <number>]" -ForegroundColor White
    Write-Host "`nActions:" -ForegroundColor Yellow
    Write-Host "  status    - Show deployment and pod status"
    Write-Host "  logs      - Show real-time logs"
    Write-Host "  restart   - Restart the deployment (pulls latest image)"
    Write-Host "  scale     - Scale replicas (use -Replicas parameter)"
    Write-Host "  url       - Get dashboard URL"
    Write-Host "  delete    - Delete deployment and service (keeps cluster)"
    Write-Host "  help      - Show this help message"
    
    Write-Host "`nExamples:" -ForegroundColor Yellow
    Write-Host "  .\manage-dashboard.ps1 -Action status"
    Write-Host "  .\manage-dashboard.ps1 -Action logs"
    Write-Host "  .\manage-dashboard.ps1 -Action restart"
    Write-Host "  .\manage-dashboard.ps1 -Action scale -Replicas 3"
    Write-Host "  .\manage-dashboard.ps1 -Action url"
    Write-Host ""
}

function Get-Status {
    Write-Host "`n=== Dashboard Status ===" -ForegroundColor Cyan
    
    Write-Host "`n[Deployment]" -ForegroundColor Yellow
    kubectl get deployment medicaid-dashboard -n $Namespace
    
    Write-Host "`n[Pods]" -ForegroundColor Yellow
    kubectl get pods -l app=medicaid-dashboard -n $Namespace
    
    Write-Host "`n[Service]" -ForegroundColor Yellow
    kubectl get service medicaid-dashboard-service -n $Namespace
    
    Write-Host "`n[Recent Events]" -ForegroundColor Yellow
    kubectl get events -n $Namespace --sort-by='.lastTimestamp' | Select-Object -Last 5
}

function Get-Logs {
    Write-Host "`n=== Dashboard Logs (real-time) ===" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""
    kubectl logs -f -l app=medicaid-dashboard -n $Namespace
}

function Restart-Dashboard {
    Write-Host "`n=== Restarting Dashboard ===" -ForegroundColor Cyan
    kubectl rollout restart deployment/medicaid-dashboard -n $Namespace
    
    Write-Host "`nWaiting for rollout to complete..." -ForegroundColor Yellow
    kubectl rollout status deployment/medicaid-dashboard -n $Namespace --timeout=5m
    
    Write-Host "`n✓ Dashboard restarted successfully" -ForegroundColor Green
}

function Scale-Dashboard {
    Write-Host "`n=== Scaling Dashboard ===" -ForegroundColor Cyan
    Write-Host "Scaling to $Replicas replicas..." -ForegroundColor Yellow
    
    kubectl scale deployment/medicaid-dashboard -n $Namespace --replicas=$Replicas
    
    Write-Host "`nWaiting for scale to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    kubectl get pods -l app=medicaid-dashboard -n $Namespace
    
    Write-Host "`n✓ Scaled to $Replicas replicas" -ForegroundColor Green
}

function Get-Url {
    Write-Host "`n=== Dashboard URL ===" -ForegroundColor Cyan
    
    $serviceInfo = kubectl get service medicaid-dashboard-service -n $Namespace -o json | ConvertFrom-Json
    $externalIp = $serviceInfo.status.loadBalancer.ingress[0].ip
    
    if ($externalIp) {
        Write-Host "`n✓ Dashboard URL: http://$externalIp`:8501" -ForegroundColor Green
        Write-Host "`nYou can also access it via:" -ForegroundColor Yellow
        Write-Host "  gcloud container clusters get-credentials $ClusterName --region=$Region" -ForegroundColor White
        Write-Host "  kubectl port-forward service/medicaid-dashboard-service 8501:8501" -ForegroundColor White
        Write-Host "  Then visit: http://localhost:8501" -ForegroundColor White
    } else {
        Write-Host "`n⚠ External IP not yet assigned" -ForegroundColor Yellow
        Write-Host "Waiting for LoadBalancer... (this can take 2-5 minutes)" -ForegroundColor Gray
        
        $attempts = 0
        while ($attempts -lt 12) {
            Start-Sleep -Seconds 10
            $serviceInfo = kubectl get service medicaid-dashboard-service -n $Namespace -o json | ConvertFrom-Json
            $externalIp = $serviceInfo.status.loadBalancer.ingress[0].ip
            
            if ($externalIp) {
                Write-Host "`n✓ Dashboard URL: http://$externalIp`:8501" -ForegroundColor Green
                return
            }
            
            $attempts++
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
        
        Write-Host "`n⚠ External IP still pending. Check manually with:" -ForegroundColor Yellow
        Write-Host "  kubectl get service medicaid-dashboard-service" -ForegroundColor White
    }
}

function Remove-Dashboard {
    Write-Host "`n=== Delete Dashboard ===" -ForegroundColor Cyan
    Write-Host "⚠ This will delete the deployment and service, but keep the cluster" -ForegroundColor Yellow
    
    $confirm = Read-Host "Are you sure? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled." -ForegroundColor Gray
        return
    }
    
    Write-Host "`nDeleting deployment..." -ForegroundColor Yellow
    kubectl delete deployment medicaid-dashboard -n $Namespace
    
    Write-Host "Deleting service..." -ForegroundColor Yellow
    kubectl delete service medicaid-dashboard-service -n $Namespace
    
    Write-Host "`n✓ Dashboard deleted" -ForegroundColor Green
    Write-Host "`nTo delete the entire cluster, run:" -ForegroundColor Yellow
    Write-Host "  gcloud container clusters delete $ClusterName --region=$Region" -ForegroundColor White
}

# Main execution
try {
    # Ensure kubectl is configured
    $currentContext = kubectl config current-context 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ kubectl not configured. Run:" -ForegroundColor Yellow
        Write-Host "  gcloud container clusters get-credentials $ClusterName --region=$Region" -ForegroundColor White
        exit 1
    }
    
    switch ($Action) {
        "status"  { Get-Status }
        "logs"    { Get-Logs }
        "restart" { Restart-Dashboard }
        "scale"   { Scale-Dashboard }
        "url"     { Get-Url }
        "delete"  { Remove-Dashboard }
        "help"    { Show-Help }
        default   { Show-Help }
    }
} catch {
    Write-Host "`n✗ Error: $_" -ForegroundColor Red
    exit 1
}
