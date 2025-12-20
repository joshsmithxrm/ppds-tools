# PPDS.Tools

[![Build](https://github.com/joshsmithxrm/ppds-tools/actions/workflows/test.yml/badge.svg)](https://github.com/joshsmithxrm/ppds-tools/actions/workflows/test.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PPDS.Tools.svg)](https://www.powershellgallery.com/packages/PPDS.Tools/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

PowerShell module for Dataverse plugin deployment, data migration, and CI/CD automation. Part of the [Power Platform Developer Suite](https://github.com/joshsmithxrm/power-platform-developer-suite) ecosystem.

## Installation

```powershell
Install-Module PPDS.Tools -Scope CurrentUser
```

**Requirements:** PowerShell 7.0+

## Compatibility

| PPDS.Tools | Requires |
|------------|----------|
| 1.1.x | PowerShell 7.0+ |
| 1.2.x | PowerShell 7.0+, [PPDS.Migration.Cli](https://github.com/joshsmithxrm/ppds-sdk) >= 1.0.0 (for migration cmdlets) |

---

## Cmdlets

| Cmdlet | Description |
|--------|-------------|
| **Plugin Deployment** | |
| `Connect-DataverseEnvironment` | Establish authenticated connection |
| `Get-DataversePluginRegistrations` | Extract registrations from assemblies |
| `Deploy-DataversePlugins` | Deploy assemblies and register steps |
| `Get-DataversePluginDrift` | Detect configuration drift |
| `Remove-DataverseOrphanedSteps` | Clean up orphaned steps |
| **Data Migration** | |
| `Export-DataverseData` | Export data to ZIP file |
| `Import-DataverseData` | Import data from ZIP file |
| `Get-DataverseDependencyGraph` | Analyze schema dependencies |
| `Invoke-DataverseMigration` | Full environment-to-environment migration |

---

## Plugin Deployment

### Connect to Dataverse

```powershell
# Interactive browser login
$conn = Connect-DataverseEnvironment `
    -EnvironmentUrl "https://myorg.crm.dynamics.com" `
    -Interactive

# Service principal
$conn = Connect-DataverseEnvironment `
    -EnvironmentUrl "https://myorg.crm.dynamics.com" `
    -ClientId $clientId `
    -ClientSecret $clientSecret `
    -TenantId $tenantId
```

### Extract and Deploy Plugins

```powershell
# Extract registrations from compiled assembly
Get-DataversePluginRegistrations `
    -AssemblyPath "./bin/Release/net462/MyPlugins.dll" `
    -OutputPath "./registrations.json"

# Deploy to Dataverse
Deploy-DataversePlugins `
    -RegistrationFile "./registrations.json" `
    -Connection $conn

# Check for drift
Get-DataversePluginDrift `
    -RegistrationFile "./registrations.json" `
    -Connection $conn
```

---

## Data Migration

Migration cmdlets wrap the [`ppds-migrate`](https://github.com/joshsmithxrm/ppds-sdk) CLI tool.

```powershell
# Export data
Export-DataverseData `
    -Connection "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;..." `
    -SchemaPath "./schema.xml" `
    -OutputPath "./data.zip"

# Import data
Import-DataverseData `
    -Connection "AuthType=ClientSecret;Url=https://target.crm.dynamics.com;..." `
    -DataPath "./data.zip" `
    -BypassPlugins

# Full migration
Invoke-DataverseMigration `
    -SourceConnection "AuthType=ClientSecret;Url=https://source.crm.dynamics.com;..." `
    -TargetConnection "AuthType=ClientSecret;Url=https://target.crm.dynamics.com;..." `
    -SchemaPath "./schema.xml"
```

---

## Architecture Decisions

- [ADR-0001: CLI Wrapper Pattern](docs/adr/0001_CLI_WRAPPER_PATTERN.md) - Why migration cmdlets wrap the CLI

---

## Related Projects

| Project | Description |
|---------|-------------|
| [ppds-sdk](https://github.com/joshsmithxrm/ppds-sdk) | NuGet packages and CLI tools |
| [power-platform-developer-suite](https://github.com/joshsmithxrm/power-platform-developer-suite) | VS Code extension |
| [ppds-alm](https://github.com/joshsmithxrm/ppds-alm) | CI/CD pipeline templates |
| [ppds-demo](https://github.com/joshsmithxrm/ppds-demo) | Reference implementation |

## License

MIT License - see [LICENSE](LICENSE) for details.
