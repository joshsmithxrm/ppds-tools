# ADR-0001: CLI Wrapper Pattern for Migration Cmdlets

**Status:** Accepted
**Applies to:** PPDS.Tools migration cmdlets

## Context

The PPDS.Migration library (in the SDK repo) provides high-performance Dataverse data migration capabilities. We needed to expose this functionality in PPDS.Tools PowerShell module.

Two approaches were considered:

1. **Direct .NET reference** - Reference PPDS.Migration NuGet package directly from PowerShell
2. **CLI wrapper** - Wrap the `ppds-migrate` CLI tool

## Decision

Wrap the `ppds-migrate` CLI tool rather than referencing PPDS.Migration directly.

```powershell
# Migration cmdlets shell out to the CLI
$result = & ppds-migrate export --connection $conn --schema $schema --json
```

## Consequences

### Positive

- **Clean process boundary** - No .NET assembly loading conflicts in PowerShell
- **Simpler dependency management** - CLI is a single tool install, not NuGet packages
- **JSON progress parsing** - CLI's `--json` flag provides structured output that maps cleanly to `Write-Progress`
- **Consistent behavior** - Same code path whether user runs CLI directly or via PowerShell
- **Independent versioning** - Can update CLI without republishing PowerShell module

### Negative

- **Extra dependency** - Users must install `ppds-migrate` CLI tool
- **Process overhead** - Shell execution has more overhead than direct .NET calls
- **Error handling** - Must parse exit codes and stderr instead of catching exceptions

### Mitigations

- `Get-PpdsMigrateCli` helper auto-detects or offers to install the CLI
- Exit codes are well-defined (0=success, 1=partial, 2=failure, 3=invalid args)
- JSON output includes error details for parsing

## Alternatives Considered

### Direct NuGet Reference

```powershell
# Would require loading .NET assemblies
Add-Type -Path "PPDS.Migration.dll"
$exporter = [PPDS.Migration.DataverseExporter]::new($options)
```

**Rejected because:**
- Assembly loading conflicts with other Dataverse modules
- Complex dependency chain (PPDS.Migration → PPDS.Dataverse → Microsoft.PowerPlatform.Dataverse.Client)
- Version conflicts when multiple modules load different versions

### Embedded .NET Host

**Rejected because:**
- Over-engineered for the use case
- Adds significant complexity
- Same assembly loading issues
