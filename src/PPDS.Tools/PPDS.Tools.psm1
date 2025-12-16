# PPDS.Tools.psm1 - Root module file
# Power Platform Developer Suite - PowerShell Tools

$ErrorActionPreference = 'Stop'

#region DataverseConnection Class
# Must be defined in root module for proper visibility

class DataverseConnection {
    [string]$EnvironmentUrl
    [string]$CurrentAccessToken
    [datetime]$TokenExpiry
    [string]$ConnectedOrgFriendlyName
    [hashtable]$ConnectedOrgPublishedEndpoints
    [bool]$IsReady

    # Auth context (non-sensitive, for diagnostics only)
    hidden [string]$TenantId
    hidden [string]$ClientId
    hidden [string]$AuthMethod  # "ServicePrincipal" or "DeviceCode"

    # Note: ClientSecret and RefreshToken are intentionally NOT stored.
    # Storing long-lived credentials poses security risks. If token refresh
    # is needed in the future, credentials should be re-prompted or use
    # the SecretManagement module.

    DataverseConnection([string]$environmentUrl, [string]$accessToken, [datetime]$expiry, [string]$orgName) {
        $this.EnvironmentUrl = $environmentUrl.TrimEnd("/")
        $this.CurrentAccessToken = $accessToken
        $this.TokenExpiry = $expiry
        $this.ConnectedOrgFriendlyName = $orgName
        $this.ConnectedOrgPublishedEndpoints = @{
            "WebApplication" = $this.EnvironmentUrl
        }
        $this.IsReady = $true
    }

    [bool] IsTokenExpired() {
        # Note: This method exists for future use. Currently, long-running
        # operations that exceed token lifetime (~60 min) require reconnection.
        return [datetime]::UtcNow -ge $this.TokenExpiry.AddMinutes(-5)
    }

    [string] ToString() {
        return "DataverseConnection: $($this.ConnectedOrgFriendlyName) @ $($this.EnvironmentUrl)"
    }
}

#endregion

# Dot-source private functions
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Dot-source public functions
$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Export public functions (also declared in manifest)
$publicFunctions = Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse |
    Select-Object -ExpandProperty BaseName

Export-ModuleMember -Function $publicFunctions
