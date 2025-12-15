# PPDS.Tools Implementation Plan

**Created:** 2025-12-15
**Status:** In Progress
**Target:** Address all code review findings before v1.0 release

---

## Overview

This document tracks the implementation of improvements identified during the comprehensive code review. All items must be completed and verified before the module is published to PowerShell Gallery.

---

## Progress Tracker

| # | Task | Priority | Status | Notes |
|---|------|----------|--------|-------|
| 1 | [Add PSScriptAnalyzer to CI](#1-add-psscriptanalyzer-to-ci) | High | ✅ Completed | Added lint job with settings file |
| 2 | [Add Unit Tests for JSON Utilities](#2-add-unit-tests-for-json-utilities) | High | ✅ Completed | 18 new tests |
| 3 | [Extract Shared Assembly Resolution](#3-extract-shared-assembly-resolution) | High | ✅ Completed | `Invoke-WithAssemblyResolution` |
| 4 | [Escape OData Filter Values](#4-escape-odata-filter-values) | High | ✅ Completed | `Get-EscapedODataString` + 12 tests |
| 5 | [Add CHANGELOG.md](#5-add-changelogmd) | Medium | ✅ Completed | Updated existing with Unreleased |
| 6 | [Refactor Large Functions](#6-refactor-large-functions) | Medium | ⏭️ Deferred | Functions work well as-is |
| 7 | [Add Code Coverage to CI](#7-add-code-coverage-to-ci) | Medium | ✅ Completed | 80% threshold, JaCoCo format |
| 8 | [Extract Hardcoded OAuth AppId](#8-extract-hardcoded-oauth-appid) | Low | ✅ Completed | `$script:DefaultOAuthAppId` |
| 9 | [Add Pester Tags](#9-add-pester-tags) | Low | ✅ Completed | Unit tag on all tests |
| 10 | [Consider Async Step Deployment](#10-consider-async-step-deployment) | Low | ✅ Completed | Documented decision in code |
| 11 | [Final Review](#11-final-review) | Required | 🔄 In Progress | |

**Legend:** ⬜ Pending | 🔄 In Progress | ✅ Completed | ⏭️ Deferred

---

## Detailed Task Specifications

### 1. Add PSScriptAnalyzer to CI

**Priority:** High
**Estimated Complexity:** Low
**Files to Modify:** `.github/workflows/test.yml`

#### Requirements

- Add PSScriptAnalyzer step to the test workflow
- Fail on Errors and Warnings (not Information)
- Run against `src/` directory
- Upload results as artifact for review

#### Implementation

```yaml
- name: Run PSScriptAnalyzer
  shell: pwsh
  run: |
    Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
    $results = Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error,Warning
    $results | Format-Table -AutoSize
    if ($results) {
      Write-Error "PSScriptAnalyzer found $($results.Count) issue(s)"
      exit 1
    }
```

#### Acceptance Criteria

- [ ] PSScriptAnalyzer runs on every push and PR
- [ ] Build fails if any Error or Warning severity issues found
- [ ] Results displayed in workflow logs
- [ ] Any existing violations fixed before merging

---

### 2. Add Unit Tests for JSON Utilities

**Priority:** High
**Estimated Complexity:** Medium
**Files to Create:** `tests/PPDS.Tools.Tests/JsonUtilities.Tests.ps1`

#### Requirements

Test coverage for:
- `ConvertTo-RegistrationJson` - round-trip serialization
- `Read-RegistrationJson` - file reading and parsing
- `Format-JsonValue` (internal) - all value types

#### Test Cases

```powershell
Describe 'ConvertTo-RegistrationJson' {
    It 'Should produce valid JSON' { }
    It 'Should include $schema property' { }
    It 'Should handle empty assemblies array' { }
    It 'Should handle special characters in strings' { }
    It 'Should preserve property order' { }
    It 'Should format nested objects correctly' { }
}

Describe 'Read-RegistrationJson' {
    It 'Should return null for non-existent file' { }
    It 'Should parse valid JSON file' { }
    It 'Should handle UTF-8 encoding' { }
}

Describe 'Format-JsonValue' {
    It 'Should format null correctly' { }
    It 'Should format booleans as lowercase' { }
    It 'Should format integers without quotes' { }
    It 'Should escape special characters in strings' { }
    It 'Should format empty arrays as []' { }
    It 'Should format nested objects with proper indentation' { }
}
```

#### Acceptance Criteria

- [ ] All test cases pass
- [ ] Tests use Pester 5 syntax
- [ ] Tests are tagged with `Unit` tag
- [ ] No external dependencies (mock file system where needed)

---

### 3. Extract Shared Assembly Resolution

**Priority:** High
**Estimated Complexity:** Medium
**Files to Modify:** `src/PPDS.Tools/Private/AssemblyReflection.ps1`

#### Problem

`Get-PluginRegistrationsFromAssembly` and `Get-AllPluginTypeNames` both contain nearly identical assembly resolution logic (lines 22-30 and 139-147).

#### Solution

Extract to a shared function:

```powershell
function Invoke-WithAssemblyResolution {
    <#
    .SYNOPSIS
        Executes a script block with assembly resolution handling.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DllPath,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $dllFullPath = (Resolve-Path $DllPath).Path
    $dllDir = Split-Path $dllFullPath -Parent

    $resolveHandler = [System.ResolveEventHandler]{
        param($sender, $args)
        $assemblyName = (New-Object System.Reflection.AssemblyName($args.Name)).Name
        $localDllPath = Join-Path $using:dllDir "$assemblyName.dll"
        if (Test-Path $localDllPath) {
            return [System.Reflection.Assembly]::LoadFrom($localDllPath)
        }
        return $null
    }

    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($resolveHandler)

    try {
        $assembly = [System.Reflection.Assembly]::LoadFrom($dllFullPath)
        & $ScriptBlock -Assembly $assembly
    }
    finally {
        [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($resolveHandler)
    }
}
```

#### Acceptance Criteria

- [ ] New `Invoke-WithAssemblyResolution` function created
- [ ] `Get-PluginRegistrationsFromAssembly` refactored to use it
- [ ] `Get-AllPluginTypeNames` refactored to use it
- [ ] All existing tests still pass
- [ ] No behavior change (verified manually)

---

### 4. Escape OData Filter Values

**Priority:** High
**Estimated Complexity:** Low
**Files to Modify:** `src/PPDS.Tools/Private/DataverseQueries.ps1`

#### Problem

Filter values are interpolated directly into OData queries without escaping:
```powershell
$filter = "`$filter=name eq '$Name'"
```

If `$Name` contains a single quote, this breaks the query or could cause unintended behavior.

#### Solution

Create an escape utility and apply to all filter constructions:

```powershell
function Get-EscapedODataString {
    <#
    .SYNOPSIS
        Escapes a string value for use in OData filter expressions.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    # OData string literals use single quotes, escape by doubling
    return $Value -replace "'", "''"
}
```

#### Files Affected

Apply escaping in these locations:
- `Get-PluginAssembly` (line 53)
- `Get-PluginPackage` (lines 74, 80)
- `Get-PluginType` (line 102)
- `Get-SdkMessage` (line 170)
- `Get-SdkMessageFilter` (line 190-192)
- `Get-ProcessingStep` (line 210)
- `Get-Solution` (line 266)

#### Acceptance Criteria

- [ ] `Get-EscapedODataString` function created
- [ ] All OData filter string values escaped
- [ ] Test added for escaping behavior
- [ ] Verified with names containing single quotes

---

### 5. Add CHANGELOG.md

**Priority:** Medium
**Estimated Complexity:** Low
**Files to Create:** `CHANGELOG.md`

#### Requirements

Follow Keep a Changelog format (matching the extension):
- `[Unreleased]` section for pending changes
- Semantic versioning
- Categories: Added, Changed, Fixed, Removed, Security

#### Initial Content

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- PSScriptAnalyzer linting in CI pipeline
- Unit tests for JSON serialization utilities
- Code coverage reporting (target: 80%)
- OData filter value escaping for security

### Changed

- Extracted shared assembly resolution logic to reduce duplication
- Refactored large public functions into smaller private helpers

### Fixed

- Potential OData injection when filter values contain single quotes

## [1.0.0] - YYYY-MM-DD

### Added

- Initial release of PPDS.Tools PowerShell module
- `Connect-DataverseEnvironment` - Authentication with multiple methods
- `Get-DataversePluginRegistrations` - Extract registrations from assemblies
- `Deploy-DataversePlugins` - Deploy assemblies and register steps
- `Get-DataversePluginDrift` - Detect configuration drift
- `Remove-DataverseOrphanedSteps` - Clean up orphaned steps
- JSON schema for plugin registration configuration
- Support for both Assembly and NuGet plugin packages
```

#### Acceptance Criteria

- [ ] CHANGELOG.md exists in repository root
- [ ] Follows Keep a Changelog format
- [ ] Documents all changes made in this implementation plan
- [ ] Version dates updated before release

---

### 6. Refactor Large Functions

**Priority:** Medium
**Estimated Complexity:** High
**Files to Modify:**
- `src/PPDS.Tools/Public/Plugins/Get-DataversePluginRegistrations.ps1`
- `src/PPDS.Tools/Public/Plugins/Deploy-DataversePlugins.ps1`

#### Problem

- `Get-DataversePluginRegistrations` is 243 lines with multiple responsibilities
- `Deploy-DataversePlugins` is 403 lines handling too many concerns

#### Solution

Extract private helper functions while preserving public API.

##### Get-DataversePluginRegistrations Extraction

```powershell
# New private functions to extract:
function Get-PluginProjectsInfo { }      # Lines 106-147: Project discovery and building
function Export-AssemblyRegistration { } # Lines 168-224: Process single assembly
function Write-ExtractionSummary { }     # Lines 227-235: Output summary
```

##### Deploy-DataversePlugins Extraction

```powershell
# New private functions to extract:
function Deploy-SingleAssembly { }       # Lines 86-364: Process one assembly registration
function Register-PluginSteps { }        # Lines 158-334: Step registration loop
function Find-OrphanedSteps { }          # Lines 337-363: Orphan detection
function Write-DeploymentSummary { }     # Lines 367-386: Output summary
```

#### Acceptance Criteria

- [ ] Public function signatures unchanged
- [ ] Each extracted function < 100 lines
- [ ] All existing tests still pass
- [ ] New functions have comment-based help
- [ ] Code coverage maintained or improved

---

### 7. Add Code Coverage to CI

**Priority:** Medium
**Estimated Complexity:** Medium
**Files to Modify:** `.github/workflows/test.yml`

#### Requirements

- Generate code coverage report using Pester
- Upload coverage report as artifact
- Fail build if coverage < 80%
- Display coverage summary in workflow

#### Implementation

```yaml
- name: Run Tests with Coverage
  shell: pwsh
  run: |
    $config = New-PesterConfiguration
    $config.Run.Path = './tests'
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = './TestResults.xml'
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = './src/PPDS.Tools/**/*.ps1'
    $config.CodeCoverage.OutputPath = './coverage.xml'
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.CoveragePercentTarget = 80

    $result = Invoke-Pester -Configuration $config

    if ($result.CodeCoverage.CoveragePercent -lt 80) {
      Write-Error "Code coverage $($result.CodeCoverage.CoveragePercent)% is below 80% threshold"
      exit 1
    }

- name: Upload Coverage Report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: coverage-report
    path: coverage.xml
```

#### Acceptance Criteria

- [ ] Coverage report generated on each run
- [ ] Build fails if coverage < 80%
- [ ] Coverage artifact uploaded
- [ ] Coverage percentage displayed in logs

---

### 8. Extract Hardcoded OAuth AppId

**Priority:** Low
**Estimated Complexity:** Low
**Files to Modify:** `src/PPDS.Tools/Public/Auth/Connect-DataverseEnvironment.ps1`

#### Problem

Line 139 contains a hardcoded OAuth AppId:
```powershell
$finalConnectionString = "AuthType=OAuth;Url=$url;AppId=51f81489-12ee-4a9e-aaae-a2591f45987d;..."
```

#### Solution

Extract to a module-scoped constant in `PPDS.Tools.psm1` or a dedicated constants file:

```powershell
# In PPDS.Tools.psm1 or Private/Constants.ps1
$script:DefaultOAuthAppId = '51f81489-12ee-4a9e-aaae-a2591f45987d'

# In Connect-DataverseEnvironment.ps1
$finalConnectionString = "AuthType=OAuth;Url=$url;AppId=$script:DefaultOAuthAppId;..."
```

#### Acceptance Criteria

- [ ] AppId moved to constant
- [ ] Constant documented with comment explaining it's Microsoft's first-party app
- [ ] Function still works for interactive auth

---

### 9. Add Pester Tags

**Priority:** Low
**Estimated Complexity:** Low
**Files to Modify:** All test files in `tests/`

#### Requirements

Add tags to categorize tests:
- `Unit` - Isolated unit tests, no external dependencies
- `Integration` - Tests requiring Dataverse connection
- `Slow` - Tests that take > 5 seconds

#### Implementation

```powershell
Describe 'ConvertTo-RegistrationJson' -Tag 'Unit' {
    # ...
}

Describe 'Deploy-DataversePlugins Integration' -Tag 'Integration', 'Slow' {
    # ...
}
```

#### Benefits

```powershell
# Run only unit tests (fast, no connection needed)
Invoke-Pester -Tag 'Unit'

# Skip slow tests in development
Invoke-Pester -ExcludeTag 'Slow'
```

#### Acceptance Criteria

- [ ] All existing tests tagged
- [ ] New tests include appropriate tags
- [ ] README documents tag usage

---

### 10. Consider Async Step Deployment

**Priority:** Low
**Estimated Complexity:** High
**Status:** Research / Future Enhancement

#### Problem

Large registrations with many steps deploy sequentially, which can be slow.

#### Potential Solution

Use PowerShell 7's `ForEach-Object -Parallel` for step registration:

```powershell
$steps | ForEach-Object -Parallel {
    # Register step
} -ThrottleLimit 5
```

#### Considerations

- Dataverse API rate limits
- Error handling in parallel context
- Progress reporting
- Transaction semantics (partial failures)

#### Decision

**Defer to future release.** Document as potential enhancement. Current sequential approach is:
- Simpler to debug
- Provides clear progress output
- Avoids rate limiting issues

#### Acceptance Criteria

- [ ] Decision documented in code comments
- [ ] GitHub issue created for future consideration (optional)

---

### 11. Final Review

**Priority:** Required
**Estimated Complexity:** Medium
**Prerequisite:** All other tasks completed

#### Review Prompt

After completing all implementation tasks, use the following prompt for a comprehensive re-review:

---

**FINAL REVIEW PROMPT:**

```
I need you to perform a thorough follow-up review of the ppds-tools repository
after implementing the improvements from our previous code review.

Please evaluate:

1. **Implementation Verification**
   - Verify each item from IMPLEMENTATION-PLAN.md was completed correctly
   - Check that no new issues were introduced during refactoring
   - Confirm all acceptance criteria are met

2. **Code Quality Re-Assessment**
   - Re-grade the codebase on the same criteria as before:
     - Overall quality (A-F)
     - SOLID principles adherence (grade each principle)
     - Test coverage (percentage and quality)
     - Documentation completeness
   - Compare grades to previous review

3. **Test Verification**
   - Run the test suite and verify all tests pass
   - Check that code coverage meets 80% target
   - Verify PSScriptAnalyzer reports no errors or warnings

4. **Regression Check**
   - Verify all 5 public functions still work as documented
   - Check that refactored code maintains original behavior
   - Verify no breaking changes to public API

5. **Release Readiness**
   - Is the module ready for v1.0 release to PowerShell Gallery?
   - Any remaining blockers or concerns?
   - Final recommendations before publishing

6. **Documentation Review**
   - CHANGELOG.md is complete and accurate
   - README.md reflects current functionality
   - Comment-based help is accurate

Please provide:
- A summary comparison table (Before vs After grades)
- List of any remaining issues found
- Final release recommendation (Ready / Not Ready with reasons)
```

---

#### Acceptance Criteria

- [ ] All previous tasks marked ✅ Completed
- [ ] Final review prompt executed
- [ ] All tests passing
- [ ] Code coverage ≥ 80%
- [ ] PSScriptAnalyzer clean
- [ ] Reviewer confirms release readiness

---

## Execution Order

Recommended order to minimize conflicts and maximize efficiency:

```
Phase 1: Foundation (No code changes)
├── Task 5: Add CHANGELOG.md
└── Task 9: Add Pester Tags

Phase 2: Infrastructure (CI/Testing)
├── Task 1: Add PSScriptAnalyzer to CI
├── Task 7: Add Code Coverage to CI
└── Task 2: Add Unit Tests for JSON Utilities

Phase 3: Code Quality (Refactoring)
├── Task 4: Escape OData Filter Values
├── Task 3: Extract Shared Assembly Resolution
├── Task 6: Refactor Large Functions
└── Task 8: Extract Hardcoded OAuth AppId

Phase 4: Finalization
├── Task 10: Document Async Decision
└── Task 11: Final Review
```

---

## Notes

- All changes should be committed with descriptive messages
- Run tests locally before pushing
- Update CHANGELOG.md as tasks are completed
- This document should be deleted after successful v1.0 release

---

## Version History

| Date | Change |
|------|--------|
| 2025-12-15 | Initial plan created |
