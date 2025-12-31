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

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'data', 'copy'
        '--schema', (Resolve-Path $SchemaPath).Path
        '--source-env', $SourceEnvironment
        '--target-env', $TargetEnvironment
        '--json'  # Always use JSON for progress parsing
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

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and parse progress
    $copyResult = [PSCustomObject]@{
        RecordsProcessed = 0
        RecordsFailed    = 0
        Duration         = [TimeSpan]::Zero
    }
    $errorOutput = @()
    $currentPhase = 'starting'

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
                    'export' {
                        if ($currentPhase -ne 'export') {
                            $currentPhase = 'export'
                            Write-Verbose "Starting export phase..."
                        }

                        if ($progress.entity -and $progress.total -gt 0) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            $status = "$($progress.current)/$($progress.total)"
                            if ($progress.rps) {
                                $status += " @ $([math]::Round($progress.rps, 1)) rps"
                            }
                            Write-Progress -Activity "Exporting $($progress.entity)" `
                                -PercentComplete $percent `
                                -Status $status `
                                -Id 1
                        }
                        elseif ($progress.message) {
                            Write-Verbose $progress.message
                        }
                    }
                    'import' {
                        if ($currentPhase -ne 'import') {
                            $currentPhase = 'import'
                            Write-Progress -Activity "Export complete" -Completed -Id 1
                            Write-Verbose "Starting import phase..."
                        }

                        if ($progress.entity -and $progress.total -gt 0) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            $status = "$($progress.current)/$($progress.total)"
                            if ($progress.rps) {
                                $status += " @ $([math]::Round($progress.rps, 1)) rps"
                            }
                            Write-Progress -Activity "Importing $($progress.entity)" `
                                -PercentComplete $percent `
                                -Status $status `
                                -Id 2
                        }
                        elseif ($progress.message) {
                            Write-Verbose $progress.message
                        }
                    }
                    'deferred' {
                        if ($progress.entity -and $progress.field) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            Write-Progress -Activity "Updating deferred: $($progress.entity).$($progress.field)" `
                                -PercentComplete $percent `
                                -Status "$($progress.current)/$($progress.total)" `
                                -Id 2
                        }
                    }
                    'complete' {
                        Write-Progress -Activity "Copy complete" -Completed -Id 1
                        Write-Progress -Activity "Copy complete" -Completed -Id 2
                        $copyResult.RecordsProcessed = $progress.recordsProcessed
                        $copyResult.RecordsFailed = $progress.errors
                        if ($progress.duration) {
                            $copyResult.Duration = [TimeSpan]::Parse($progress.duration)
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
            "Copy failed with exit code $LASTEXITCODE"
        }
        throw $errorMessage
    }
    elseif ($LASTEXITCODE -eq 1) {
        # Partial success
        Write-Warning "Copy completed with some failures. $($copyResult.RecordsFailed) records failed."
    }

    Write-Progress -Activity "Copy" -Completed -Id 1
    Write-Progress -Activity "Copy" -Completed -Id 2

    if ($PassThru) {
        return $copyResult
    }
}
