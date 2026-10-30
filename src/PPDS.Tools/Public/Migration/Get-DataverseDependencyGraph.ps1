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

        This cmdlet wraps the ppds CLI tool.

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

    $cliArgs = @('data', 'analyze', '--schema', (Resolve-Path $SchemaPath).Path)
    return Invoke-PpdsCli -Arguments $cliArgs -Json -AsJson:$AsJson
}
