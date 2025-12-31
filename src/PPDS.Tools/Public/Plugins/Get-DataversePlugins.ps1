function Get-DataversePlugins {
    <#
    .SYNOPSIS
        Lists registered plugins in a Dataverse environment.

    .DESCRIPTION
        Retrieves all plugin assemblies and packages registered in the target
        Dataverse environment, including their types, steps, and images.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER Assembly
        Filter by assembly name (classic DLL plugins).

    .PARAMETER Package
        Filter by package name or unique name (NuGet plugin packages).

    .PARAMETER PassThru
        Return results as structured objects instead of displaying formatted output.

    .EXAMPLE
        Get-DataversePlugins

        Lists all registered plugins using the active profile.

    .EXAMPLE
        Get-DataversePlugins -Profile "dev" -Assembly "MyPlugins"

        Lists plugins from a specific assembly.

    .EXAMPLE
        $plugins = Get-DataversePlugins -PassThru
        $plugins.Assemblies | ForEach-Object { $_.Name }

        Returns plugin data as objects for processing.

    .OUTPUTS
        Text output by default. PSCustomObject with plugin details if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [string]$Assembly,

        [Parameter()]
        [string]$Package,

        [Parameter()]
        [switch]$PassThru
    )

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'plugins', 'list'
    )

    if ($Profile) {
        $cliArgs += '--profile'
        $cliArgs += $Profile
    }

    if ($Environment) {
        $cliArgs += '--environment'
        $cliArgs += $Environment
    }

    if ($Assembly) {
        $cliArgs += '--assembly'
        $cliArgs += $Assembly
    }

    if ($Package) {
        $cliArgs += '--package'
        $cliArgs += $Package
    }

    if ($PassThru) {
        $cliArgs += '--json'
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and capture output
    $output = & $cliPath @cliArgs 2>&1

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        if ($errorMessage) {
            throw "List failed: $($errorMessage -join "`n")"
        }
        throw "List failed with exit code $LASTEXITCODE"
    }

    if ($PassThru) {
        # Parse JSON output
        $jsonOutput = $output | Where-Object { $_ -match '^\s*\{' } | Out-String
        try {
            return $jsonOutput | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse list output: $_"
        }
    }
    else {
        # Write CLI output to console
        $output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning $_.ToString()
            }
            elseif ($_ -match '^\s*[\{\[]') {
                # JSON output - skip in non-PassThru mode
            }
            else {
                Write-Verbose $_
            }
        }
    }
}
