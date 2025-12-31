# PPDS.Tools

[![Build](https://github.com/joshsmithxrm/ppds-tools/actions/workflows/test.yml/badge.svg)](https://github.com/joshsmithxrm/ppds-tools/actions/workflows/test.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PPDS.Tools.svg)](https://www.powershellgallery.com/packages/PPDS.Tools/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

PowerShell module for Dataverse plugin deployment, data migration, and CI/CD automation. Part of the [Power Platform Developer Suite](https://github.com/joshsmithxrm/power-platform-developer-suite) ecosystem.

## Installation

```powershell
# Install the PowerShell module
Install-Module PPDS.Tools -Scope CurrentUser -AllowPrerelease

# Install the CLI tool (required)
dotnet tool install --global PPDS.Cli
```

**Requirements:**
- PowerShell 7.0+
- .NET 8.0+ SDK (for CLI tool)
- PPDS.Cli dotnet tool

---

## Cmdlets

| Cmdlet | Description |
|--------|-------------|
| **Authentication** | |
| `Connect-DataverseEnvironment` | Create authentication profile |
| `Get-DataverseProfile` | Get active profile |
| `Get-DataverseProfiles` | List all profiles |
| **Plugin Deployment** | |
| `Get-DataversePluginRegistrations` | Extract registrations from assemblies |
| `Deploy-DataversePlugins` | Deploy assemblies and register steps |
| `Get-DataversePluginDrift` | Detect configuration drift |
| `Remove-DataverseOrphanedSteps` | Clean up orphaned steps |
| `Get-DataversePlugins` | List registered plugins |
| **Data Migration** | |
| `Export-DataverseData` | Export data to ZIP file |
| `Import-DataverseData` | Import data from ZIP file |
| `Copy-DataverseData` | Copy data between environments |
| `Get-DataverseDependencyGraph` | Analyze schema dependencies |

---

## Quick Start

### 1. Create an Authentication Profile

```powershell
# Interactive login (device code)
Connect-DataverseEnvironment -DeviceCode -Name "dev" -Environment "https://myorg.crm.dynamics.com"

# Service principal (for CI/CD)
Connect-DataverseEnvironment `
    -Name "ci" `
    -ApplicationId $env:CLIENT_ID `
    -ClientSecret $env:CLIENT_SECRET `
    -TenantId $env:TENANT_ID `
    -Environment "https://myorg.crm.dynamics.com"
```

### 2. Deploy Plugins

```powershell
# Extract registrations from compiled assembly
Get-DataversePluginRegistrations -InputPath "./bin/Release/net462/MyPlugins.dll"

# Deploy to Dataverse (uses active profile)
Deploy-DataversePlugins -ConfigPath "./registrations.json"

# Or specify a profile
Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile "dev"

# Check for drift
Get-DataversePluginDrift -ConfigPath "./registrations.json"
```

### 3. Migrate Data

```powershell
# Export data
Export-DataverseData -SchemaPath "./schema.xml" -OutputPath "./data.zip"

# Import data
Import-DataverseData -DataPath "./data.zip" -BypassPlugins all

# Or copy directly between environments
Copy-DataverseData `
    -SourceEnvironment "dev" `
    -TargetEnvironment "test" `
    -SchemaPath "./schema.xml"
```

---

## Authentication

All cmdlets use profile-based authentication managed by the `ppds` CLI.

### Creating Profiles

```powershell
# Interactive (device code flow)
Connect-DataverseEnvironment -DeviceCode -Name "dev"

# Service principal with client secret
Connect-DataverseEnvironment `
    -Name "prod" `
    -ApplicationId "00000000-0000-0000-0000-000000000000" `
    -ClientSecret "your-secret" `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -Environment "https://org.crm.dynamics.com"

# Managed identity (Azure)
Connect-DataverseEnvironment -ManagedIdentity -Name "azure"

# GitHub Actions OIDC
Connect-DataverseEnvironment -GitHubFederated -ApplicationId $appId -TenantId $tenantId -Name "gh"
```

### Using Profiles

```powershell
# Use active profile (default)
Deploy-DataversePlugins -ConfigPath "./registrations.json"

# Specify profile
Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile "dev"

# Override environment
Export-DataverseData -SchemaPath "./schema.xml" -OutputPath "./data.zip" -Environment "https://test.crm.dynamics.com"
```

### Managing Profiles

```powershell
# List profiles
Get-DataverseProfiles

# Get active profile
Get-DataverseProfile

# Switch profile (use CLI directly)
ppds auth select dev

# Delete profile (use CLI directly)
ppds auth delete prod
```

---

## CI/CD Examples

### GitHub Actions

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        run: |
          dotnet tool install --global PPDS.Cli
          Install-Module PPDS.Tools -Force -AllowPrerelease
        shell: pwsh

      - name: Authenticate
        run: |
          Connect-DataverseEnvironment `
            -GitHubFederated `
            -ApplicationId "${{ vars.AZURE_CLIENT_ID }}" `
            -TenantId "${{ vars.AZURE_TENANT_ID }}" `
            -Environment "${{ vars.DATAVERSE_URL }}" `
            -Name "deploy"
        shell: pwsh

      - name: Deploy Plugins
        run: |
          Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile "deploy"
        shell: pwsh
```

### Azure DevOps

```yaml
steps:
  - task: PowerShell@2
    inputs:
      targetType: inline
      script: |
        dotnet tool install --global PPDS.Cli
        Install-Module PPDS.Tools -Force -AllowPrerelease

        Connect-DataverseEnvironment `
          -ApplicationId "$(ClientId)" `
          -ClientSecret "$(ClientSecret)" `
          -TenantId "$(TenantId)" `
          -Environment "$(DataverseUrl)" `
          -Name "deploy"

        Deploy-DataversePlugins -ConfigPath "./registrations.json"
      pwsh: true
```

---

## Architecture

All cmdlets wrap the [`ppds`](https://github.com/joshsmithxrm/ppds-sdk) CLI tool. This provides:

- **Single source of truth** - CLI is the implementation
- **Consistent behavior** - Same code path as CLI users
- **Automatic updates** - CLI improvements benefit PowerShell users

See [ADR-0001: CLI Wrapper Pattern](docs/adr/0001_CLI_WRAPPER_PATTERN.md) for details.

---

## Related Projects

| Project | Description |
|---------|-------------|
| [ppds-sdk](https://github.com/joshsmithxrm/ppds-sdk) | NuGet packages and CLI tool |
| [power-platform-developer-suite](https://github.com/joshsmithxrm/power-platform-developer-suite) | VS Code extension |
| [ppds-alm](https://github.com/joshsmithxrm/ppds-alm) | CI/CD pipeline templates |
| [ppds-demo](https://github.com/joshsmithxrm/ppds-demo) | Reference implementation |

## License

MIT License - see [LICENSE](LICENSE) for details.
