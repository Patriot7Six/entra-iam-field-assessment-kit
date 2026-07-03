# Connects a third-party application that currently uses local accounts to
# Entra ID SAML SSO, and gates access through a group-based app role
# assignment instead of manual approval. This is the pattern the assessment
# script recommends for any finding tagged "Application lacks SSO."
#
# Placeholder-only. Do not add real tenant IDs, app IDs, group IDs, secrets,
# or identifier URIs from a real tenant's verified domain.

resource "azuread_application" "example_app" {
  display_name    = "Application 001"
  identifier_uris = ["https://example.redacted/application-001"]

  web {
    redirect_uris = ["https://example.redacted/application-001/saml/acs"]
  }

  # Group-based access instead of individually assigned users -- keeps
  # enablement to a group-membership change rather than a per-user request.
  app_role {
    allowed_member_types = ["User"]
    description          = "Standard access to Application 001"
    display_name         = "Standard User"
    enabled               = true
    id                    = "00000000-0000-0000-0000-100000000001"
    value                 = "StandardUser"
  }
}

resource "azuread_service_principal" "example_app" {
  application_id = azuread_application.example_app.client_id

  # Enables SAML SSO instead of the app's local login. custom_single_sign_on
  # marks this as a non-gallery SAML app; enterprise exposes it in the
  # Enterprise Applications blade the way a customer's admins expect to find it.
  preferred_single_sign_on_mode = "saml"

  feature_tags {
    enterprise             = true
    custom_single_sign_on  = true
  }

  saml_single_sign_on {
    relay_state = "/"
  }

  # Require the app role above before Entra ID issues a token -- prevents
  # "anyone in the tenant" access once SSO replaces local accounts.
  app_role_assignment_required = true
}

# Ties access to the pre-existing "Group 001 - Critical App Access" group
# instead of assigning users one at a time -- this is what turns a manual,
# multi-day access request into a group-membership change, which is the
# lever behind every MTTE improvement this kit's scoring model looks for.
resource "azuread_app_role_assignment" "example_app_standard_access" {
  app_role_id         = azuread_service_principal.example_app.app_role_ids["StandardUser"]
  principal_object_id = azuread_group.critical_app_finance.object_id
  resource_object_id  = azuread_service_principal.example_app.object_id
}
