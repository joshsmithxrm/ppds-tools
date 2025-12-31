# Helper function to locate or install the ppds CLI tool

function Get-PpdsCli {
    <#
    .SYNOPSIS
        Locates the ppds CLI tool or offers to install it.

    .DESCRIPTION
        Searches for the ppds CLI tool in:
        1. Global .NET tools
        2. Local .NET tools (in tool-manifest)
        3. PATH

        If not found, offers to install it globally.

    .PARAMETER AutoInstall
        Automatically install if not found (no prompt).

    .OUTPUTS
        String. Path to the ppds executable.

    .EXAMPLE
        $cli = Get-PpdsCli
        & $cli plugins extract --help
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AutoInstall
    )

    # Check if ppds is in PATH
    $inPath = Get-Command 'ppds' -ErrorAction SilentlyContinue
    if ($inPath) {
        Write-Verbose "Found ppds in PATH: $($inPath.Source)"
        return $inPath.Source
    }

    # Check global .NET tools (cross-platform)
    $globalToolsPath = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.dotnet' 'tools'
    $cliExeName = if ($IsWindows) { 'ppds.exe' } else { 'ppds' }
    $globalCliPath = Join-Path $globalToolsPath $cliExeName
    if (Test-Path $globalCliPath) {
        Write-Verbose "Found ppds in global tools: $globalCliPath"
        return $globalCliPath
    }

    # Check for dotnet tool list
    try {
        $toolList = dotnet tool list --global 2>&1
        if ($toolList -match 'ppds\.cli') {
            Write-Verbose "Found ppds in dotnet global tools"
            return 'ppds'
        }
    }
    catch {
        Write-Verbose "Could not check dotnet tool list: $_"
    }

    # Not found - offer to install
    Write-Warning "ppds CLI tool not found."

    if ($AutoInstall) {
        Write-Host "Installing ppds CLI tool globally..."
        $installResult = dotnet tool install --global PPDS.Cli 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ppds installed successfully." -ForegroundColor Green
            return 'ppds'
        }
        else {
            throw "Failed to install ppds: $installResult"
        }
    }

    $response = Read-Host "Would you like to install it globally? (Y/n)"
    if ($response -eq '' -or $response -match '^[Yy]') {
        Write-Host "Installing ppds CLI tool..."
        $installResult = dotnet tool install --global PPDS.Cli 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ppds installed successfully." -ForegroundColor Green
            return 'ppds'
        }
        else {
            throw "Failed to install ppds: $installResult"
        }
    }

    throw @"
ppds CLI tool is required but not installed.

Install it manually with:
    dotnet tool install --global PPDS.Cli

Or install it locally in your project:
    dotnet new tool-manifest  # if no manifest exists
    dotnet tool install PPDS.Cli
"@
}
