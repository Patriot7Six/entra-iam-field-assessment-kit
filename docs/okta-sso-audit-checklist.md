# Okta SSO Audit Checklist

Portfolio mapping only. This checklist has not been run against a live Okta
org -- it exists to show the same assessment method this kit applies to
Entra ID carries over to Okta, not to claim hands-on Okta production
experience. Terms below use current Okta Identity Engine naming; confirm
against the target org, since Classic Engine orgs use different policy
names (Sign-On Policy / App Sign-On Policy rather than Global Session
Policy / Authentication Policies).

## Discovery questions (mirrors `phase-1-discovery-questions.md`)

- Is this org on Identity Engine or Classic Engine? Policy names and
  capabilities differ between the two.
- What's the source of truth for user profiles -- Okta Universal Directory
  itself, or is profile sourced from an HR system or another directory via
  SCIM, making Okta read-only for those attributes?
- Which apps are provisioned via SCIM (automated joiner/mover/leaver) versus
  manually assigned?
- Which apps still rely on Okta-stored passwords instead of SSO?
- Are Super Admin and other privileged admin roles scoped to the minimum
  needed, or is there a habit of granting Super Admin broadly?
- Are Network Zones defined and used in policy conditions, or is every
  policy scoped to "Anywhere"?

## Authentication and session posture (mirrors `conditional-access-baseline.md`)

- Global Session Policy: MFA requirement, session lifetime, and reauth
  frequency for the org as a whole.
- Authentication Policies (per-app sign-on policies): confirm high-value and
  critical apps have a stricter policy than the org default rather than
  inheriting it silently.
- Account management policy: phishing-resistant authenticator enrollment
  (Okta Verify, WebAuthn/passkeys) required or optional; password recovery
  and account unlock flow requirements.
- Legacy or weak factors (SMS, security questions) still enabled as a
  fallback -- flag the same way this kit flags legacy authentication in
  Entra ID.

## Lifecycle and service accounts (mirrors `service-account-cleanup.md`)

- SCIM-provisioned apps: confirm deprovisioning on deactivation actually
  fires (Okta sets the SCIM user to `active=false`; the receiving app
  decides what that means, and not every integration handles it the same
  way).
- Non-SCIM apps: who owns the manual deprovisioning step, and what evidence
  proves it happened within a defined SLA after termination?
- API tokens and service integrations (Okta API tokens, OAuth service apps):
  ownership, rotation cadence, and scope -- the same owner/credential-age
  check this kit's script runs against Entra service principals.

## What this checklist does not cover

Okta Identity Governance (access certification campaigns, entitlement
management, access request workflows) is a separate licensed capability and
isn't addressed here. If the target org has it, that's where recurring
access reviews and certification campaigns -- the Okta equivalent of this
kit's `access-reviews.json` handling -- would actually live.
