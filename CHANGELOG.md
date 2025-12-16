# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- PSScriptAnalyzer linting in CI pipeline (errors + warnings fail build)
- Unit tests for JSON serialization utilities
- Code coverage reporting with 80% threshold
- Pester test tags for categorization (Unit, Integration)
- Native OAuth2 implementation for service principal (client credentials) authentication
- Device code flow for interactive authentication (`-Interactive` flag)
- `DataverseConnection` class with token expiry tracking

### Changed

- **Breaking**: Replaced `Microsoft.Xrm.Data.PowerShell` dependency with native OAuth2 authentication
  - Module now works on both PowerShell 5.1 and PowerShell 7+
  - No external module dependencies for Dataverse connectivity
- `Connect-DataverseEnvironment` now returns a `DataverseConnection` object instead of `CrmServiceClient`
  - Same properties available: `CurrentAccessToken`, `ConnectedOrgFriendlyName`, `ConnectedOrgPublishedEndpoints`
- Interactive authentication now uses device code flow instead of browser redirect
  - More reliable across different environments (SSH, containers, corporate proxies)
- Extracted shared assembly resolution logic to `Invoke-WithAssemblyResolution`
- Refactored large public functions into smaller private helpers
- Moved OAuth AppId to module constant for maintainability
- Plugin type registration now uses `MSCRM.SolutionUniqueName` header for solution association (matches extension pattern)
- Plugin package registration uses `MSCRM.SolutionUniqueName` header (no separate AddSolutionComponent call needed)

### Fixed

- OData query issues when filter values contain single quotes (proper escaping)
- Path resolution in `Deploy-DataversePlugins` now correctly handles paths starting with `./`
  - `./path` resolves relative to current working directory
  - Other relative paths (including `../`) resolve relative to registrations.json location
  - Absolute paths used as-is
- Plugin package registration now correctly parses name/version from nupkg filename (requires X.Y.Z format)
- Skip adding Plugin Assembly to solution for NuGet packages (package contains the assembly)
- Assembly registration now returns fallback object if post-registration query fails (fixes "skipping step registration" issue)
- Image update now only sends updatable fields (`entityalias`, `attributes`) - `imagetype`, `name`, `messagepropertyname` are read-only after creation
- Image update/create errors now caught and logged as warnings instead of crashing deployment
- Connection string parsing now case-insensitive for key names (`Url`, `url`, `URL` all work)

### Security

- Added input escaping for OData filter values to prevent injection
- **Removed storage of `ClientSecret` and `RefreshToken` in `DataverseConnection` object**
  - Long-lived credentials are no longer stored after authentication
  - Only the time-limited access token (~60 min) is retained
  - Prevents accidental credential exposure via logging, serialization, or memory inspection
  - Added `ToString()` override to prevent accidental credential logging
  - If token refresh is needed in the future, credentials should be re-prompted or use SecretManagement module

### Removed

- Dependency on `Microsoft.Xrm.Data.PowerShell` module
- PowerShell 7.0 minimum requirement (now supports 5.1+)
- Unused component types from `$script:ComponentType` (PluginType, SdkMessageProcessingStepImage - only PluginAssembly and SdkMessageProcessingStep remain)

## [1.0.0] - 2025-12-13

### Added

- Initial release of PPDS.Tools PowerShell module
- `Connect-DataverseEnvironment` - Authenticate to Dataverse environments
  - Support for service principal (client credentials) authentication
  - Support for interactive OAuth browser login
  - Environment variable and .env file support
- `Get-DataversePluginRegistrations` - Extract plugin registrations from compiled assemblies
  - Reflection-based extraction of [PluginStep] and [PluginImage] attributes
  - Automatic project discovery in repository structure
  - JSON schema validation support
- `Deploy-DataversePlugins` - Deploy plugins to Dataverse
  - Support for classic plugin assemblies and NuGet plugin packages
  - Automatic step and image registration/updates
  - Solution component management
  - WhatIf mode for dry runs
- `Get-DataversePluginDrift` - Detect configuration drift
  - Compare registrations.json with Dataverse state
  - Report orphaned, missing, and modified components
- `Remove-DataverseOrphanedSteps` - Clean up orphaned components
  - Safe removal of steps not in configuration
  - Plugin type cleanup support

### Dependencies

- Requires PowerShell 7.0+
- Requires Microsoft.Xrm.Data.PowerShell module for Dataverse connectivity

[Unreleased]: https://github.com/joshsmithxrm/ppds-tools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/joshsmithxrm/ppds-tools/releases/tag/v1.0.0
