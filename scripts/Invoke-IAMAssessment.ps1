param(
    [ValidateSet('Demo','Tenant')][string]$Mode = 'Demo',
    [string]$DemoPath = './demo',
    [string]$OutputPath = './reports/generated',
    [switch]$Redact
)

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
function Import-CsvSafe($Path) { if (Test-Path $Path) { return Import-Csv $Path } return @() }

if ($Mode -eq 'Tenant') {
    Write-Host 'Tenant mode selected. Collecting redacted snapshot first...' -ForegroundColor Cyan
    & "$PSScriptRoot/Get-IAMTenantSnapshot.ps1" -OutputPath $OutputPath -Redact:$Redact
    $Users = Import-CsvSafe (Join-Path $OutputPath 'tenant-users.redacted.csv')
    $Apps = Import-CsvSafe (Join-Path $OutputPath 'tenant-applications.redacted.csv')
    $ServiceAccounts = Import-CsvSafe (Join-Path $OutputPath 'tenant-service-accounts.redacted.csv')
    $PrivilegedRoles = Import-CsvSafe (Join-Path $OutputPath 'tenant-privileged-roles.redacted.csv')
    # Access reviews (Get-MgIdentityGovernanceAccessReviewDefinition, requires
    # Entra ID Governance licensing) are not collected by this kit yet. Left
    # empty in Tenant mode rather than guessed at -- see README known limitations.
    $AccessReviews = @()
    $CAPolicies = Import-CsvSafe (Join-Path $OutputPath 'tenant-conditional-access.redacted.csv')
} else {
    $Users = Import-CsvSafe (Join-Path $DemoPath 'users.csv')
    $Apps = Import-CsvSafe (Join-Path $DemoPath 'applications.csv')
    $ServiceAccounts = Import-CsvSafe (Join-Path $DemoPath 'service-accounts.csv')
    $PrivilegedRoles = Import-CsvSafe (Join-Path $DemoPath 'privileged-roles.csv')
    $CAPolicies = Get-Content (Join-Path $DemoPath 'conditional-access-policies.json') -Raw | ConvertFrom-Json
    $AccessReviews = Get-Content (Join-Path $DemoPath 'access-reviews.json') -Raw | ConvertFrom-Json
}

$Findings = New-Object System.Collections.Generic.List[object]
$Evidence = New-Object System.Collections.Generic.List[object]
function Add-Finding($Severity,$Area,$Title,$Detail,$Recommendation) { $script:Findings.Add([pscustomobject]@{Severity=$Severity;Area=$Area;Title=$Title;Detail=$Detail;Recommendation=$Recommendation}) | Out-Null }
function Add-Evidence($Area,$Object,$Result,$Notes) { $script:Evidence.Add([pscustomobject]@{Timestamp=(Get-Date).ToUniversalTime().ToString('s')+'Z';Area=$Area;Object=$Object;Result=$Result;Notes=$Notes}) | Out-Null }

foreach ($u in @($Users | Where-Object { $_.mfaCapable -eq 'false' -and $_.accountEnabled -eq 'true' })) {
    Add-Finding 'High' 'Authentication' 'Enabled user lacks MFA-ready flag' "$($u.displayName) appears enabled but not MFA-ready in source data." 'Require MFA registration or confirm compensating control.'
    Add-Evidence 'Authentication' $u.displayName 'Finding' 'MFA-ready field was false while account was enabled.'
}
foreach ($u in @($Users | Where-Object { $_.terminationDate -and $_.accountEnabled -eq 'true' })) {
    Add-Finding 'Critical' 'Lifecycle' 'Terminated or expired worker still enabled' "$($u.displayName) has a termination date but account is enabled." 'Disable account, remove group access, revoke sessions, and document offboarding evidence.'
    Add-Evidence 'Lifecycle' $u.displayName 'Finding' 'Termination date present while account enabled.'
}
foreach ($a in $Apps) {
    if ($a.ssoEnabled -eq 'false') { Add-Finding 'High' 'SSO' 'Application lacks SSO' "$($a.displayName) is not SSO-enabled." 'Move app to Entra enterprise app SSO where supported or document exception.' }
    if ($a.mfaRequired -eq 'false' -and $a.criticality -in @('Critical','High','Moderate')) { Add-Finding 'High' 'Authentication' 'Application lacks MFA requirement' "$($a.displayName) does not require MFA in the source data." 'Enforce MFA through Conditional Access or app control.' }
    if ($a.averageEnablementHours -and $a.criticality -eq 'Critical') {
        $hours = [double]$a.averageEnablementHours
        $minutes = [math]::Round($hours * 60, 1)
        if ($hours -gt 1) {
            Add-Finding 'Moderate' 'MTTE' 'Critical app enablement exceeds one-hour ceiling' "$($a.displayName) average enablement is $hours hours, above the one-hour MTTE ceiling." 'Map role-to-group or access-package path to target under one hour.'
        } elseif ($hours -gt (5/60)) {
            Add-Finding 'Low' 'MTTE' 'Critical app enablement above five-minute stretch goal' "$($a.displayName) average enablement is $minutes minutes -- inside the one-hour ceiling but above the five-minute stretch goal for critical systems." 'Evaluate access-package auto-assignment or pre-approved group membership to close the gap to five minutes.'
        }
    }
    Add-Evidence 'Application Review' $a.displayName 'Reviewed' "Criticality=$($a.criticality); SSO=$($a.ssoEnabled); MFA=$($a.mfaRequired); MTTEHours=$($a.averageEnablementHours)"
}
foreach ($s in $ServiceAccounts) {
    if ($s.owner -eq 'Unknown' -or [string]::IsNullOrWhiteSpace($s.owner)) { Add-Finding 'Critical' 'Service Accounts' 'Service account has no owner' "$($s.displayName) has no named owner." 'Assign accountable owner or retire account.' }
    $ageDays = 0
    if (-not [string]::IsNullOrWhiteSpace($s.credentialAgeDays) -and [int]::TryParse($s.credentialAgeDays, [ref]$ageDays) -and $ageDays -gt 365) {
        Add-Finding 'High' 'Service Accounts' 'Service account credential age exceeds one year' "$($s.displayName) credential age is $ageDays days." 'Rotate credential or replace with managed identity / certificate-based auth where practical.'
    }
    Add-Evidence 'Service Account Review' $s.displayName 'Reviewed' "Owner=$($s.owner); CredentialAgeDays=$($s.credentialAgeDays)"
}
foreach ($p in $PrivilegedRoles) {
    if ($p.assignmentType -eq 'Permanent' -or $p.eligible -eq 'false') { Add-Finding 'High' 'Privileged Access' 'Permanent privileged role assignment' "$($p.principal) has $($p.role) as $($p.assignmentType)." 'Move to eligible/JIT assignment where supported and require periodic review.' }
    Add-Evidence 'Privileged Access' $p.principal 'Reviewed' "Role=$($p.role); Assignment=$($p.assignmentType); LastReviewed=$($p.lastReviewed)"
}
foreach ($r in $AccessReviews) {
    if ($r.status -eq 'Overdue') { Add-Finding 'Moderate' 'Access Reviews' 'Access review overdue' "$($r.name) is overdue." 'Run review, record reviewer decision, and schedule recurring cadence.' }
    Add-Evidence 'Access Review' $r.name 'Reviewed' "Resource=$($r.resource); Status=$($r.status)"
}
foreach ($c in $CAPolicies) {
    # Real Microsoft Graph conditionalAccessPolicy.state values are: enabled,
    # disabled, enabledForReportingButNotEnforced. There is no "reportOnly"
    # value in the API -- checking for it would silently never match against
    # a real tenant.
    if ($c.state -eq 'enabledForReportingButNotEnforced') { Add-Finding 'Moderate' 'Conditional Access' 'Policy is report-only' "$($c.displayName) is not enforced." 'Review sign-in impact and move to enabled when safe.' }
    Add-Evidence 'Conditional Access' $c.displayName 'Reviewed' "State=$($c.state)"
}

$Findings | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'findings.csv')
$Evidence | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath 'evidence-ledger.csv')
$Critical=@($Findings|Where-Object Severity -eq 'Critical').Count; $High=@($Findings|Where-Object Severity -eq 'High').Count; $Moderate=@($Findings|Where-Object Severity -eq 'Moderate').Count; $Low=@($Findings|Where-Object Severity -eq 'Low').Count
$Report = "# IAM Assessment Report`n`n## Executive Summary`n`nMode: $Mode`n`nFinding counts:`n`n- Critical: $Critical`n- High: $High`n- Moderate: $Moderate`n- Low: $Low`n`nThis assessment reviews identity lifecycle, authentication, SSO coverage, privileged access, service accounts, access reviews, Conditional Access posture, and MTTE friction where data is available.`n`n## Findings`n`n"
foreach ($f in $Findings) { $Report += "### [$($f.Severity)] $($f.Title)`n`nArea: $($f.Area)`n`nDetail: $($f.Detail)`n`nRecommendation: $($f.Recommendation)`n`n" }
$Report += "## Phase 2 Remediation Plan`n`n1. Close critical lifecycle and service-account risks first.`n2. Move critical applications toward group-based or access-package-based enablement.`n3. Enforce MFA and Conditional Access for high-value apps and privileged users.`n4. Convert permanent privileged access to eligible / JIT where licensing and process allow.`n5. Establish access review cadence and evidence retention.`n6. Re-run this assessment after remediation and compare MTTE and risk counts.`n`n## Redaction Reminder`n`nIf this report was generated from a real tenant, review every line before sharing. Remove tenant IDs, domains, UPNs, app IDs, group names, internal application names, security findings that reveal exploitable details, and customer-specific terms.`n"
$Report | Out-File -Encoding utf8 -FilePath (Join-Path $OutputPath 'iam-assessment-report.md')
"# Redaction Checklist`n`n- [ ] Tenant ID removed`n- [ ] Domain names removed`n- [ ] UPNs and email addresses removed`n- [ ] Object IDs removed`n- [ ] Application IDs removed`n- [ ] Client IDs removed`n- [ ] Group names generalized`n- [ ] Internal app names generalized`n- [ ] Admin names removed`n- [ ] Security findings rewritten as sanitized examples`n- [ ] Raw Graph exports deleted or kept outside the repo`n- [ ] .gitignore reviewed before commit`n" | Out-File -Encoding utf8 -FilePath (Join-Path $OutputPath 'redaction-checklist.md')
Write-Host "Assessment complete: $OutputPath" -ForegroundColor Green
