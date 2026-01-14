# PPDS Tools

PowerShell module for Dataverse plugin deployment and data migration. All cmdlets wrap the `ppds` CLI.

## NEVER

- Use `powershell.exe` - use `pwsh` (PowerShell 7+ required)
- Skip `[CmdletBinding()]` on public functions - breaks common parameters
- Use `Write-Host` for output - breaks pipeline; use `Write-Output`
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
| `Deploy-DataversePlugins` | `ppds plugins deploy` |
| `Get-DataversePluginDrift` | `ppds plugins diff` |
| `Export-DataverseData` | `ppds data export` |
| `Import-DataverseData` | `ppds data import` |

## Commands

| Command | Purpose |
|---------|---------|
| `Import-Module ./src/PPDS.Tools -Force` | Load for development |
| `Invoke-Pester ./tests -Output Detailed` | Run tests |
| `Test-ModuleManifest ./src/PPDS.Tools/PPDS.Tools.psd1` | Validate manifest |

## Key Files

- `src/PPDS.Tools/PPDS.Tools.psd1` - Module manifest (version, exports)
- `src/PPDS.Tools/Public/` - Exported cmdlets
- `tests/` - Pester 5 tests
- `docs/adr/0001_CLI_WRAPPER_PATTERN.md` - Why we wrap CLI

## See Also

- `Get-Command -Module PPDS.Tools` - List all cmdlets
- `docs/adr/` - Architecture Decision Records
