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

    # Auth context for token refresh
    hidden [string]$TenantId
    hidden [string]$ClientId
    hidden [string]$ClientSecret
    hidden [string]$RefreshToken

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
        return [datetime]::UtcNow -ge $this.TokenExpiry.AddMinutes(-5)
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
