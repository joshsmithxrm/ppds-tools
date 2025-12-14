# PPDS.Tools

PowerShell tools for Dataverse plugin deployment, drift detection, and CI/CD automation. Part of the [Power Platform Developer Suite](https://github.com/joshsmithxrm).

## Installation

```powershell
Install-Module PPDS.Tools -Scope CurrentUser
```

## Prerequisites

- PowerShell 7.0+
- [Microsoft.Xrm.Data.PowerShell](https://www.powershellgallery.com/packages/Microsoft.Xrm.Data.PowerShell) module (for deployment commands)
- Power Platform CLI (`pac`) for assembly updates

## Quick Start

### Connect to a Dataverse Environment

```powershell
Import-Module PPDS.Tools

# Interactive browser login
$conn = Connect-DataverseEnvironment `
    -EnvironmentUrl "https://myorg.crm.dynamics.com" `
    -Interactive

# Or use service principal
$conn = Connect-DataverseEnvironment `
    -EnvironmentUrl "https://myorg.crm.dynamics.com" `
    -ClientId $clientId `
    -ClientSecret $clientSecret `
    -TenantId $tenantId
```

### Extract Plugin Registrations

```powershell
# Extract from a compiled DLL
Get-DataversePluginRegistrations `
    -AssemblyPath "./bin/Release/net462/MyPlugins.dll" `
    -OutputPath "./registrations.json"

# Or discover and extract all projects in a repository
Get-DataversePluginRegistrations -RepositoryRoot "." -Build
```

### Deploy Plugins

```powershell
Deploy-DataversePlugins `
    -RegistrationFile "./registrations.json" `
    -Connection $conn

# With orphan cleanup
Deploy-DataversePlugins `
    -RegistrationFile "./registrations.json" `
    -Connection $conn `
    -Force
```

### Check for Configuration Drift

```powershell
Get-DataversePluginDrift `
    -RegistrationFile "./registrations.json" `
    -Connection $conn
```

### Remove Orphaned Steps

```powershell
Remove-DataverseOrphanedSteps `
    -RegistrationFile "./registrations.json" `
    -Connection $conn
```

## Commands

| Command | Description |
|---------|-------------|
| `Connect-DataverseEnvironment` | Establishes an authenticated connection to Dataverse |
| `Get-DataversePluginRegistrations` | Extracts plugin registrations from compiled assemblies |
| `Deploy-DataversePlugins` | Deploys plugin assemblies and registers steps |
| `Get-DataversePluginDrift` | Compares configuration with Dataverse state |
| `Remove-DataverseOrphanedSteps` | Removes steps that exist in Dataverse but not in config |

## Authentication

The module supports multiple authentication methods:

1. **Explicit parameters** - Pass credentials directly to commands
2. **Environment variables** - Set `SP_APPLICATION_ID`, `SP_CLIENT_SECRET`, `DATAVERSE_URL` in a `.env` file
3. **Interactive OAuth** - Use `-Interactive` for browser-based login

## registrations.json Format

Plugin registrations are stored in JSON format:

```json
{
  "$schema": "../schemas/plugin-registration.schema.json",
  "version": "1.0",
  "assemblies": [
    {
      "name": "MyPlugins",
      "type": "Assembly",
      "solution": "MySolution",
      "path": "./bin/Release/net462/MyPlugins.dll",
      "plugins": [
        {
          "typeName": "MyNamespace.AccountPreCreatePlugin",
          "steps": [
            {
              "name": "MyNamespace.AccountPreCreatePlugin: Create of account",
              "message": "Create",
              "entity": "account",
              "stage": "PreOperation",
              "mode": "Synchronous",
              "executionOrder": 1,
              "images": []
            }
          ]
        }
      ]
    }
  ]
}
```

## Related Projects

- [power-platform-developer-suite](https://github.com/joshsmithxrm/power-platform-developer-suite) - VS Code extension
- [ppds-sdk](https://github.com/joshsmithxrm/ppds-sdk) - NuGet packages for plugin development
- [ppds-alm](https://github.com/joshsmithxrm/ppds-alm) - CI/CD pipeline templates
- [ppds-demo](https://github.com/joshsmithxrm/ppds-demo) - Reference implementation

## License

MIT License - see [LICENSE](LICENSE) for details.
