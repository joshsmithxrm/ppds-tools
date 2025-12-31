function Get-DataversePluginRegistrations {
    <#
    .SYNOPSIS
        Extracts plugin registrations from an assembly or NuGet package.

    .DESCRIPTION
        Parses a plugin assembly (.dll) or NuGet package (.nupkg) and extracts
        plugin step and image registrations based on attributes defined in code.

        The output is a registrations.json file that can be used with
        Deploy-DataversePlugins to register the plugins in an environment.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER InputPath
        Path to the plugin assembly (.dll) or NuGet package (.nupkg).

    .PARAMETER OutputPath
        Output file path for registrations.json.
        Default: registrations.json in the input file's directory.

    .PARAMETER Solution
        Solution unique name to add components to during deployment.

    .PARAMETER Force
        Overwrite existing file without merging.
        By default, existing deployment settings are preserved.

    .PARAMETER PassThru
        Return the extracted configuration as an object instead of writing to file.

    .EXAMPLE
        Get-DataversePluginRegistrations -InputPath "./bin/Release/MyPlugins.dll"

        Extracts registrations from the assembly and writes to registrations.json.

    .EXAMPLE
        Get-DataversePluginRegistrations -InputPath "./MyPlugins.1.0.0.nupkg" -Solution "MySolution"

        Extracts from NuGet package with solution assignment for deployment.

    .EXAMPLE
        $config = Get-DataversePluginRegistrations -InputPath "./MyPlugins.dll" -PassThru
        $config.assemblies[0].types | ForEach-Object { $_.typeName }

        Extracts registrations and returns them as an object for inspection.

    .OUTPUTS
        None by default. PSCustomObject with configuration if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('AssemblyPath')]
        [string]$InputPath,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$Solution,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate input file exists
    if (-not (Test-Path $InputPath)) {
        throw "Input file not found: $InputPath"
    }

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'plugins', 'extract'
        '--input', (Resolve-Path $InputPath).Path
    )

    if ($OutputPath) {
        $cliArgs += '--output'
        $cliArgs += $OutputPath
    }

    if ($Solution) {
        $cliArgs += '--solution'
        $cliArgs += $Solution
    }

    if ($Force) {
        $cliArgs += '--force'
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
            throw "Extraction failed: $($errorMessage -join "`n")"
        }
        throw "Extraction failed with exit code $LASTEXITCODE"
    }

    if ($PassThru) {
        # Parse JSON output
        $jsonOutput = $output | Where-Object { $_ -match '^\s*\{' } | Out-String
        try {
            return $jsonOutput | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse extraction output: $_"
        }
    }
    else {
        # Write CLI output to verbose
        $output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning $_.ToString()
            }
            else {
                Write-Verbose $_
            }
        }
    }
}
