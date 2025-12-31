# ADR-0001: CLI Wrapper Pattern for All Cmdlets

**Status:** Accepted (Updated)
**Applies to:** All PPDS.Tools cmdlets
**Date:** 2025-01-XX (Updated from original migration-only scope)

## Context

The PPDS ecosystem includes both a C# SDK (with CLI) and PowerShell tools. We needed to decide how PPDS.Tools should implement its functionality.

Two approaches were considered:

1. **Native implementation** - Implement Dataverse operations directly in PowerShell using OAuth and Web API
2. **CLI wrapper** - Wrap the unified `ppds` CLI tool

Originally (v1.x), we used a hybrid approach:
- Migration cmdlets wrapped the CLI
- Plugin cmdlets used native implementation

This led to maintenance burden and feature parity issues.

## Decision

**All cmdlets wrap the `ppds` CLI tool.** No native Dataverse implementation in PowerShell.

```powershell
# All cmdlets shell out to the CLI
$cliPath = Get-PpdsCli
& $cliPath plugins deploy --config $config --profile $profile --json
```

### Cmdlet-to-CLI Mapping

| Cmdlet | CLI Command |
|--------|-------------|
| `Connect-DataverseEnvironment` | `ppds auth create` |
| `Get-DataverseProfile` | `ppds auth who` |
| `Get-DataverseProfiles` | `ppds auth list` |
| `Get-DataversePluginRegistrations` | `ppds plugins extract` |
| `Deploy-DataversePlugins` | `ppds plugins deploy` |
| `Get-DataversePluginDrift` | `ppds plugins diff` |
| `Remove-DataverseOrphanedSteps` | `ppds plugins clean` |
| `Get-DataversePlugins` | `ppds plugins list` |
| `Export-DataverseData` | `ppds data export` |
| `Import-DataverseData` | `ppds data import` |
| `Copy-DataverseData` | `ppds data copy` |
| `Get-DataverseDependencyGraph` | `ppds data analyze` |

## Consequences

### Positive

- **Single source of truth** - CLI is the implementation, PowerShell is an interface
- **Feature parity guaranteed** - CLI updates automatically benefit PowerShell users
- **Reduced maintenance** - Fix bugs once in CLI, not twice
- **Clean process boundary** - No .NET assembly loading conflicts in PowerShell
- **Simpler dependency** - CLI is a single tool install
- **Consistent behavior** - Same code path whether user runs CLI or PowerShell

### Negative

- **CLI dependency** - Users must install `ppds` CLI tool
- **Process overhead** - Shell execution has more overhead than direct .NET calls
- **Error handling** - Must parse exit codes and stderr instead of catching exceptions

### Mitigations

- `Get-PpdsCli` helper auto-detects or offers to install the CLI
- Exit codes are well-defined (0=success, 1=partial, 2=failure)
- JSON output includes error details for parsing
- PowerShell adds value through:
  - Parameter validation and transformation
  - `Write-Progress` integration
  - Pipeline support
  - PowerShell idioms (`-WhatIf`, `-Verbose`)

## Alternatives Considered

### Native PowerShell Implementation

```powershell
# Direct Dataverse API calls
$token = Get-OAuthToken -TenantId $tenant -ClientId $appId ...
$response = Invoke-RestMethod -Uri "$env/api/data/v9.2/pluginassemblies" -Headers @{ Authorization = "Bearer $token" }
```

**Rejected because:**
- Duplicates CLI implementation (maintenance burden)
- Features lag behind CLI
- Two codebases to test and maintain
- Assembly loading conflicts with Dataverse PowerShell SDK

### Hybrid Approach (v1.x)

**Rejected because:**
- Inconsistent user experience (some cmdlets need `-Connection`, others need `-Profile`)
- Native implementation required separate OAuth, Web API, and reflection code
- Maintenance of ~1000 lines of native PowerShell code

## Migration from v1.x

v2.0 is a breaking change from v1.x:
- `DataverseConnection` class removed
- `-Connection` parameters replaced with `-Profile` and `-Environment`
- All cmdlets now require the `ppds` CLI tool

See CHANGELOG.md for full migration guide.
