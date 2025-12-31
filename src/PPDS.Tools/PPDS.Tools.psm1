# PPDS.Tools.psm1 - Root module file
# Power Platform Developer Suite - PowerShell Tools
#
# This module provides PowerShell wrappers around the ppds CLI tool.
# All cmdlets delegate to the CLI for actual operations.

$ErrorActionPreference = 'Stop'

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

# Create and export aliases (manifest AliasesToExport controls what's visible)
New-Alias -Name Invoke-DataverseMigration -Value Copy-DataverseData -Force
Export-ModuleMember -Alias Invoke-DataverseMigration
