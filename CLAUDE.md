# CLAUDE.md - ppds-tools

**PowerShell module for Dataverse plugin deployment and automation.**

---

## Project Overview

This repository contains the PPDS.Tools PowerShell module, providing cmdlets for plugin extraction, deployment, and drift detection.

**Part of the PPDS Ecosystem** - See `C:\VS\ppds\CLAUDE.md` for cross-project context.

---

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| PowerShell | 7.0+ | Required runtime |
| Pester | 5.0+ | Testing framework |
| PowerShell Gallery | - | Module distribution |

---

## Project Structure

```
ppds-tools/
├── src/
│   └── PPDS.Tools/
│       ├── PPDS.Tools.psd1       # Module manifest
│       ├── PPDS.Tools.psm1       # Root module
│       ├── Public/               # Exported cmdlets
│       │   ├── Auth/
│       │   │   └── Connect-DataverseEnvironment.ps1
│       │   └── Plugins/
│       │       ├── Get-DataversePluginRegistrations.ps1
│       │       ├── Deploy-DataversePlugins.ps1
│       │       ├── Get-DataversePluginDrift.ps1
│       │       └── Remove-DataverseOrphanedSteps.ps1
│       ├── Private/              # Internal functions
│       └── Schemas/
│           └── plugin-registration.schema.json
├── tests/
│   └── PPDS.Tools.Tests/
├── .github/workflows/
│   ├── test.yml                  # CI tests
│   └── publish-psgallery.yml     # Release → PSGallery
└── CHANGELOG.md
```

---

## Common Commands

```powershell
# Import module for development
Import-Module ./src/PPDS.Tools -Force

# Run tests
Install-Module Pester -Force -Scope CurrentUser
Invoke-Pester ./tests -Output Detailed

# Validate manifest
Test-ModuleManifest ./src/PPDS.Tools/PPDS.Tools.psd1

# Check available commands
Get-Command -Module PPDS.Tools
```

---

## Cmdlet Naming Convention

All cmdlets follow the pattern: `Verb-Dataverse<Noun>`

| Cmdlet | Purpose |
|--------|---------|
| `Connect-DataverseEnvironment` | Establish connection with credentials |
| `Get-DataversePluginRegistrations` | Extract registrations from assembly |
| `Deploy-DataversePlugins` | Deploy plugins to environment |
| `Get-DataversePluginDrift` | Compare config vs environment |
| `Remove-DataverseOrphanedSteps` | Clean up orphaned steps |

---

## Development Workflow

### Adding a New Cmdlet

1. Create file in `Public/[Category]/Verb-DataverseNoun.ps1`
2. Add function name to `FunctionsToExport` in `.psd1`
3. Write Pester tests in `tests/`
4. Update `CHANGELOG.md`

### Module Structure Pattern

```powershell
# Public function template
function Verb-DataverseNoun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequiredParam,

        [Parameter()]
        [switch]$OptionalSwitch
    )

    # Implementation
}
```

---

## Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Protected, always releasable |
| `feature/*` | New features |
| `fix/*` | Bug fixes |

**Merge Strategy:** Squash merge to main

---

## Release Process

1. Update version in `PPDS.Tools.psd1` (`ModuleVersion`)
2. Update `CHANGELOG.md`
3. Merge to `main`
4. Create GitHub Release with tag `vX.Y.Z`
5. `publish-psgallery.yml` workflow automatically publishes to PSGallery

**Required Secret:** `PSGALLERY_API_KEY`

---

## Version Management

Version is in `src/PPDS.Tools/PPDS.Tools.psd1`:
```powershell
@{
    ModuleVersion = '1.0.0'
    # ...
}
```

---

## Testing Patterns

### Pester Test Structure
```powershell
Describe 'Get-DataversePluginRegistrations' {
    BeforeAll {
        Import-Module $PSScriptRoot/../src/PPDS.Tools -Force
    }

    It 'Should extract registrations from valid assembly' {
        # Arrange
        $assemblyPath = './tests/fixtures/TestPlugins.dll'

        # Act
        $result = Get-DataversePluginRegistrations -AssemblyPath $assemblyPath

        # Assert
        $result | Should -Not -BeNullOrEmpty
    }
}
```

---

## Ecosystem Integration

**Depends on:**
- Assemblies using `PPDS.Plugins` attributes (from ppds-sdk)

**Used by:**
- **ppds-alm** - CI/CD templates call these cmdlets
- **ppds-demo** - Example scripts use this module

---

## Key Files

| File | Purpose |
|------|---------|
| `PPDS.Tools.psd1` | Module manifest (version, exports, metadata) |
| `PPDS.Tools.psm1` | Root module (dot-sources Public/Private) |
| `CHANGELOG.md` | Release notes |
| `plugin-registration.schema.json` | JSON schema for registration files |
