# CAE and CAEP Notes

Portfolio mapping only. This kit does not implement or test CAE against a live
tenant. Validate current behavior against Microsoft's documentation before
using any of this in a customer engagement -- CAE's supported events and
enforcement modes have changed more than once.

## What each term means

**CAE (Continuous Access Evaluation)** is Microsoft's implementation of a
back-channel between Entra ID (the token issuer) and a resource provider
(Exchange Online, SharePoint, Teams, Microsoft Graph, and others) that lets
the resource provider reject a still-valid token in near real time instead of
waiting for it to expire. It is Microsoft's product name for the capability.

**CAEP (Continuous Access Evaluation Profile)** is the underlying industry
standard: an OpenID Shared Signals Framework profile for propagating security
events between providers. CAE is Microsoft's implementation built on top of
CAEP, not a separate, unrelated feature. A JD asking for "CAE and CAEP" is
asking for both the Microsoft-specific product knowledge and the standards
-based reasoning behind it.

## Two evaluation paths

- **Critical event evaluation** -- doesn't depend on Conditional Access.
  Available in any tenant. Revokes sessions in near real time on: user
  disabled or deleted, password change or reset, and elevated user risk.
- **Conditional Access policy evaluation** -- requires the
  `continuousAccessEvaluation` session control in a Conditional Access
  policy. Enforces network location changes in near real time, with two
  modes: standard (allows a narrow exception for IP mismatches between what
  Entra ID sees and what the resource provider sees) and strict location
  enforcement, which removes that exception and blocks immediately on
  mismatch.

## Where this maps to the assessment kit

- The `conditional-access-baseline.md` doc in this kit already recommends
  requiring MFA and blocking legacy auth. The next tier for a CAE-aware
  posture is enabling the CAE session control on the policies protecting
  Critical-tier apps (see `demo/applications.csv`) and deciding standard vs.
  strict location enforcement per app, not tenant-wide.
- CAE tokens for CAE-capable apps can live up to 28 hours instead of the
  usual 60-90 minutes, because revocation happens over the back channel
  instead of through token expiry. That tradeoff (fewer re-auth prompts,
  same or better real-world revocation speed) is worth stating explicitly
  when a customer asks why a longer token lifetime isn't a downgrade.
- CAE also has a workload-identity variant for service principals, scoped
  today to Microsoft Graph as the resource provider and single-tenant apps.
  It requires the Conditional Access policy assigned directly to the service
  principal -- group-based assignment doesn't apply to workload identities
  the way it does to users. Relevant to the `service-account-cleanup.md`
  workflow in this kit: rotating a stale credential doesn't get you
  real-time revocation on its own without a workload-identity CA policy.
