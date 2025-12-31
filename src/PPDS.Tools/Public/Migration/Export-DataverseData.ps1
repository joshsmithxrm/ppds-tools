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

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'data', 'export'
        '--schema', (Resolve-Path $SchemaPath).Path
        '--output', $OutputPath
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

    if ($Parallel -gt 0) {
        $cliArgs += '--parallel'
        $cliArgs += $Parallel
    }

    if ($BatchSize -ne 5000) {
        $cliArgs += '--batch-size'
        $cliArgs += $BatchSize
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and parse progress
    $errorOutput = @()

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
                        if ($progress.entity -and $progress.total -gt 0) {
                            $percent = [math]::Min(100, [math]::Round(($progress.current / $progress.total) * 100))
                            $status = "$($progress.current)/$($progress.total)"
                            if ($progress.rps) {
                                $status += " @ $([math]::Round($progress.rps, 1)) rps"
                            }
                            Write-Progress -Activity "Exporting $($progress.entity)" `
                                -PercentComplete $percent `
                                -Status $status
                        }
                        elseif ($progress.message) {
                            Write-Verbose $progress.message
                        }
                    }
                    'complete' {
                        Write-Progress -Activity "Export complete" -Completed
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
    if ($LASTEXITCODE -ne 0) {
        $errorMessage = if ($errorOutput.Count -gt 0) {
            $errorOutput -join "`n"
        }
        else {
            "Export failed with exit code $LASTEXITCODE"
        }
        throw $errorMessage
    }

    Write-Progress -Activity "Export" -Completed

    if ($PassThru) {
        return Get-Item $OutputPath
    }
}
