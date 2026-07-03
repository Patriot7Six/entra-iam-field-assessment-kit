# Key Vault and API Security Notes

Portfolio mapping only. No Key Vault instance is provisioned or tested by
this kit. This connects the service-account findings this kit already
produces to where Key Vault and API-security practice actually fits.

## Where Key Vault fits the service-account problem this kit already flags

`service-account-cleanup.md` and the `Invoke-IAMAssessment.ps1` scoring logic
flag two conditions: no named owner, and credential age over one year. Both
are downstream of the same root cause -- a long-lived secret sitting in a
service principal, a config file, or a pipeline variable with nobody
accountable for rotating it. Key Vault addresses the storage and rotation
half of that problem; it doesn't replace the ownership half.

Practical pattern for the apps this kit's demo data models as
`AccessMethod=LocalAccounts` or holding stale credentials:

1. Move the secret (API key, connection string, client secret) into Key
   Vault instead of app config or a pipeline variable.
2. Grant access with Key Vault RBAC roles scoped to the specific vault or
   secret, not a blanket Contributor role on the resource group.
3. Where the caller is an Azure resource (a Function App, an App Service, a
   VM, a container), use a system- or user-assigned managed identity instead
   of a stored client secret. This is what the assessment script's existing
   recommendation ("replace with managed identity / certificate-based auth
   where practical") is pointing at -- managed identity removes the
   credential-age problem entirely because there's no long-lived secret to
   age out.
4. Where managed identity isn't an option (the caller isn't an Azure
   resource, or it's a third-party SaaS product), set an expiration on the
   Key Vault secret and alert before it lapses, and keep the credential-age
   check in this kit's scoring model as the compensating control.

## API security, scoped to what this role actually touches

The JD's "securing APIs" qualification, read against the rest of the
posting, points at API access control (who or what can call an API and with
what scope) rather than API development security (input validation, OWASP
API Top 10). For an IAM engineer, the relevant surface is:

- OAuth 2.0 / OIDC scopes and app roles on the API's app registration --
  this kit's `enterprise-app-example.tf` demonstrates an app role gating
  access through group membership rather than per-user assignment.
- Whether the API validates token audience and scope/role claims on every
  call, not just at initial sign-in -- this is the same gap CAE closes for
  session tokens (see `docs/cae-caep-notes.md`).
- Credential lifecycle for machine-to-machine callers, which is the Key
  Vault / managed identity pattern above.

None of this has been implemented against a real API in this kit. Treat it
as the talking points for a discovery conversation, not a tested reference
architecture.
