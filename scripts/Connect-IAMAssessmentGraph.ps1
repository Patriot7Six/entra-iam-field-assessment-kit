# Connect-IAMAssessmentGraph.ps1
# Read-oriented Microsoft Graph connection helper.
# Run only in a tenant you are authorized to assess.

$Scopes = @(
    'User.Read.All',
    'Group.Read.All',
    'Application.Read.All',
    'Directory.Read.All',
    'AuditLog.Read.All',
    'Policy.Read.All',
    'RoleManagement.Read.Directory'
)

Write-Host 'Connecting to Microsoft Graph with read-oriented scopes...' -ForegroundColor Cyan
Connect-MgGraph -Scopes $Scopes
Get-MgContext | Select-Object TenantId, Account, Scopes

Write-Host ''
Write-Host 'Safety note: do not commit tenant IDs, account names, domains, object IDs, app IDs, exports, or raw Graph output to GitHub.' -ForegroundColor Yellow
