<#
.SYNOPSIS
    Automated Microsoft 365 Pure-Cloud User Offboarding Script

.DESCRIPTION
    Disables user access, revokes sessions, handles mailbox conversions, configures 
    auto-replies, removes group memberships, and strips licenses using modern MS Graph.

.NOTES
    Author: Argin Aslanian - User Automated Offboarding
    Architecture: Microsoft Graph API & Exchange Online V3
#>

#region ===== PARAMETERS =====
param (
    [Parameter(Mandatory=$true)] [string]$UserUPN,
    [Parameter(Mandatory=$false)] [string]$ManagerUPN,
    [Parameter(Mandatory=$false)] [int]$RetentionDays = 30,
    [Parameter(Mandatory=$false)] [string]$ForwardEmail = "false",
    [Parameter(Mandatory=$false)] [string]$ForwardToUPN,
    [Parameter(Mandatory=$false)] [string]$DryRun = "false"
)

# Cloud Logic App Hack: Convert incoming strings back to native booleans
$IsDryRun = ($DryRun -eq "true" -or $DryRun -eq "True" -or $DryRun -eq "1")
$IsForward = ($ForwardEmail -eq "true" -or $ForwardEmail -eq "True" -or $ForwardEmail -eq "1")
#endregion

#region ===== LOGGING SETUP =====
function Write-Log {
    param ([string]$Message)
    # Changed from Write-Host to Write-Output so Azure guarantees it shows up in the logs
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') :: $Message"
}
#endregion

try {
    Write-Log "Initializing connection to Microsoft Graph and Exchange Online via Managed Identity..."
    Connect-MgGraph -Identity -NoWelcome | Out-Null
    
    Connect-ExchangeOnline -ManagedIdentity -Organization "abc.onmicrosoft.com" -ErrorAction Stop    # domain changed for security purposes

    Write-Log "Locating user identity in Entra ID..."
    $MgUser = Get-MgUser -UserId $UserUPN -Property "Id, DisplayName, UserPrincipalName, AssignedLicenses" -ErrorAction Stop
    Write-Log "Target acquired: $($MgUser.DisplayName) ($($MgUser.Id))"

    Write-Log "Phase 1: Disabling account and revoking refresh tokens..."
    if (-not $IsDryRun) {
        Update-MgUser -UserId $MgUser.Id -AccountEnabled:$false
        Revoke-MgUserSignInSession -UserId $MgUser.Id | Out-Null
        Write-Log "-> Account disabled and sessions revoked."
    } else { Write-Log "[DRY RUN] Would disable account and revoke sessions." }

    Write-Log "Phase 2: Processing Exchange Online mailbox..."
    if (-not $IsDryRun) {
        Set-Mailbox -Identity $UserUPN -HiddenFromAddressListsEnabled $true -Type Shared
        Write-Log "-> Mailbox hidden from GAL and converted to Shared."

        $AutoReplyInternal = "<html><body>This user is no longer with the company.</body></html>"
        $AutoReplyExternal = "<html><body>This email address is no longer monitored.</body></html>"
        Set-MailboxAutoReplyConfiguration -Identity $UserUPN -AutoReplyState Enabled -InternalMessage $AutoReplyInternal -ExternalMessage $AutoReplyExternal
        Write-Log "-> Auto-reply configured."

        if ($IsForward -and $ForwardToUPN) {
            Set-Mailbox -Identity $UserUPN -ForwardingAddress $ForwardToUPN -DeliverToMailboxAndForward $false
            Write-Log "-> Mail forwarding configured to $ForwardToUPN."
        }

        if ($ManagerUPN) {
            Add-MailboxPermission -Identity $UserUPN -User $ManagerUPN -AccessRights FullAccess -InheritanceType All -AutoMapping $true | Out-Null
            Write-Log "-> Full mailbox access granted to Manager: $ManagerUPN."
        }
    } else { Write-Log "[DRY RUN] Would convert mailbox, set auto-reply, and delegate access." }

    Write-Log "Phase 3: Stripping Group Memberships and Admin Roles..."
    $Memberships = Get-MgUserMemberOf -UserId $MgUser.Id
    foreach ($Group in $Memberships) {
        if ($Group.AdditionalProperties["@odata.type"] -match "group") {
            if (-not $IsDryRun) {
                Remove-MgGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $MgUser.Id
                Write-Log "-> Removed from Group ID: $($Group.Id)"
            } else { Write-Log "[DRY RUN] Would remove from group: $($Group.Id)" }
        }
        elseif ($Group.AdditionalProperties["@odata.type"] -match "directoryRole") {
            if (-not $IsDryRun) {
                Remove-MgDirectoryRoleMemberByRef -DirectoryRoleId $Group.Id -DirectoryObjectId $MgUser.Id
                Write-Log "-> Stripped Admin Role ID: $($Group.Id)"
            } else { Write-Log "[DRY RUN] Would strip admin role: $($Group.Id)" }
        }
    }

    Write-Log "Phase 4: Reclaiming Microsoft 365 Licenses..."
    if ($MgUser.AssignedLicenses.Count -gt 0) {
        $SkuIdsToRemove = $MgUser.AssignedLicenses.SkuId
        if (-not $IsDryRun) {
            Set-MgUserLicense -UserId $MgUser.Id -RemoveLicenses $SkuIdsToRemove -AddLicenses @{} | Out-Null
            Write-Log "-> All licenses successfully stripped."
        } else { Write-Log "[DRY RUN] Would remove $($SkuIdsToRemove.Count) licenses." }
    } else { Write-Log "-> No licenses found on the account." }

    Write-Log "========================================"
    Write-Log "OFFBOARDING COMPLETE for $UserUPN."
    if ($IsDryRun) { Write-Log "!!! THIS WAS A DRY RUN. NO CHANGES WERE MADE. !!!" }
    Write-Log "========================================"

} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)"
} finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
}
