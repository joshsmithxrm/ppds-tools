# PPDS Tools

PowerShell module for Dataverse plugin deployment and data migration. All cmdlets wrap the `ppds` CLI.

## NEVER

- Use `powershell.exe` - use `pwsh` (PowerShell 7+ required)
- Skip `[CmdletBinding()]` on public functions - breaks common parameters
- Call `Write-Host` directly in public cmdlets - breaks pipeline; return objects, and log via `Write-Log` (private helper; `Write-Host` is allowed only inside private helpers, `PSAvoidUsingWriteHost` is excluded in analyzer settings)
- Skip Pester tests for new cmdlets - all public cmdlets must have tests
- Use non-approved verbs - PowerShell standards require approved verbs

## ALWAYS

- Cmdlet naming: `Verb-Dataverse<Noun>` - consistent naming
- `[CmdletBinding()]` on all public functions - enables common parameters
- `[Parameter(Mandatory)]` for required params - clear contract
- Return objects, not formatted strings - pipeline compatibility
- Update `FunctionsToExport` in `.psd1` - new cmdlets must be exported

## Cmdlets

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

## Commands

| Command | Purpose |
|---------|---------|
| `Import-Module ./src/PPDS.Tools -Force` | Load for development |
| `Invoke-Pester ./tests -Output Detailed` | Run tests |
| `Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` | Lint (as CI runs it) |
| `Test-ModuleManifest ./src/PPDS.Tools/PPDS.Tools.psd1` | Validate manifest |

## Key Files

- `src/PPDS.Tools/PPDS.Tools.psd1` - Module manifest (version, exports)
- `src/PPDS.Tools/Public/` - Exported cmdlets
- `tests/` - Pester 5 tests
- `docs/adr/0001_CLI_WRAPPER_PATTERN.md` - Why we wrap CLI

## See Also

- `Get-Command -Module PPDS.Tools` - List all cmdlets
- `docs/adr/` - Architecture Decision Records
