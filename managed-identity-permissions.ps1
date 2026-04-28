# Run this script only once to give the azure automation managed identity the required graph permissions

# 1. Define Automation Account Name
$ManagedIdentityName = "AUTOMATION-ACCOUNT-NAME" 

# The static, well-known App ID for Microsoft Graph globally
$GraphAppId = "00000003-0000-0000-c000-000000000000" 

# The specific permissions our offboarding script requires
$Permissions = @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory"
)

Write-Host "Connecting to Entra ID to assign permissions..." -ForegroundColor Cyan
# This requires high-level scopes to assign roles to other applications
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"

# 2. Find the Service Principal for Managed Identity
$MI_SP = Get-MgServicePrincipal -Filter "DisplayName eq '$ManagedIdentityName'"

if (-not $MI_SP) {
    Write-Host "ERROR: Could not find a Managed Identity named '$ManagedIdentityName'. Check the name and try again." -ForegroundColor Red
    break
}

# 3. Find the Service Principal for Microsoft Graph
$Graph_SP = Get-MgServicePrincipal -Filter "AppId eq '$GraphAppId'"

# 4. Loop through and assign each permission
Write-Host "Applying permissions to $($MI_SP.DisplayName)..." -ForegroundColor Yellow

foreach ($Role in $Permissions) {
    # Find the specific role ID inside the Graph application
    $AppRole = $Graph_SP.AppRoles | Where-Object { $_.Value -eq $Role }
    
    if ($AppRole) {
        try {
            New-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $MI_SP.Id `
                -PrincipalId $MI_SP.Id `
                -ResourceId $Graph_SP.Id `
                -AppRoleId $AppRole.Id | Out-Null
                
            Write-Host "SUCCESS: Assigned $($Role)" -ForegroundColor Green
        } catch {
            Write-Host "SKIP: $($Role) might already be assigned or an error occurred." -ForegroundColor Gray
        }
    }
}

Write-Host "Permission assignment complete. Disconnecting..." -ForegroundColor Cyan
Disconnect-MgGraph
