function Export-DataverseData {
    <#
    .SYNOPSIS
        Exports data from a Dataverse environment to a ZIP file.

    .DESCRIPTION
        Exports data from Dataverse based on a schema definition file.
        Uses parallel processing for high-performance data extraction.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.
        Create profiles with Connect-DataverseEnvironment or 'ppds auth create'.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER SchemaPath
        Path to the schema.xml file that defines entities and relationships to export.

    .PARAMETER OutputPath
        Path for the output ZIP file containing exported data.

    .PARAMETER Parallel
        Degree of parallelism for concurrent entity exports.
        Default: CPU count * 2

    .PARAMETER BatchSize
        Records per API request (controls request size, all records are exported).
        Default: 5000 (Dataverse maximum)

    .PARAMETER PassThru
        Return the output file as a FileInfo object.

    .EXAMPLE
        Export-DataverseData -SchemaPath "./schema.xml" -OutputPath "./data.zip"

        Exports data using the active profile.

    .EXAMPLE
        Export-DataverseData -Profile "dev" -Environment "https://org.crm.dynamics.com" `
            -SchemaPath "./schema.xml" -OutputPath "./data.zip" -Parallel 16

        Exports using a specific profile and environment with 16 parallel threads.

    .OUTPUTS
        None by default. FileInfo if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [int]$Parallel = 0,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$BatchSize = 5000,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate schema file exists
    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found: $SchemaPath"
    }

    # Build arguments
    $cliArgs = @(
        'data', 'export'
        '--schema', (Resolve-Path $SchemaPath).Path
        '--output', $OutputPath
        '--output-format', 'Json'
    )

    if ($Profile) {
        $cliArgs += '--profile'
        $cliArgs += $Profile
    }

    if ($Environment) {
        $cliArgs += '--environment'
        $cliArgs += $Environment
    }

    if ($Parallel -gt 0) {
        $cliArgs += '--parallel'
        $cliArgs += $Parallel
    }

    if ($BatchSize -ne 5000) {
        $cliArgs += '--batch-size'
        $cliArgs += $BatchSize
    }

    Invoke-PpdsMigration -Arguments $cliArgs | Out-Null
    if ($PassThru) {
        return Get-Item -LiteralPath $OutputPath
    }
}
