# 1. The Logic App Webhook URL
$WebhookUri = "LOGIC-APP-TRIGGER-URL"

# 2. The HR Termination Data (JSON Payload)
$Payload = @{
    TargetUPN = "TARGET-UPN@abc.onmicrosoft.com"    # Values changed for security purposes
    ManagerUPN = "MANAGER-UPN@abc.onmicrosoft.com"   # Values changed for security purposes
    RetentionDays = 30
    ForwardEmail = $false
    ForwardToUPN = "MANAGER-UPN@abc.onmicrosoft.com"  # Values changed for security purposes
    DryRun = $false
} | ConvertTo-Json

Write-Host "Initiating Automated Offboarding Sequence..." -ForegroundColor Cyan
Write-Host "Transmitting payload to Azure Logic Apps..." -ForegroundColor Yellow

# 3. Fire the Webhook
try {
    Invoke-RestMethod -Uri $WebhookUri -Method Post -Body $Payload -ContentType "application/json"
    Write-Host "SUCCESS: Signal received by Logic App! The automation is running." -ForegroundColor Green
} catch {
    Write-Host "FAILED: Could not reach the Logic App. Check the URL." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Gray
}
