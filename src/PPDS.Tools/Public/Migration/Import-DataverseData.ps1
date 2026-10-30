function Import-DataverseData {
    <#
    .SYNOPSIS
        Imports data from a ZIP file into a Dataverse environment.

    .DESCRIPTION
        Imports data into Dataverse from a previously exported data file.
        Handles dependency ordering, circular references, and many-to-many relationships.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.
        Create profiles with Connect-DataverseEnvironment or 'ppds auth create'.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER DataPath
        Path to the data.zip file containing exported data.

    .PARAMETER BypassPlugins
        Bypass custom plugin execution during import.
        Valid values: sync, async, all
        Requires prvBypassCustomBusinessLogic privilege.

    .PARAMETER BypassFlows
        Bypass Power Automate flow triggers during import.

    .PARAMETER ContinueOnError
        Continue import on individual record failures.
        Failed records are logged but don't stop the import.

    .PARAMETER Mode
        Import mode for handling existing records:
        - Create: Create new records only (fails if exists)
        - Update: Update existing records only (fails if not exists)
        - Upsert: Create or update as needed (default)

    .PARAMETER UserMappingPath
        Path to user mapping XML file for remapping user references.
        Use New-DataverseUserMapping to generate this file.

    .PARAMETER StripOwnerFields
        Strip ownership fields (ownerid, createdby, modifiedby) allowing
        Dataverse to assign the current user.

    .PARAMETER SkipMissingColumns
        Skip columns that exist in exported data but not in target environment.
        Prevents schema mismatch errors when environments differ.

    .PARAMETER PassThru
        Return an import result object with statistics.

    .EXAMPLE
        Import-DataverseData -DataPath "./data.zip"

        Imports data using the active profile with default settings (Upsert mode).

    .EXAMPLE
        Import-DataverseData -Profile "prod" -DataPath "./data.zip" `
            -BypassPlugins all -BypassFlows -ContinueOnError

        Imports with all plugins and flows bypassed, continuing on errors.

    .EXAMPLE
        Import-DataverseData -DataPath "./data.zip" -UserMappingPath "./usermapping.xml" `
            -StripOwnerFields -SkipMissingColumns

        Imports with user remapping and flexible schema handling.

    .OUTPUTS
        None by default. PSCustomObject with import statistics if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$DataPath,

        [Parameter()]
        [ValidateSet('sync', 'async', 'all')]
        [string]$BypassPlugins,

        [Parameter()]
        [switch]$BypassFlows,

        [Parameter()]
        [switch]$ContinueOnError,

        [Parameter()]
        [ValidateSet('Create', 'Update', 'Upsert')]
        [string]$Mode = 'Upsert',

        [Parameter()]
        [string]$UserMappingPath,

        [Parameter()]
        [switch]$StripOwnerFields,

        [Parameter()]
        [switch]$SkipMissingColumns,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate data file exists
    if (-not (Test-Path $DataPath)) {
        throw "Data file not found: $DataPath"
    }

    # Validate user mapping file if specified
    if ($UserMappingPath -and -not (Test-Path $UserMappingPath)) {
        throw "User mapping file not found: $UserMappingPath"
    }

    # Build arguments
    $cliArgs = @(
        'data', 'import'
        '--data', (Resolve-Path $DataPath).Path
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

    if ($Mode -ne 'Upsert') {
        $cliArgs += '--mode'
        $cliArgs += $Mode
    }

    if ($UserMappingPath) {
        $cliArgs += '--user-mapping'
        $cliArgs += (Resolve-Path $UserMappingPath).Path
    }

    if ($StripOwnerFields) {
        $cliArgs += '--strip-owner-fields'
    }

    if ($SkipMissingColumns) {
        $cliArgs += '--skip-missing-columns'
    }

    $result = Invoke-PpdsMigration -Arguments $cliArgs
    if ($PassThru) {
        return $result
    }
}
