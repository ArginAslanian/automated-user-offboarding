Write-Host "Connecting to Entra ID..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"

# 1. Get Automation Account's Identity
$MI_Name = "AUTOMATION-ACCOUNT-NAME"
$MI = Get-MgServicePrincipal -Filter "DisplayName eq '$MI_Name'"

if (-not $MI) {
    Write-Host "ERROR: Could not find Managed Identity." -ForegroundColor Red
    break
}

# 2. Get the static, global Exchange Online internal application ID
$EXO_AppId = "00000002-0000-0ff1-ce00-000000000000"
$EXO_SP = Get-MgServicePrincipal -Filter "AppId eq '$EXO_AppId'"

# 3. Isolate the specific "Exchange.ManageAsApp" permission role
$AppRole = $EXO_SP.AppRoles | Where-Object { $_.Value -eq "Exchange.ManageAsApp" }

# 4. Inject the permission into your Managed Identity
Write-Host "Injecting Exchange.ManageAsApp permission..." -ForegroundColor Yellow

if ($MI -and $AppRole) {
    try {
        New-MgServicePrincipalAppRoleAssignment `
            -PrincipalId $MI.Id `
            -ServicePrincipalId $MI.Id `
            -ResourceId $EXO_SP.Id `
            -AppRoleId $AppRole.Id | Out-Null
            
        Write-Host "SUCCESS: Exchange Permission injected!" -ForegroundColor Green
    } catch {
        Write-Host "SKIP: Permission is already injected, or an error occurred." -ForegroundColor Gray
        Write-Host $_.Exception.Message -ForegroundColor Gray
    }
}

Write-Host "Disconnecting..." -ForegroundColor Cyan
Disconnect-MgGraph
