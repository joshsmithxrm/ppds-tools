function Copy-DataverseData {
    <#
    .SYNOPSIS
        Copies data from one Dataverse environment to another.

    .DESCRIPTION
        Performs a complete data copy from a source to target Dataverse environment.
        This combines export and import into a single operation:
        1. Exports data from source environment to a temporary file
        2. Imports data into target environment
        3. Cleans up temporary file

        Use this for environment-to-environment data migrations.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER SourceProfile
        Authentication profile for the source environment.
        If not specified, uses the active profile.

    .PARAMETER SourceEnvironment
        Source environment - accepts URL, friendly name, unique name, or ID.
        Required.

    .PARAMETER TargetProfile
        Authentication profile for the target environment.
        Supports comma-separated values for parallel import scaling.
        If not specified, uses the active profile.

    .PARAMETER TargetEnvironment
        Target environment - accepts URL, friendly name, unique name, or ID.
        Required.

    .PARAMETER SchemaPath
        Path to the schema.xml file defining entities to migrate.

    .PARAMETER TempDirectory
        Temporary directory for intermediate data file.
        Default: system temp directory

    .PARAMETER Parallel
        Maximum concurrent entity exports.
        Default: CPU count * 2

    .PARAMETER BatchSize
        Records per API request.
        Default: 5000 (Dataverse maximum)

    .PARAMETER BypassPlugins
        Bypass custom plugin execution on target: sync, async, or all.
        Requires prvBypassCustomBusinessLogic privilege.

    .PARAMETER BypassFlows
        Bypass Power Automate flow triggers on target.

    .PARAMETER ContinueOnError
        Continue import on individual record failures.
        Default: true for copy operations.

    .PARAMETER StripOwnerFields
        Strip ownership fields allowing Dataverse to assign current user.

    .PARAMETER SkipMissingColumns
        Skip columns that exist in source but not in target environment.

    .PARAMETER UserMappingPath
        Path to user mapping XML file for remapping user references.

    .PARAMETER PassThru
        Return a copy result object with statistics.

    .EXAMPLE
        Copy-DataverseData `
            -SourceEnvironment "dev" `
            -TargetEnvironment "test" `
            -SchemaPath "./schema.xml"

        Copies data from dev to test environment using the active profile.

    .EXAMPLE
        Copy-DataverseData `
            -SourceProfile "dev-admin" -SourceEnvironment "https://dev.crm.dynamics.com" `
            -TargetProfile "test-admin" -TargetEnvironment "https://test.crm.dynamics.com" `
            -SchemaPath "./schema.xml" `
            -BypassPlugins all -BypassFlows

        Copies with specific profiles and all plugins/flows bypassed.

    .OUTPUTS
        None by default. PSCustomObject with statistics if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$SourceEnvironment,

        [Parameter()]
        [string]$TargetProfile,

        [Parameter(Mandatory)]
        [string]$TargetEnvironment,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter()]
        [string]$TempDirectory,

        [Parameter()]
        [int]$Parallel = 0,

        [Parameter()]
        [ValidateRange(1, 5000)]
        [int]$BatchSize = 5000,

        [Parameter()]
        [ValidateSet('sync', 'async', 'all')]
        [string]$BypassPlugins,

        [Parameter()]
        [switch]$BypassFlows,

        [Parameter()]
        [switch]$ContinueOnError,

        [Parameter()]
        [switch]$StripOwnerFields,

        [Parameter()]
        [switch]$SkipMissingColumns,

        [Parameter()]
        [string]$UserMappingPath,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate schema file exists
    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found: $SchemaPath"
    }

    # Validate user mapping file if specified
    if ($UserMappingPath -and -not (Test-Path $UserMappingPath)) {
        throw "User mapping file not found: $UserMappingPath"
    }

    # Build arguments
    $cliArgs = @(
        'data', 'copy'
        '--schema', (Resolve-Path $SchemaPath).Path
        '--source-env', $SourceEnvironment
        '--target-env', $TargetEnvironment
        '--output-format', 'Json'
    )

    if ($SourceProfile) {
        $cliArgs += '--source-profile'
        $cliArgs += $SourceProfile
    }

    if ($TargetProfile) {
        $cliArgs += '--target-profile'
        $cliArgs += $TargetProfile
    }

    if ($TempDirectory) {
        $cliArgs += '--temp-dir'
        $cliArgs += $TempDirectory
    }

    if ($Parallel -gt 0) {
        $cliArgs += '--parallel'
        $cliArgs += $Parallel
    }

    if ($BatchSize -ne 5000) {
        $cliArgs += '--batch-size'
        $cliArgs += $BatchSize
    }

    if ($BypassPlugins) {
        $cliArgs += '--bypass-plugins'
        $cliArgs += $BypassPlugins
    }

    if ($BypassFlows) {
        $cliArgs += '--bypass-flows'
    }

    if ($ContinueOnError) {
        $cliArgs += '--continue-on-error'
    }

    if ($StripOwnerFields) {
        $cliArgs += '--strip-owner-fields'
    }

    if ($SkipMissingColumns) {
        $cliArgs += '--skip-missing-columns'
    }

    if ($UserMappingPath) {
        $cliArgs += '--user-mapping'
        $cliArgs += (Resolve-Path $UserMappingPath).Path
    }

    $result = Invoke-PpdsMigration -Arguments $cliArgs
    if ($PassThru) {
        return $result
    }
}
