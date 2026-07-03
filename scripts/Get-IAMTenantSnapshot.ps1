param(
    [string]$OutputPath = './reports/tenant-redacted',
    [switch]$Redact
)

. "$PSScriptRoot/ConvertTo-RedactedIAMData.ps1"
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# NOTE: this script has not been execution-tested against a live tenant in the
# environment that built this kit (no PowerShell / Microsoft.Graph module
# available there). Cmdlet names and property names below are verified against
# Microsoft's published Graph PowerShell SDK documentation as of this writing,
# but run this against a test tenant before relying on it for a customer
# assessment. Two spots are flagged inline below as things to specifically
# verify: (1) whether your SDK version returns PasswordCredentials /
# KeyCredentials on Get-MgServicePrincipal without extra handling -- some
# versions have shipped with a bug returning these empty even when selected --
# and (2) whether your tenant has Entra ID P2 / Governance licensing, which
# determines whether the PIM-eligible-assignments call succeeds or the script
# falls back to plain role assignments only.

Write-Host 'Collecting users...' -ForegroundColor Cyan
$users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,UserType,CreatedDateTime,SignInActivity |
    Select-Object Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,UserType,CreatedDateTime,@{n='LastSignInDateTime';e={$_.SignInActivity.LastSignInDateTime}}

Write-Host 'Collecting groups...' -ForegroundColor Cyan
$groups = Get-MgGroup -All -Property Id,DisplayName,SecurityEnabled,MailEnabled,GroupTypes,CreatedDateTime |
    Select-Object Id,DisplayName,SecurityEnabled,MailEnabled,GroupTypes,CreatedDateTime

Write-Host 'Collecting applications and service principals...' -ForegroundColor Cyan
$apps = Get-MgServicePrincipal -All -Property Id,AppId,DisplayName,AccountEnabled,ServicePrincipalType,AppOwnerOrganizationId,Tags |
    Select-Object Id,AppId,DisplayName,AccountEnabled,ServicePrincipalType,AppOwnerOrganizationId,Tags

Write-Host 'Collecting Conditional Access policies if available...' -ForegroundColor Cyan
try {
    $ca = Get-MgIdentityConditionalAccessPolicy -All | Select-Object Id,DisplayName,State,CreatedDateTime,ModifiedDateTime
} catch {
    $ca = @([pscustomobject]@{ Id='not-collected'; DisplayName='Conditional Access collection failed or permission missing'; State='unknown'; CreatedDateTime=$null; ModifiedDateTime=$null })
}

Write-Host 'Collecting service principal credentials (service account candidates)...' -ForegroundColor Cyan
# VERIFY: some Microsoft.Graph SDK versions have returned empty PasswordCredentials
# / KeyCredentials collections even when explicitly selected (a known SDK
# issue, not a permissions problem). If CredentialCount comes back 0 across
# the board, confirm directly against a known service principal with secrets
# before concluding the tenant has no service account credential risk.
$servicePrincipalsWithCreds = Get-MgServicePrincipal -All -Property Id,AppId,DisplayName,AccountEnabled,ServicePrincipalType,Notes,PasswordCredentials,KeyCredentials

$serviceAccounts = foreach ($sp in $servicePrincipalsWithCreds) {
    $allCreds = @()
    if ($sp.PasswordCredentials) { $allCreds += $sp.PasswordCredentials }
    if ($sp.KeyCredentials) { $allCreds += $sp.KeyCredentials }

    $owner = 'Unknown'
    try {
        $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $sp.Id -ErrorAction Stop
        if ($owners -and $owners.Count -gt 0) {
            $first = $owners | Select-Object -First 1
            $owner = if ($first.AdditionalProperties.userPrincipalName) { $first.AdditionalProperties.userPrincipalName } else { $first.Id }
        }
    } catch {
        $owner = 'Unknown'
    }

    $credentialAgeDays = $null
    $notes = ''
    if ($allCreds.Count -gt 0) {
        $withStart = $allCreds | Where-Object { $_.StartDateTime }
        if ($withStart) {
            $latestStart = ($withStart | Sort-Object StartDateTime -Descending | Select-Object -First 1).StartDateTime
            $credentialAgeDays = [int]((Get-Date).ToUniversalTime() - [datetime]$latestStart).TotalDays
        }
    } else {
        $notes = 'No credentials returned by Graph for this service principal. Confirm directly in Entra ID before treating as credential-free.'
    }

    [pscustomobject]@{
        Id                    = $sp.Id
        DisplayName           = $sp.DisplayName
        Owner                 = $owner
        Purpose                = $sp.Notes
        AccountEnabled        = $sp.AccountEnabled
        ServicePrincipalType  = $sp.ServicePrincipalType
        CredentialCount       = $allCreds.Count
        CredentialAgeDays     = $credentialAgeDays
        Notes                 = $notes
    }
}

Write-Host 'Collecting privileged role assignments...' -ForegroundColor Cyan
$permanentAssignments = @()
try {
    # PIM-enabled tenants: active assignment schedule (requires Microsoft.Graph.Identity.Governance module)
    $permanentAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -All -ExpandProperty RoleDefinition,Principal -ErrorAction Stop
} catch {
    try {
        # Tenants without PIM: plain directory role assignments
        $permanentAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty RoleDefinition,Principal -ErrorAction Stop
    } catch {
        Write-Host 'Could not collect role assignments. Check RoleManagement.Read.Directory permission.' -ForegroundColor Yellow
    }
}

$eligibleAssignments = @()
try {
    # Requires Microsoft Entra ID P2 / Governance licensing. Expected to fail on tenants without it.
    $eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty RoleDefinition,Principal -ErrorAction Stop
} catch {
    Write-Host 'Could not collect PIM-eligible assignments (requires Entra ID P2 / Governance license). Permanent assignments were still collected.' -ForegroundColor Yellow
}

function Get-PrincipalLabel($principal, $fallbackId) {
    if (-not $principal) { return $fallbackId }
    if ($principal.AdditionalProperties.userPrincipalName) { return $principal.AdditionalProperties.userPrincipalName }
    if ($principal.AdditionalProperties.displayName) { return $principal.AdditionalProperties.displayName }
    return $fallbackId
}

$privilegedRoles = @()
$privilegedRoles += foreach ($a in $permanentAssignments) {
    [pscustomobject]@{
        Id             = $a.Id
        Principal      = Get-PrincipalLabel $a.Principal $a.PrincipalId
        Role           = $a.RoleDefinition.DisplayName
        AssignmentType = 'Permanent'
        Eligible       = $false
        LastReviewed   = ''
    }
}
$privilegedRoles += foreach ($a in $eligibleAssignments) {
    [pscustomobject]@{
        Id             = $a.Id
        Principal      = Get-PrincipalLabel $a.Principal $a.PrincipalId
        Role           = $a.RoleDefinition.DisplayName
        AssignmentType = 'Eligible'
        Eligible       = $true
        LastReviewed   = ''
    }
}

if ($Redact) {
    $users            = $users            | ConvertTo-RedactedObject -PseudonymPrefix 'User'
    $groups           = $groups           | ConvertTo-RedactedObject -PseudonymPrefix 'Group'
    $apps             = $apps             | ConvertTo-RedactedObject -PseudonymPrefix 'Application'
    $ca               = $ca               | ConvertTo-RedactedObject -PseudonymPrefix 'Policy'
    $serviceAccounts  = $serviceAccounts  | ConvertTo-RedactedObject -PseudonymPrefix 'Service Account'
    $privilegedRoles  = $privilegedRoles  | ConvertTo-RedactedObject -PseudonymPrefix 'Role Assignment' -DisplayNameFields @('Principal')
}

$users           | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-users.redacted.csv')
$groups          | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-groups.redacted.csv')
$apps            | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-applications.redacted.csv')
$ca              | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-conditional-access.redacted.csv')
$serviceAccounts | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-service-accounts.redacted.csv')
$privilegedRoles | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'tenant-privileged-roles.redacted.csv')

Write-Host "Tenant snapshot exported to $OutputPath" -ForegroundColor Green
Write-Host 'Review all files manually before sharing or committing.' -ForegroundColor Yellow
