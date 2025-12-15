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

### Changed

- Extracted shared assembly resolution logic to `Invoke-WithAssemblyResolution`
- Refactored large public functions into smaller private helpers
- Moved OAuth AppId to module constant for maintainability

### Fixed

- OData query issues when filter values contain single quotes (proper escaping)

### Security

- Added input escaping for OData filter values to prevent injection

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

[1.0.0]: https://github.com/joshsmithxrm/ppds-tools/releases/tag/v1.0.0
