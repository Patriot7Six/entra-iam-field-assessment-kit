# ConvertTo-RedactedIAMData.ps1
# Redacts and pseudonymizes tenant-specific values before they leave the tenant.
#
# Design note: earlier versions of this helper ran every string through a fixed
# regex pass (GUID / email / onmicrosoft.com) and called that "redaction." That
# only catches values matching those three shapes. A DisplayName like
# "Wile Coyote" or "Finance ERP" matches none of them and would pass through
# unchanged. This version keeps the regex pass for values that are safe to
# generalize in place (emails, onmicrosoft.com domains) and adds real
# pseudonymization for the fields the README promises: DisplayName-style
# fields become stable "Application 001" / "Group 001" / "User 001" labels,
# and Id/AppId/TenantId values become stable "user-0001" style pseudonyms
# instead of one shared "REDACTED_GUID" constant.
#
# "Stable" means the same input value maps to the same pseudonym everywhere it
# appears in a single run, so relationships between records (this user owns
# that service principal, this role assignment points to that principal) stay
# traceable in the redacted output. It does not mean stable across two
# separate runs -- each run builds its own mapping.

$script:PseudonymMaps = @{
    Id          = @{}
    DisplayName = @{}
}
$script:PseudonymCounters = @{
    Id          = 0
    DisplayName = 0
}

function Get-StablePseudonym {
    param(
        [Parameter(Mandatory)][ValidateSet('Id','DisplayName')][string]$Kind,
        [Parameter(Mandatory)][string]$Value,
        [string]$Prefix = 'item'
    )
    $map = $script:PseudonymMaps[$Kind]
    if ($map.ContainsKey($Value)) { return $map[$Value] }

    $script:PseudonymCounters[$Kind]++
    $n = $script:PseudonymCounters[$Kind]
    $pseudonym = if ($Kind -eq 'Id') {
        '{0}-{1:D4}' -f $Prefix, $n
    } else {
        '{0} {1:D3}' -f $Prefix, $n
    }
    $map[$Value] = $pseudonym
    return $pseudonym
}

function ConvertTo-RedactedString {
    # Generalizes values that are safe to pattern-match in place: emails, UPNs,
    # and *.onmicrosoft.com domains. Does not pseudonymize display names --
    # use Get-StablePseudonym for that, since display names don't match a regex.
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Value }
    $v = $Value
    $v = $v -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', 'user@example.redacted'
    $v = $v -replace '\b[a-zA-Z0-9-]+\.onmicrosoft\.com\b', 'tenant.onmicrosoft.example.redacted'
    return $v
}

function ConvertTo-RedactedObject {
    <#
    .SYNOPSIS
    Redacts and pseudonymizes an object's properties in place.

    .PARAMETER DisplayNameFields
    Property names on this object type that should become stable "Noun 001"
    pseudonyms rather than a regex substitution. Defaults cover the common
    field name used across the Graph object shapes in this kit.

    .PARAMETER PseudonymPrefix
    The noun used in the pseudonym, e.g. "User", "Group", "Application",
    "Service Account", "Role". Pass this per call site so users come out as
    "User 001" and apps come out as "Application 001" instead of everything
    sharing one generic label.
    #>
    param(
        [Parameter(ValueFromPipeline = $true)]$InputObject,
        [string[]]$DisplayNameFields = @('DisplayName','displayName'),
        [string]$PseudonymPrefix = 'Item'
    )
    process {
        $copy = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) {
            $name = $p.Name
            $value = $p.Value
            if ($null -eq $value) { $copy[$name] = $null; continue }

            if ($name -match '^(Id|AppId|TenantId|PrincipalId|ObjectId)$' -and $value -is [string] -and $value -match '^[0-9a-fA-F-]{8,}$') {
                $copy[$name] = Get-StablePseudonym -Kind Id -Value ([string]$value) -Prefix ($PseudonymPrefix.ToLower() -replace '\s','-')
            }
            elseif ($DisplayNameFields -contains $name -and $value -is [string]) {
                $copy[$name] = Get-StablePseudonym -Kind DisplayName -Value $value -Prefix $PseudonymPrefix
            }
            elseif ($name -match '^(UserPrincipalName|Mail|ProxyAddresses)$') {
                $copy[$name] = ConvertTo-RedactedString ([string]$value)
            }
            elseif ($value -is [string]) {
                $copy[$name] = ConvertTo-RedactedString $value
            }
            else {
                $copy[$name] = $value
            }
        }
        [pscustomobject]$copy
    }
}
