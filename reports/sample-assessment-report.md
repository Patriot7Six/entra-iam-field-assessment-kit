# Sample IAM Assessment Report

Generated from `./scripts/Invoke-IAMAssessment.ps1 -Mode Demo` against the ACME Coyote Systems demo dataset in `/demo`. Re-run the script to regenerate this file; do not hand-edit.

## Executive Summary

Mode: Demo

Finding counts:

- Critical: 2
- High: 9
- Moderate: 4
- Low: 1

This assessment reviews identity lifecycle, authentication, SSO coverage, privileged access, service accounts, access reviews, Conditional Access posture, and MTTE friction where data is available.

## Findings

### [Critical] Terminated or expired worker still enabled

Area: Lifecycle

Detail: Legacy Contractor has a termination date but account is enabled.

Recommendation: Disable account, remove group access, revoke sessions, and document offboarding evidence.

### [Critical] Service account has no owner

Area: Service Accounts

Detail: svc-legacy-report has no named owner.

Recommendation: Assign accountable owner or retire account.

### [High] Enabled user lacks MFA-ready flag

Area: Authentication

Detail: Marvin Martian appears enabled but not MFA-ready in source data.

Recommendation: Require MFA registration or confirm compensating control.

### [High] Enabled user lacks MFA-ready flag

Area: Authentication

Detail: Legacy Contractor appears enabled but not MFA-ready in source data.

Recommendation: Require MFA registration or confirm compensating control.

### [High] Application lacks SSO

Area: SSO

Detail: Legacy Timekeeping is not SSO-enabled.

Recommendation: Move app to Entra enterprise app SSO where supported or document exception.

### [High] Application lacks MFA requirement

Area: Authentication

Detail: Legacy Timekeeping does not require MFA in the source data.

Recommendation: Enforce MFA through Conditional Access or app control.

### [High] Application lacks MFA requirement

Area: Authentication

Detail: Vendor Portal does not require MFA in the source data.

Recommendation: Enforce MFA through Conditional Access or app control.

### [High] Service account credential age exceeds one year

Area: Service Accounts

Detail: svc-finance-sync credential age is 410 days.

Recommendation: Rotate credential or replace with managed identity / certificate-based auth where practical.

### [High] Service account credential age exceeds one year

Area: Service Accounts

Detail: svc-legacy-report credential age is 900 days.

Recommendation: Rotate credential or replace with managed identity / certificate-based auth where practical.

### [High] Permanent privileged role assignment

Area: Privileged Access

Detail: wile@acme-coyote.example has Global Administrator as Permanent.

Recommendation: Move to eligible/JIT assignment where supported and require periodic review.

### [High] Permanent privileged role assignment

Area: Privileged Access

Detail: svc-legacy-report has Privileged Role Administrator as Permanent.

Recommendation: Move to eligible/JIT assignment where supported and require periodic review.

### [Moderate] Critical app enablement exceeds one-hour ceiling

Area: MTTE

Detail: Finance ERP average enablement is 16 hours, above the one-hour MTTE ceiling.

Recommendation: Map role-to-group or access-package path to target under one hour.

### [Moderate] Critical app enablement exceeds one-hour ceiling

Area: MTTE

Detail: Engineering Git average enablement is 4 hours, above the one-hour MTTE ceiling.

Recommendation: Map role-to-group or access-package path to target under one hour.

### [Moderate] Access review overdue

Area: Access Reviews

Detail: Quarterly Finance ERP Access Review is overdue.

Recommendation: Run review, record reviewer decision, and schedule recurring cadence.

### [Moderate] Policy is report-only

Area: Conditional Access

Detail: Block legacy authentication is not enforced.

Recommendation: Review sign-in impact and move to enabled when safe.

### [Low] Critical app enablement above five-minute stretch goal

Area: MTTE

Detail: Deployment Pipeline average enablement is 30.0 minutes -- inside the one-hour ceiling but above the five-minute stretch goal for critical systems.

Recommendation: Evaluate access-package auto-assignment or pre-approved group membership to close the gap to five minutes.

## Phase 2 Remediation Plan

1. Close critical lifecycle and service-account risks first.
2. Move critical applications toward group-based or access-package-based enablement.
3. Enforce MFA and Conditional Access for high-value apps and privileged users.
4. Convert permanent privileged access to eligible / JIT where licensing and process allow.
5. Establish access review cadence and evidence retention.
6. Re-run this assessment after remediation and compare MTTE and risk counts.

## Redaction Reminder

If this report was generated from a real tenant, review every line before sharing. Remove tenant IDs, domains, UPNs, app IDs, group names, internal application names, security findings that reveal exploitable details, and customer-specific terms.
