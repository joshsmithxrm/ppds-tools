# PPDS Migration CLI & PowerShell Design

**Status:** Design
**Created:** December 19, 2025
**Purpose:** CLI tool and PowerShell cmdlets for Dataverse data migration

---

## Overview

This document covers the tooling layer for PPDS Migration:

1. **PPDS.Migration.Cli** - .NET CLI tool (`ppds-migrate`)
2. **PowerShell Cmdlets** - Wrappers in PPDS.Tools module

Both consume the `PPDS.Migration` NuGet package from the SDK repo.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         tools/ repository                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    PPDS.Migration.Cli                       │ │
│  │                    ──────────────────                       │ │
│  │  .NET Tool (dotnet tool install ppds-migrate)              │ │
│  │                                                             │ │
│  │  Commands:                                                  │ │
│  │  - ppds-migrate export                                      │ │
│  │  - ppds-migrate import                                      │ │
│  │  - ppds-migrate analyze                                     │ │
│  │  - ppds-migrate migrate                                     │ │
│  │                                                             │ │
│  │  References: PPDS.Migration (NuGet)                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      PPDS.Tools                             │ │
│  │                      ──────────                             │ │
│  │  PowerShell Module                                          │ │
│  │                                                             │ │
│  │  Migration Cmdlets (wrap CLI):                              │ │
│  │  - Export-DataverseData                                     │ │
│  │  - Import-DataverseData                                     │ │
│  │  - Get-DataverseDependencyGraph                             │ │
│  │  - Invoke-DataverseMigration                                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ references
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         sdk/ repository                          │
│  ┌─────────────────┐  ┌─────────────────┐                       │
│  │ PPDS.Dataverse  │◄─│ PPDS.Migration  │                       │
│  │   (NuGet)       │  │    (NuGet)      │                       │
│  └─────────────────┘  └─────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
tools/
├── src/
│   ├── PPDS.Tools/                      # Existing PowerShell module
│   │   ├── PPDS.Tools.psd1
│   │   ├── PPDS.Tools.psm1
│   │   └── Public/
│   │       ├── ... (existing cmdlets)
│   │       └── Migration/               # NEW
│   │           ├── Export-DataverseData.ps1
│   │           ├── Import-DataverseData.ps1
│   │           ├── Get-DataverseDependencyGraph.ps1
│   │           └── Invoke-DataverseMigration.ps1
│   │
│   └── PPDS.Migration.Cli/              # NEW - .NET CLI tool
│       ├── PPDS.Migration.Cli.csproj
│       ├── Program.cs
│       └── Commands/
│           ├── ExportCommand.cs
│           ├── ImportCommand.cs
│           ├── AnalyzeCommand.cs
│           └── MigrateCommand.cs
│
├── tests/
│   └── PPDS.Migration.Cli.Tests/        # NEW
│
└── docs/
    └── design/
        └── MIGRATION_CLI_DESIGN.md      # This file
```

---

## PPDS.Migration.Cli

### Project Configuration

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>PPDS.Migration.Cli</RootNamespace>
    <AssemblyName>ppds-migrate</AssemblyName>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>

    <!-- .NET Tool Configuration -->
    <PackAsTool>true</PackAsTool>
    <ToolCommandName>ppds-migrate</ToolCommandName>
    <PackageId>PPDS.Migration.Cli</PackageId>
    <Version>1.0.0</Version>
    <Authors>Josh Smith</Authors>
    <Description>High-performance Dataverse data migration CLI tool</Description>
    <PackageTags>dataverse;dynamics365;powerplatform;migration;cmt;cli</PackageTags>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PPDS.Migration" Version="1.0.*" />
    <PackageReference Include="System.CommandLine" Version="2.0.0-beta4.*" />
  </ItemGroup>
</Project>
```

### Commands

#### Export Command

```bash
ppds-migrate export [options]

Options:
  --connection <string>     Dataverse connection string (required)
  --schema <path>           Path to schema.xml file (required)
  --output <path>           Output ZIP file path (required)
  --parallel <int>          Degree of parallelism (default: CPU count * 2)
  --page-size <int>         FetchXML page size (default: 5000)
  --include-files           Export file attachments
  --json                    Output progress as JSON (for tool integration)
  -v, --verbose             Verbose output
  -h, --help                Show help
```

#### Import Command

```bash
ppds-migrate import [options]

Options:
  --connection <string>     Dataverse connection string (required)
  --data <path>             Path to data.zip file (required)
  --batch-size <int>        Records per batch (default: 1000)
  --bypass-plugins          Bypass custom plugin execution
  --bypass-flows            Bypass Power Automate flows
  --continue-on-error       Continue on individual record failures
  --mode <mode>             Import mode: Create, Update, Upsert (default: Upsert)
  --json                    Output progress as JSON
  -v, --verbose             Verbose output
  -h, --help                Show help
```

#### Analyze Command

```bash
ppds-migrate analyze [options]

Options:
  --schema <path>           Path to schema.xml file (required)
  --output-format <format>  Output format: text, json (default: text)
  -h, --help                Show help
```

**Output (text):**
```
Schema Analysis
===============
Entities: 15
Dependencies: 23
Circular References: 1

Import Tiers:
  Tier 0: currency, subject, uomschedule
  Tier 1: businessunit, uom
  Tier 2: systemuser, team
  Tier 3: account, contact (circular)

Deferred Fields:
  account.primarycontactid -> contact

Many-to-Many Relationships:
  accountleads_association (account <-> lead)
```

**Output (json):**
```json
{
  "entityCount": 15,
  "dependencyCount": 23,
  "circularReferenceCount": 1,
  "tiers": [
    { "tier": 0, "entities": ["currency", "subject", "uomschedule"] },
    { "tier": 1, "entities": ["businessunit", "uom"] },
    { "tier": 2, "entities": ["systemuser", "team"] },
    { "tier": 3, "entities": ["account", "contact"] }
  ],
  "deferredFields": {
    "account": ["primarycontactid"]
  },
  "manyToManyRelationships": ["accountleads_association"]
}
```

#### Migrate Command

```bash
ppds-migrate migrate [options]

Options:
  --source-connection <string>  Source Dataverse connection string (required)
  --target-connection <string>  Target Dataverse connection string (required)
  --schema <path>               Path to schema.xml file (required)
  --temp-dir <path>             Temporary directory for data file (default: system temp)
  --batch-size <int>            Records per batch (default: 1000)
  --bypass-plugins              Bypass custom plugin execution on target
  --json                        Output progress as JSON
  -v, --verbose                 Verbose output
  -h, --help                    Show help
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Partial success (some records failed, but operation completed) |
| 2 | Failure (operation could not complete) |
| 3 | Invalid arguments |

### Progress Output (JSON)

When `--json` flag is used, progress is output as JSON lines (one per line):

```json
{"phase":"analyzing","message":"Parsing schema...","timestamp":"2025-12-19T10:30:00Z"}
{"phase":"analyzing","message":"Building dependency graph...","timestamp":"2025-12-19T10:30:01Z"}
{"phase":"export","entity":"account","current":450,"total":1000,"rps":287.5,"timestamp":"2025-12-19T10:30:15Z"}
{"phase":"export","entity":"contact","current":230,"total":500,"rps":312.1,"timestamp":"2025-12-19T10:30:16Z"}
{"phase":"import","tier":0,"entity":"currency","current":5,"total":5,"rps":45.2,"timestamp":"2025-12-19T10:31:00Z"}
{"phase":"deferred","entity":"account","field":"primarycontactid","current":450,"total":1000,"timestamp":"2025-12-19T10:35:00Z"}
{"phase":"complete","duration":"00:05:23","recordsProcessed":1505,"errors":0,"timestamp":"2025-12-19T10:35:23Z"}
```

---

## PowerShell Cmdlets

### Export-DataverseData

```powershell
Export-DataverseData
    -Connection <string>
    -SchemaPath <string>
    -OutputPath <string>
    [-Parallel <int>]
    [-PageSize <int>]
    [-IncludeFiles]
    [-PassThru]

# Example
Export-DataverseData `
    -Connection "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=xxx;ClientSecret=xxx" `
    -SchemaPath "./schema.xml" `
    -OutputPath "./data.zip" `
    -Parallel 8 `
    -Verbose
```

### Import-DataverseData

```powershell
Import-DataverseData
    -Connection <string>
    -DataPath <string>
    [-BatchSize <int>]
    [-BypassPlugins]
    [-BypassFlows]
    [-ContinueOnError]
    [-Mode <string>]  # Create, Update, Upsert
    [-PassThru]

# Example
Import-DataverseData `
    -Connection "AuthType=ClientSecret;..." `
    -DataPath "./data.zip" `
    -BatchSize 1000 `
    -BypassPlugins `
    -ContinueOnError `
    -Verbose
```

### Get-DataverseDependencyGraph

```powershell
Get-DataverseDependencyGraph
    -SchemaPath <string>
    [-AsJson]

# Example
$graph = Get-DataverseDependencyGraph -SchemaPath "./schema.xml"
$graph.Tiers | Format-Table

# JSON output for scripting
$json = Get-DataverseDependencyGraph -SchemaPath "./schema.xml" -AsJson
$data = $json | ConvertFrom-Json
```

### Invoke-DataverseMigration

```powershell
Invoke-DataverseMigration
    -SourceConnection <string>
    -TargetConnection <string>
    -SchemaPath <string>
    [-BatchSize <int>]
    [-BypassPlugins]
    [-PassThru]

# Example
Invoke-DataverseMigration `
    -SourceConnection "AuthType=ClientSecret;Url=https://source.crm.dynamics.com;..." `
    -TargetConnection "AuthType=ClientSecret;Url=https://target.crm.dynamics.com;..." `
    -SchemaPath "./schema.xml" `
    -BypassPlugins `
    -Verbose
```

### Implementation Pattern

PowerShell cmdlets wrap the CLI tool:

```powershell
function Export-DataverseData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Connection,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [int]$Parallel = 0,

        [int]$PageSize = 5000,

        [switch]$IncludeFiles,

        [switch]$PassThru
    )

    $cliPath = Get-PpdsMigrateCli  # Helper to find/install CLI

    $args = @(
        'export'
        '--connection', $Connection
        '--schema', $SchemaPath
        '--output', $OutputPath
        '--json'  # Always use JSON for parsing
    )

    if ($Parallel -gt 0) { $args += '--parallel', $Parallel }
    if ($PageSize -ne 5000) { $args += '--page-size', $PageSize }
    if ($IncludeFiles) { $args += '--include-files' }

    $result = & $cliPath @args 2>&1 | ForEach-Object {
        if ($_ -match '^\{') {
            $progress = $_ | ConvertFrom-Json
            Write-Progress -Activity "Exporting $($progress.entity)" `
                -PercentComplete (($progress.current / $progress.total) * 100) `
                -Status "$($progress.current)/$($progress.total) @ $($progress.rps) rps"
        }
        $_
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Export failed with exit code $LASTEXITCODE"
    }

    if ($PassThru) {
        Get-Item $OutputPath
    }
}
```

---

## Installation

### CLI Tool

```bash
# Global install
dotnet tool install --global PPDS.Migration.Cli

# Local install (in project)
dotnet tool install PPDS.Migration.Cli

# Verify
ppds-migrate --version
```

### PowerShell Module

```powershell
# From PowerShell Gallery
Install-Module PPDS.Tools

# Import
Import-Module PPDS.Tools

# Verify
Get-Command -Module PPDS.Tools -Name *Dataverse*
```

---

## Implementation Prompts

### Prompt: CLI Project Setup

```
Create the PPDS.Migration.Cli project in the tools repository.

## Context
- Repository: C:\VS\ppds\tools
- Branch: feature/migration-cli
- Design doc: docs/design/MIGRATION_CLI_DESIGN.md

## Requirements

1. Create project structure:
   ```
   src/PPDS.Migration.Cli/
   ├── PPDS.Migration.Cli.csproj
   ├── Program.cs
   └── Commands/
       ├── ExportCommand.cs
       ├── ImportCommand.cs
       ├── AnalyzeCommand.cs
       └── MigrateCommand.cs
   ```

2. Configure as .NET tool (see design doc for csproj settings)

3. Use System.CommandLine for argument parsing

4. Implement Program.cs with root command and subcommands

5. Create placeholder command classes with argument definitions

Do NOT implement command logic yet - just scaffolding and argument parsing.
The actual logic will come from PPDS.Migration NuGet package (not yet published).
```

### Prompt: CLI Command Implementation

```
Implement the CLI commands for PPDS.Migration.Cli.

## Context
- Repository: C:\VS\ppds\tools
- Project: src/PPDS.Migration.Cli
- Design doc: docs/design/MIGRATION_CLI_DESIGN.md
- Depends on: PPDS.Migration NuGet package (from SDK repo)

## Requirements

1. Implement ExportCommand.cs:
   - Parse connection string, schema path, output path
   - Configure ExportOptions from CLI arguments
   - Create IExporter via DI
   - Use JsonProgressReporter when --json flag set
   - Handle cancellation (Ctrl+C)
   - Return appropriate exit codes

2. Implement ImportCommand.cs:
   - Similar pattern to export
   - Configure ImportOptions from CLI arguments
   - Create IImporter via DI

3. Implement AnalyzeCommand.cs:
   - Parse schema only (no Dataverse connection needed)
   - Output dependency graph in text or JSON format

4. Implement MigrateCommand.cs:
   - Combine export + import
   - Use temp file for intermediate data.zip
   - Clean up temp file on completion

## Error Handling
- Catch and log exceptions
- Return exit code 2 on failure
- Return exit code 1 on partial success (some records failed)
```

### Prompt: PowerShell Cmdlets

```
Implement PowerShell cmdlets for Dataverse migration in PPDS.Tools.

## Context
- Repository: C:\VS\ppds\tools
- Module: src/PPDS.Tools
- Design doc: docs/design/MIGRATION_CLI_DESIGN.md
- Depends on: ppds-migrate CLI tool

## Requirements

1. Create cmdlet files in src/PPDS.Tools/Public/Migration/:
   - Export-DataverseData.ps1
   - Import-DataverseData.ps1
   - Get-DataverseDependencyGraph.ps1
   - Invoke-DataverseMigration.ps1

2. Each cmdlet should:
   - Have full parameter documentation
   - Validate required parameters
   - Find or prompt to install ppds-migrate CLI
   - Pass --json flag and parse progress for Write-Progress
   - Support -Verbose for detailed output
   - Throw on non-zero exit codes
   - Support -PassThru where appropriate

3. Create helper function Get-PpdsMigrateCli:
   - Check if ppds-migrate is available
   - Offer to install if missing
   - Return path to CLI executable

4. Update PPDS.Tools.psd1 to export new cmdlets
```

---

## Dependencies

| Component | Depends On | Notes |
|-----------|------------|-------|
| PPDS.Migration.Cli | PPDS.Migration (NuGet) | Must wait for SDK package to publish |
| PowerShell Cmdlets | ppds-migrate CLI | Wrapper pattern |

## Implementation Order

1. **SDK First:** Implement PPDS.Dataverse and PPDS.Migration in SDK repo
2. **Publish NuGet:** Publish PPDS.Migration to NuGet.org (or local feed for testing)
3. **CLI Tool:** Implement PPDS.Migration.Cli referencing NuGet package
4. **PowerShell:** Implement cmdlet wrappers

---

## Related Documents

- SDK Design: `C:\VS\ppds\sdk\docs\design\` (on `feature/dataverse-packages` branch)
  - 00_PACKAGE_STRATEGY.md
  - 01_PPDS_DATAVERSE_DESIGN.md
  - 02_PPDS_MIGRATION_DESIGN.md
  - 03_IMPLEMENTATION_PROMPTS.md
