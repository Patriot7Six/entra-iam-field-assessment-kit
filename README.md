# Entra IAM Field Assessment Kit

A customer-facing IAM assessment and remediation kit for Microsoft Entra ID environments.

This repo models how an IAM engineer can assess a customer's current identity environment, identify access risk, score Mean Time to Enable (MTTE), and turn findings into an engineering-ready remediation plan.

It is built for two operating modes:

1. **Demo mode** — runs against sanitized CSV and JSON files in `/demo`.
2. **Tenant mode** — optionally connects to Microsoft Graph PowerShell and exports redacted assessment data from an authorized Microsoft 365 / Entra ID tenant.

> Public repo rule: never commit tenant exports, tenant IDs, domain names, user principal names, object IDs, app IDs, client secrets, access tokens, refresh tokens, certificate thumbprints, internal app names, customer names, or real security findings.

## Scenario

ACME Coyote Systems is a 375-person regulated supplier with inconsistent SSO coverage, manual access requests, stale privileged roles, weak service account ownership, and slow onboarding for critical applications.

The goal is to move from ad hoc access administration to a documented IAM operating model with faster enablement, cleaner evidence, and lower identity risk.

## What This Shows

- Phase 1 IAM assessment
- Phase 2 remediation planning
- Entra ID and Conditional Access thinking, including Continuous Access
  Evaluation (see `docs/cae-caep-notes.md`)
- SSO and MFA coverage review, including a portable Okta variant of the same
  method (see `docs/okta-sso-audit-checklist.md`)
- Privileged access analysis
- Joiner / mover / leaver lifecycle review
- Service account cleanup planning, including where Key Vault and managed
  identity fit (see `docs/key-vault-and-api-security-notes.md`)
- Access review evidence
- MTTE scoring against Slower's own framing: under one hour, five-minute
  stretch goal for critical systems
- Customer-ready documentation

## Known limitations

- Tenant mode has not been execution-tested against a live tenant in the
  environment that built this kit (no PowerShell available there). Cmdlet
  and property names are verified against Microsoft's published Graph
  PowerShell SDK documentation, but run this against a test tenant first.
- Tenant mode does not collect access reviews
  (`Get-MgIdentityGovernanceAccessReviewDefinition`, requires Entra ID
  Governance licensing) yet -- `AccessReviews` is empty outside Demo mode.
- Service principal credential collection depends on
  `Get-MgServicePrincipal` returning `PasswordCredentials` /
  `KeyCredentials`; some SDK versions have shipped with a bug returning
  these empty even when explicitly selected. Verify against a known service
  principal with secrets before trusting a zero result.
- Privileged role collection tries PIM schedules first and falls back to
  plain role assignments; eligible (PIM) assignments require Entra ID P2 /
  Governance licensing and will come back empty without it.

## Quick Start: Demo Mode

From PowerShell 7:

```powershell
cd entra-iam-field-assessment-kit
./scripts/Invoke-IAMAssessment.ps1 -Mode Demo -DemoPath ./demo -OutputPath ./reports/generated
```

Open:

```text
reports/generated/iam-assessment-report.md
reports/generated/evidence-ledger.csv
reports/generated/redaction-checklist.md
```

## Optional: Tenant Mode

Tenant mode uses Microsoft Graph PowerShell read-only scopes where possible. Run it only from a tenant you are authorized to assess.

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
./scripts/Connect-IAMAssessmentGraph.ps1
./scripts/Invoke-IAMAssessment.ps1 -Mode Tenant -OutputPath ./reports/tenant-redacted -Redact
```

The script redacts common sensitive fields before writing report outputs. You still need to review everything in `/reports/tenant-redacted` before publishing screenshots or copying content into GitHub.

## What Gets Redacted

The redaction helper (`scripts/ConvertTo-RedactedIAMData.ps1`) applies two
different treatments depending on the field:

- Emails, UPNs, and `*.onmicrosoft.com` domains -> pattern-replaced in place
  (`user@example.redacted`, `tenant.onmicrosoft.example.redacted`).
- Id / AppId / TenantId / PrincipalId / ObjectId fields -> stable pseudonyms
  such as `user-0001`, `group-0001`, `application-0001`. "Stable" means the
  same real value maps to the same pseudonym everywhere it appears within a
  single run, so relationships between records stay traceable -- it does not
  mean stable across separate runs.
- DisplayName fields -> stable `Noun 001` pseudonyms (`Application 001`,
  `Group 001`, `User 001`, `Service Account 001`), using the noun passed to
  `ConvertTo-RedactedObject -PseudonymPrefix` for that object type.

This is a stated design change from an earlier version of this kit, where
the redaction helper ran every string through a fixed regex and called
display names "redacted" even though none of the three regex patterns
(GUID, email, onmicrosoft.com) match a plain name like "Finance ERP." That
version's README claims didn't match what the code did. This version's
claims are what the code in `scripts/ConvertTo-RedactedIAMData.ps1` actually
does -- verify that yourself before trusting it against real tenant data;
don't take the README's word for it either.

## Repo Safety Rules

Commit:

- `/demo`
- `/docs`
- `/scripts`
- `/terraform`
- `/control-mapping`
- `/reports/sample-*`

Do not commit:

- `/reports/tenant-*`
- `/exports`
- `.env`
- `*.secret.json`
- `graph-context.json`
- Any raw tenant CSV/JSON export

## Outputs

The assessment produces:

- Executive summary
- IAM environment snapshot
- What is working
- What is not working
- High-risk findings
- MTTE findings
- SSO and MFA coverage notes
- Privileged access review
- Orphaned and stale account indicators
- Service account risk
- Conditional Access gaps
- Access review maturity
- Phase 2 remediation roadmap
- Evidence ledger
- Redaction checklist

## License

MIT. Use it, fork it, improve it, but do not publish customer or tenant data.
