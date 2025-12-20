function Invoke-DataverseMigration {
    <#
    .SYNOPSIS
        Migrates data from one Dataverse environment to another.

    .DESCRIPTION
        Performs a complete data migration from a source to target Dataverse environment.
        This combines export and import into a single operation:
        1. Exports data from source environment to a temporary file
        2. Imports data into target environment
        3. Cleans up temporary file

        Use this for environment-to-environment migrations.

        This cmdlet wraps the ppds-migrate CLI tool.

    .PARAMETER SourceConnection
        Connection string for the source Dataverse environment.

    .PARAMETER TargetConnection
        Connection string for the target Dataverse environment.

    .PARAMETER SchemaPath
        Path to the schema.xml file defining entities to migrate.

    .PARAMETER BatchSize
        Records per batch for import operations.
        Default: 1000

    .PARAMETER BypassPlugins
        Bypass custom plugin execution on the target environment.

    .PARAMETER PassThru
        Return a migration result object with statistics.

    .EXAMPLE
        Invoke-DataverseMigration `
            -SourceConnection "AuthType=ClientSecret;Url=https://source.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx" `
            -TargetConnection "AuthType=ClientSecret;Url=https://target.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx" `
            -SchemaPath "./schema.xml"

        Migrates data from source to target environment.

    .EXAMPLE
        $result = Invoke-DataverseMigration `
            -SourceConnection $sourceConn `
            -TargetConnection $targetConn `
            -SchemaPath "./schema.xml" `
            -BypassPlugins `
            -PassThru

        Migrates with plugin bypass and returns statistics.

    .OUTPUTS
        None by default. PSCustomObject with migration statistics if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceConnection,

        [Parameter(Mandatory)]
        [string]$TargetConnection,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter()]
        [int]$BatchSize = 1000,

        [Parameter()]
        [switch]$BypassPlugins,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate schema file exists
    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found: $SchemaPath"
    }

    # Get the CLI tool
    $cliPath = Get-PpdsMigrateCli

    # Build arguments
    $cliArgs = @(
        'migrate'
        '--source-connection', $SourceConnection
        '--target-connection', $TargetConnection
        '--schema', (Resolve-Path $SchemaPath).Path
        '--json'  # Always use JSON for progress parsing
    )

    if ($BatchSize -ne 1000) {
        $cliArgs += '--batch-size'
        $cliArgs += $BatchSize
    }

    if ($BypassPlugins) {
        $cliArgs += '--bypass-plugins'
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and parse progress
    $migrationResult = [PSCustomObject]@{
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
                        Write-Progress -Activity "Migration complete" -Completed -Id 1
                        Write-Progress -Activity "Migration complete" -Completed -Id 2
                        $migrationResult.RecordsProcessed = $progress.recordsProcessed
                        $migrationResult.RecordsFailed = $progress.errors
                        if ($progress.duration) {
                            $migrationResult.Duration = [TimeSpan]::Parse($progress.duration)
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
            "Migration failed with exit code $LASTEXITCODE"
        }
        throw $errorMessage
    }
    elseif ($LASTEXITCODE -eq 1) {
        # Partial success
        Write-Warning "Migration completed with some failures. $($migrationResult.RecordsFailed) records failed."
    }

    Write-Progress -Activity "Migration" -Completed -Id 1
    Write-Progress -Activity "Migration" -Completed -Id 2

    if ($PassThru) {
        return $migrationResult
    }
}
