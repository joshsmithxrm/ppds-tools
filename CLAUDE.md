# CLAUDE.md - ppds-tools

**PowerShell module for Dataverse plugin deployment and automation.**

**Part of the PPDS Ecosystem** - See `../CLAUDE.md` for cross-project context.

**Consumption guidance:** See [CONSUMPTION_PATTERNS.md](../docs/CONSUMPTION_PATTERNS.md) for when consumers should use library vs CLI vs Tools.

---

## 🚫 NEVER

| Rule | Why |
|------|-----|
| Use `powershell.exe` to invoke scripts | Use `pwsh` - module requires PowerShell 7+ |
| Skip `[CmdletBinding()]` on public functions | Breaks common parameters (-Verbose, -Debug, etc.) |
| Use `Write-Host` for output | Breaks pipeline; use `Write-Output` or return objects |
| Hardcode environment URLs | Breaks portability; always accept as parameter |
| Skip Pester tests for new cmdlets | All public cmdlets must have tests |
| Use non-approved verbs | PowerShell standards require approved verbs |

---

## ✅ ALWAYS

| Rule | Why |
|------|-----|
| Cmdlet naming: `Verb-Dataverse<Noun>` | Consistent naming across module |
| `[CmdletBinding()]` on all public functions | Enables common parameters |
| `[Parameter(Mandatory)]` for required params | Clear contract, better errors |
| Return objects, not formatted strings | Pipeline compatibility |
| Mock Dataverse calls in tests | Unit tests shouldn't require live environment |
| Update `FunctionsToExport` in `.psd1` | New cmdlets must be exported |

---

## 💻 Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| PowerShell | 7.0+ | Required runtime |
| Pester | 5.0+ | Testing framework |
| PowerShell Gallery | - | Module distribution |

---

## 📁 Project Structure

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

## 🛠️ Common Commands

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

## 📛 Cmdlet Naming Convention

All cmdlets follow the pattern: `Verb-Dataverse<Noun>`

| Cmdlet | Purpose |
|--------|---------|
| `Connect-DataverseEnvironment` | Establish connection with credentials |
| `Get-DataversePluginRegistrations` | Extract registrations from assembly |
| `Deploy-DataversePlugins` | Deploy plugins to environment |
| `Get-DataversePluginDrift` | Compare config vs environment |
| `Remove-DataverseOrphanedSteps` | Clean up orphaned steps |

---

## 🔄 Development Workflow

### Adding a New Cmdlet

1. Create file in `Public/[Category]/Verb-DataverseNoun.ps1`
2. Add function name to `FunctionsToExport` in `.psd1`
3. Write Pester tests in `tests/`
4. Update `CHANGELOG.md`

### Module Structure Pattern

```powershell
# ✅ Correct - Full CmdletBinding with proper parameters
function Verb-DataverseNoun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequiredParam,

        [Parameter()]
        [switch]$OptionalSwitch
    )

    Write-Verbose "Starting Verb-DataverseNoun"
    # Implementation
}

# ❌ Wrong - Missing CmdletBinding, poor parameter definition
function Verb-DataverseNoun($RequiredParam, $OptionalSwitch) {
    # Implementation
}
```

---

## 📦 Version Management

Version is in `src/PPDS.Tools/PPDS.Tools.psd1`:

```powershell
@{
    ModuleVersion = '1.0.0'
    # ...
}
```

---

## 🔀 Git Branch & Merge Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Protected, always releasable |
| `feature/*` | New features |
| `fix/*` | Bug fixes |

**Merge Strategy:** Squash merge to main

---

## 🚀 Release Process

1. Update version in `PPDS.Tools.psd1` (`ModuleVersion`)
2. Update `CHANGELOG.md`
3. Merge to `main`
4. Create GitHub Release with tag `vX.Y.Z`
5. `publish-psgallery.yml` workflow automatically publishes to PSGallery

**Required Secret:** `PSGALLERY_API_KEY`

---

## 🧪 Testing Patterns

### Pester Test Structure

```powershell
# ✅ Correct - Proper Pester 5 structure with mocking
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

### Testing Requirements

- **Target 80% code coverage**
- Unit tests for all public cmdlets
- Mock Dataverse calls in tests (no live environment required)
- Run `Invoke-Pester ./tests -Output Detailed` before submitting PR

---

## 🔗 Dependencies & Versioning

### This Repo Produces

| Package | Distribution |
|---------|--------------|
| PPDS.Tools | PowerShell Gallery |

### Dependencies

| Dependency | Type | Minimum | Purpose |
|------------|------|---------|---------|
| PPDS.Plugins | Reflection | 1.0.0 | Read `PluginStepAttribute`, `PluginImageAttribute` |
| PPDS.Migration.Cli | Process | 1.0.0 | Migration cmdlets shell to CLI |

### Consumed By

| Consumer | How | Breaking Change Impact |
|----------|-----|------------------------|
| ppds-alm | Workflows call cmdlets | Must update workflow scripts |
| ppds-demo | Scripts import module | Must update scripts |

### Version Sync Rules

| Rule | Details |
|------|---------|
| Major versions | Sync with ppds-alm when cmdlet signatures change |
| Minor/patch | Independent |
| Pre-release format | `Prerelease = 'alphaN'` in `.psd1` manifest |

### Breaking Changes Requiring Coordination

- Changing exported cmdlet names
- Removing or renaming mandatory parameters
- Changing output object structure
- Changing `Connect-DataverseEnvironment` auth flow

---

## 📋 Key Files

| File | Purpose |
|------|---------|
| `PPDS.Tools.psd1` | Module manifest (version, exports, metadata) |
| `PPDS.Tools.psm1` | Root module (dot-sources Public/Private) |
| `CHANGELOG.md` | Release notes |
| `plugin-registration.schema.json` | JSON schema for registration files |

---

## ⚖️ Decision Presentation

When presenting choices or asking questions:
1. **Lead with your recommendation** and rationale
2. **List alternatives considered** and why they're not preferred
3. **Ask for confirmation**, not open-ended input

❌ "What testing approach should we use?"
✅ "I recommend X because Y. Alternatives considered: A (rejected because B), C (rejected because D). Do you agree?"
