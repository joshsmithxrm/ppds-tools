function Export-DataverseData {
    <#
    .SYNOPSIS
        Exports data from a Dataverse environment to a ZIP file.

    .DESCRIPTION
        Exports data from Dataverse based on a schema definition file.
        Uses parallel processing for high-performance data extraction.
        Supports file attachments and provides progress reporting.

        This cmdlet wraps the ppds-migrate CLI tool.

    .PARAMETER Connection
        Dataverse connection string. Supports multiple authentication types:
        - AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx
        - AuthType=OAuth;Url=https://org.crm.dynamics.com;...

    .PARAMETER SchemaPath
        Path to the schema.xml file that defines entities and relationships to export.

    .PARAMETER OutputPath
        Path for the output ZIP file containing exported data.

    .PARAMETER Parallel
        Degree of parallelism for concurrent entity exports.
        Default: CPU count * 2

    .PARAMETER PageSize
        FetchXML page size for data retrieval.
        Default: 5000

    .PARAMETER IncludeFiles
        Include file attachments (notes, annotations) in the export.

    .PARAMETER PassThru
        Return the output file as a FileInfo object.

    .EXAMPLE
        Export-DataverseData `
            -Connection "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx" `
            -SchemaPath "./schema.xml" `
            -OutputPath "./data.zip"

        Exports data from Dataverse to data.zip using the schema definition.

    .EXAMPLE
        $file = Export-DataverseData `
            -Connection $connString `
            -SchemaPath "./schema.xml" `
            -OutputPath "./data.zip" `
            -Parallel 16 `
            -IncludeFiles `
            -PassThru

        Exports with 16 parallel threads, includes file attachments, and returns the file object.

    .OUTPUTS
        None by default. FileInfo if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Connection,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [int]$Parallel = 0,

        [Parameter()]
        [int]$PageSize = 5000,

        [Parameter()]
        [switch]$IncludeFiles,

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
        'export'
        '--connection', $Connection
        '--schema', (Resolve-Path $SchemaPath).Path
        '--output', $OutputPath
        '--json'  # Always use JSON for progress parsing
    )

    if ($Parallel -gt 0) {
        $cliArgs += '--parallel'
        $cliArgs += $Parallel
    }

    if ($PageSize -ne 5000) {
        $cliArgs += '--page-size'
        $cliArgs += $PageSize
    }

    if ($IncludeFiles) {
        $cliArgs += '--include-files'
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and parse progress
    $errorOutput = @()

    & $cliPath @cliArgs 2>&1 | ForEach-Object {
        $line = $_

        # Check if it's a JSON progress line
        if ($line -match '^\{') {
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
