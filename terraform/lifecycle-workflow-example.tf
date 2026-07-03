# Why there's no azuread_lifecycle_workflow resource here:
#
# The hashicorp/azuread provider does not currently expose a native resource
# for Entra ID Lifecycle Workflows (the joiner/mover/leaver automation
# feature under Identity Governance). The provider's Identity Governance
# coverage is limited to Access Packages, Catalogs, and related entitlement
# management resources -- Lifecycle Workflows themselves are configured via
# the Graph API's identityGovernance/lifecycleWorkflows endpoint directly, or
# through the Entra admin center, not through this provider. That's a real
# gap in the provider, not an oversight in this kit -- an earlier version of
# this file was a placeholder comment with no explanation, which read as
# unfinished rather than as a known constraint.
#
# What Terraform *can* manage today for the joiner/mover pattern is
# entitlement management: Access Packages and Catalogs. That's a narrower
# tool than full Lifecycle Workflows (no automated leaver deprovisioning, no
# scheduled triggers), but it does codify "new hire in this role gets this
# access automatically" -- which is most of what a Phase 2 remediation plan
# needs for the MTTE problem, as opposed to the leaver/compliance problem
# Lifecycle Workflows is built for.
#
# Placeholder-only. Do not add real tenant IDs, catalog IDs, or resource IDs
# from a real tenant.

resource "azuread_access_package_catalog" "engineering" {
  display_name = "Engineering Access Catalog"
  description  = "Access packages for standard engineering onboarding"
}

resource "azuread_access_package" "engineering_standard" {
  catalog_id    = azuread_access_package_catalog.engineering.id
  display_name  = "Engineering Standard Access"
  description   = "Group 001 membership and Application 001 standard role, auto-assigned on hire"
}
