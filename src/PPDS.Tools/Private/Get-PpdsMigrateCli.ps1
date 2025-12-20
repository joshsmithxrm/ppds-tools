# Helper function to locate or install the ppds-migrate CLI tool

function Get-PpdsMigrateCli {
    <#
    .SYNOPSIS
        Locates the ppds-migrate CLI tool or offers to install it.

    .DESCRIPTION
        Searches for the ppds-migrate CLI tool in:
        1. Global .NET tools
        2. Local .NET tools (in tool-manifest)
        3. PATH

        If not found, offers to install it globally.

    .PARAMETER AutoInstall
        Automatically install if not found (no prompt).

    .OUTPUTS
        String. Path to the ppds-migrate executable.

    .EXAMPLE
        $cli = Get-PpdsMigrateCli
        & $cli export --help
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AutoInstall
    )

    # Check if ppds-migrate is in PATH
    $inPath = Get-Command 'ppds-migrate' -ErrorAction SilentlyContinue
    if ($inPath) {
        Write-Verbose "Found ppds-migrate in PATH: $($inPath.Source)"
        return $inPath.Source
    }

    # Check global .NET tools
    $globalToolsPath = Join-Path $env:USERPROFILE '.dotnet\tools'
    $globalCliPath = Join-Path $globalToolsPath 'ppds-migrate.exe'
    if (Test-Path $globalCliPath) {
        Write-Verbose "Found ppds-migrate in global tools: $globalCliPath"
        return $globalCliPath
    }

    # Check for dotnet tool list
    try {
        $toolList = dotnet tool list --global 2>&1
        if ($toolList -match 'ppds\.migration\.cli') {
            Write-Verbose "Found ppds-migrate in dotnet global tools"
            return 'ppds-migrate'
        }
    }
    catch {
        Write-Verbose "Could not check dotnet tool list: $_"
    }

    # Not found - offer to install
    Write-Warning "ppds-migrate CLI tool not found."

    if ($AutoInstall) {
        Write-Host "Installing ppds-migrate CLI tool globally..."
        $installResult = dotnet tool install --global PPDS.Migration.Cli 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ppds-migrate installed successfully." -ForegroundColor Green
            return 'ppds-migrate'
        }
        else {
            throw "Failed to install ppds-migrate: $installResult"
        }
    }

    $response = Read-Host "Would you like to install it globally? (Y/n)"
    if ($response -eq '' -or $response -match '^[Yy]') {
        Write-Host "Installing ppds-migrate CLI tool..."
        $installResult = dotnet tool install --global PPDS.Migration.Cli 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ppds-migrate installed successfully." -ForegroundColor Green
            return 'ppds-migrate'
        }
        else {
            throw "Failed to install ppds-migrate: $installResult"
        }
    }

    throw @"
ppds-migrate CLI tool is required but not installed.

Install it manually with:
    dotnet tool install --global PPDS.Migration.Cli

Or install it locally in your project:
    dotnet new tool-manifest  # if no manifest exists
    dotnet tool install PPDS.Migration.Cli
"@
}
