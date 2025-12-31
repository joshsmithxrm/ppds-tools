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

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'data', 'import'
        '--data', (Resolve-Path $DataPath).Path
        '--json'  # Always use JSON for progress parsing
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

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and parse progress
    $importResult = [PSCustomObject]@{
        RecordsProcessed = 0
        RecordsFailed    = 0
        Duration         = [TimeSpan]::Zero
    }
    $errorOutput = @()
    $currentTier = -1

    & $cliPath @cliArgs 2>&1 | ForEach-Object {
        $line = $_

        # Check if it's a JSON progress line
        if ($line -match '^\s*\{') {
            try {
                $progress = $line | ConvertFrom-Json

                switch ($progress.phase) {
                    'analyzing' {
                        Write-Verbose $progress.message
                    }
                    'import' {
                        if ($null -ne $progress.tier -and $progress.tier -ne $currentTier) {
                            $currentTier = $progress.tier
                            Write-Verbose "Processing tier $currentTier"
                        }

                        if ($progress.entity -and $progress.total -gt 0) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            $status = "$($progress.current)/$($progress.total)"
                            if ($progress.rps) {
                                $status += " @ $([math]::Round($progress.rps, 1)) rps"
                            }
                            Write-Progress -Activity "Importing $($progress.entity)" `
                                -PercentComplete $percent `
                                -Status $status
                        }
                        elseif ($progress.message) {
                            Write-Verbose $progress.message
                        }
                    }
                    'deferred' {
                        if ($progress.entity -and $progress.field) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            Write-Progress -Activity "Updating deferred field: $($progress.entity).$($progress.field)" `
                                -PercentComplete $percent `
                                -Status "$($progress.current)/$($progress.total)"
                        }
                    }
                    'complete' {
                        Write-Progress -Activity "Import complete" -Completed
                        $importResult.RecordsProcessed = $progress.recordsProcessed
                        $importResult.RecordsFailed = $progress.errors
                        if ($progress.duration) {
                            $importResult.Duration = [TimeSpan]::Parse($progress.duration)
                        }
                        Write-Verbose "Completed in $($progress.duration). Records: $($progress.recordsProcessed), Errors: $($progress.errors)"
                    }
                    'error' {
                        $errorOutput += $progress.message
                    }
                }
            }
            catch {
                # Not valid JSON, treat as regular output
                Write-Verbose $line
            }
        }
        else {
            # Regular output
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                $errorOutput += $line.ToString()
            }
            else {
                Write-Verbose $line
            }
        }
    }

    # Check exit code
    if ($LASTEXITCODE -eq 2) {
        # Complete failure
        $errorMessage = if ($errorOutput.Count -gt 0) {
            $errorOutput -join "`n"
        }
        else {
            "Import failed with exit code $LASTEXITCODE"
        }
        throw $errorMessage
    }
    elseif ($LASTEXITCODE -eq 1) {
        # Partial success
        Write-Warning "Import completed with some failures. $($importResult.RecordsFailed) records failed."
    }

    Write-Progress -Activity "Import" -Completed

    if ($PassThru) {
        return $importResult
    }
}
