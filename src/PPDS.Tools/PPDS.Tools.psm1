# PPDS.Tools.psm1 - Root module file
# Power Platform Developer Suite - PowerShell Tools

$ErrorActionPreference = 'Stop'

# Module constants
# Microsoft's first-party OAuth app for Dataverse interactive authentication
# This is a well-known public client ID that enables device code and browser-based auth
$script:DefaultOAuthAppId = '51f81489-12ee-4a9e-aaae-a2591f45987d'

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
