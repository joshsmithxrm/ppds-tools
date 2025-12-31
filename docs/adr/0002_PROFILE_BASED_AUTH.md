# ADR-0002: Profile-Based Authentication

**Status:** Accepted
**Applies to:** All PPDS.Tools cmdlets requiring authentication
**Date:** 2025-01-XX

## Context

In v1.x, PPDS.Tools used a `DataverseConnection` class for authentication:

```powershell
# v1.x pattern
$conn = Connect-DataverseEnvironment -Interactive
Deploy-DataversePlugins -Connection $conn -RegistrationFile ./reg.json
```

This required native OAuth implementation in PowerShell (~300 lines of code).

The SDK's unified CLI now provides a robust profile-based authentication system that:
- Stores credentials securely
- Supports multiple auth methods
- Handles token refresh automatically
- Enables environment switching

## Decision

**Use CLI auth profiles instead of native OAuth.** Authentication is managed entirely by the CLI.

### New Pattern

```powershell
# Create a profile (once)
Connect-DataverseEnvironment -DeviceCode -Name "dev" -Environment "https://org.crm.dynamics.com"

# Use the profile (uses active profile by default)
Deploy-DataversePlugins -ConfigPath ./registrations.json

# Or specify a profile
Deploy-DataversePlugins -ConfigPath ./registrations.json -Profile "dev"

# Override environment for a specific call
Export-DataverseData -SchemaPath ./schema.xml -OutputPath ./data.zip -Environment "https://test.crm.dynamics.com"
```

### Authentication Flow

1. User creates profile via `Connect-DataverseEnvironment` (wraps `ppds auth create`)
2. CLI stores credentials/tokens in secure profile storage
3. Cmdlets pass `-Profile` and `-Environment` to CLI
4. CLI handles token acquisition/refresh automatically

### Supported Auth Methods

| Method | PowerShell Parameter |
|--------|---------------------|
| Interactive browser | (default) |
| Device code | `-DeviceCode` |
| Client secret | `-ApplicationId`, `-ClientSecret`, `-TenantId` |
| Certificate file | `-ApplicationId`, `-CertificatePath`, `-TenantId` |
| Certificate store | `-ApplicationId`, `-CertificateThumbprint`, `-TenantId` |
| Managed identity | `-ManagedIdentity` |
| Username/password | `-Username`, `-Password` |
| GitHub federated | `-GitHubFederated`, `-ApplicationId`, `-TenantId` |
| Azure DevOps federated | `-AzureDevOpsFederated`, `-ApplicationId`, `-TenantId` |

## Consequences

### Positive

- **Simpler PowerShell code** - No OAuth implementation needed
- **Consistent auth** - Same experience as CLI users
- **Token caching** - CLI handles token refresh automatically
- **Multiple profiles** - Easy switching between environments
- **Credential security** - CLI uses secure storage
- **Full auth method support** - All CLI auth methods available

### Negative

- **Breaking change** - v1.x scripts must be updated
- **CLI dependency** - Requires CLI to be installed
- **Profile management** - Users must understand profile concept

### Migration from v1.x

| v1.x Pattern | v2.x Pattern |
|--------------|--------------|
| `$conn = Connect-DataverseEnvironment -Interactive` | `Connect-DataverseEnvironment -DeviceCode -Name "dev"` |
| `Deploy-DataversePlugins -Connection $conn ...` | `Deploy-DataversePlugins -Profile "dev" ...` |
| `-Connection $conn` parameter | `-Profile "name"` or use active profile |

### Helper Cmdlets

New cmdlets for profile management:

| Cmdlet | Purpose |
|--------|---------|
| `Get-DataverseProfile` | Get current active profile |
| `Get-DataverseProfiles` | List all profiles |

For profile switching, deletion, and other management, use the CLI directly:
- `ppds auth select` - Switch active profile
- `ppds auth delete` - Delete a profile
- `ppds auth clear` - Clear all profiles
- `ppds env select` - Change profile's default environment

## Alternatives Considered

### Keep Native OAuth

**Rejected because:**
- Duplicates CLI implementation
- ~300 lines of OAuth code to maintain
- No token refresh (tokens expire after ~60 minutes)
- Limited auth method support

### Thin Connection Object Wrapper

```powershell
# Would validate profile exists, return object
$conn = Connect-DataverseEnvironment -Profile "dev"
Deploy-DataversePlugins -Connection $conn ...
```

**Rejected because:**
- Adds unnecessary abstraction
- Connection object would just hold profile name
- Confusing migration from v1.x (same pattern, different behavior)
