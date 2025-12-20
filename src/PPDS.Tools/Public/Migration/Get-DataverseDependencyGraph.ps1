function Get-DataverseDependencyGraph {
    <#
    .SYNOPSIS
        Analyzes a schema file and returns dependency graph information.

    .DESCRIPTION
        Parses a schema.xml file and builds a dependency graph showing:
        - Entity count and dependencies
        - Circular reference detection
        - Import tier ordering
        - Deferred fields for circular dependencies
        - Many-to-many relationship mappings

        This is useful for understanding import order before running a migration.

        This cmdlet wraps the ppds-migrate CLI tool.

    .PARAMETER SchemaPath
        Path to the schema.xml file to analyze.

    .PARAMETER AsJson
        Return raw JSON output instead of a parsed object.

    .EXAMPLE
        $graph = Get-DataverseDependencyGraph -SchemaPath "./schema.xml"
        $graph.Tiers | Format-Table

        Analyzes the schema and displays import tiers in a table.

    .EXAMPLE
        Get-DataverseDependencyGraph -SchemaPath "./schema.xml" |
            Select-Object -ExpandProperty DeferredFields

        Shows which fields will be updated in a second pass due to circular dependencies.

    .EXAMPLE
        $json = Get-DataverseDependencyGraph -SchemaPath "./schema.xml" -AsJson
        $json | Out-File "dependency-graph.json"

        Exports the dependency graph as JSON.

    .OUTPUTS
        PSCustomObject with dependency graph information, or String if -AsJson is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter()]
        [switch]$AsJson
    )

    # Validate schema file exists
    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found: $SchemaPath"
    }

    # Get the CLI tool
    $cliPath = Get-PpdsMigrateCli

    # Build arguments
    $cliArgs = @(
        'analyze'
        '--schema', (Resolve-Path $SchemaPath).Path
        '--output-format', 'json'
    )

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and capture output
    $output = & $cliPath @cliArgs 2>&1

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        if ($errorMessage) {
            throw "Analysis failed: $($errorMessage -join "`n")"
        }
        throw "Analysis failed with exit code $LASTEXITCODE"
    }

    # Filter to just JSON output (skip any stderr messages)
    $jsonOutput = $output | Where-Object { $_ -notmatch '^\s*$' -and $_ -match '^\s*[\{\[]' } | Out-String

    if (-not $jsonOutput) {
        # If no JSON found, try the raw output
        $jsonOutput = $output | Out-String
    }

    if ($AsJson) {
        return $jsonOutput.Trim()
    }

    # Parse JSON and return object
    try {
        $data = $jsonOutput | ConvertFrom-Json

        # Build a more PowerShell-friendly object
        return [PSCustomObject]@{
            EntityCount            = $data.entityCount
            DependencyCount        = $data.dependencyCount
            CircularReferenceCount = $data.circularReferenceCount
            Tiers                  = @(
                $data.tiers | ForEach-Object {
                    [PSCustomObject]@{
                        Tier       = $_.tier
                        Entities   = $_.entities
                        HasCircular = [bool]$_.hasCircular
                    }
                }
            )
            DeferredFields         = $data.deferredFields
            ManyToManyRelationships = $data.manyToManyRelationships
            Note                   = $data.note
        }
    }
    catch {
        throw "Failed to parse analysis output: $_`nOutput: $jsonOutput"
    }
}
