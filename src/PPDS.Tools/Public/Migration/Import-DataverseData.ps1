function Import-DataverseData {
    <#
    .SYNOPSIS
        Imports data from a ZIP file into a Dataverse environment.

    .DESCRIPTION
        Imports data into Dataverse from a previously exported data file.
        Handles dependency ordering, circular references, and many-to-many relationships.
        Supports bypass of plugins and flows for performance.

        This cmdlet wraps the ppds-migrate CLI tool.

    .PARAMETER Connection
        Dataverse connection string. Supports multiple authentication types:
        - AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx
        - AuthType=OAuth;Url=https://org.crm.dynamics.com;...

    .PARAMETER DataPath
        Path to the data.zip file containing exported data.

    .PARAMETER BatchSize
        Records per batch for ExecuteMultiple requests.
        Default: 1000

    .PARAMETER BypassPlugins
        Bypass custom plugin execution during import.
        Requires appropriate privileges in the target environment.

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

    .PARAMETER PassThru
        Return an import result object with statistics.

    .EXAMPLE
        Import-DataverseData `
            -Connection "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx" `
            -DataPath "./data.zip"

        Imports data using default settings (Upsert mode, 1000 batch size).

    .EXAMPLE
        Import-DataverseData `
            -Connection $connString `
            -DataPath "./data.zip" `
            -BatchSize 500 `
            -BypassPlugins `
            -ContinueOnError `
            -Verbose

        Imports with smaller batches, bypasses plugins, and continues on errors.

    .OUTPUTS
        None by default. PSCustomObject with import statistics if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Connection,

        [Parameter(Mandatory)]
        [string]$DataPath,

        [Parameter()]
        [int]$BatchSize = 1000,

        [Parameter()]
        [switch]$BypassPlugins,

        [Parameter()]
        [switch]$BypassFlows,

        [Parameter()]
        [switch]$ContinueOnError,

        [Parameter()]
        [ValidateSet('Create', 'Update', 'Upsert')]
        [string]$Mode = 'Upsert',

        [Parameter()]
        [switch]$PassThru
    )

    # Validate data file exists
    if (-not (Test-Path $DataPath)) {
        throw "Data file not found: $DataPath"
    }

    # Get the CLI tool
    $cliPath = Get-PpdsMigrateCli

    # Build arguments
    $cliArgs = @(
        'import'
        '--connection', $Connection
        '--data', (Resolve-Path $DataPath).Path
        '--json'  # Always use JSON for progress parsing
    )

    if ($BatchSize -ne 1000) {
        $cliArgs += '--batch-size'
        $cliArgs += $BatchSize
    }

    if ($BypassPlugins) {
        $cliArgs += '--bypass-plugins'
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
