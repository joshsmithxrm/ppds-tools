# CLI compatibility and testing

PPDS.Tools 1.2.0-alpha3 retains the prerelease CLI-wrapper API. PPDS.Tools 1.1.0 is the earlier stable native implementation. These repairs do not publish a package or promote the 1.2 API to stable.

## Supported contract

The baseline is the exact published PPDS.Cli 1.4.1 package. The maintenance 1.4.2 candidate is checked locally with the same offline tests; it is not required by this module or public CI. A successful offline check is not evidence of live authentication, deployment or migration success.

| Command family | Output handling |
| --- | --- |
| Auth who/list | Complete JSON document; `active` / `profiles` properties |
| Plugin extract/deploy/diff/clean/list | `--output-format Json`; unwrap successful `data` envelope for `-PassThru` |
| Data analyze | Complete raw JSON dependency document |
| Data export/import/copy | JSON-lines progress on stderr; final result uses `failureCount` and `success` |

Extraction with `-PassThru` returns the configuration without writing an output file, matching the CLI's JSON mode. Omit `-PassThru` to write the configuration. Plugin drift exit code 1 is accepted only with a successful JSON envelope; it remains a visible warning without `-PassThru`. Error envelopes and other nonzero codes throw, including authentication, validation and environment-safety refusals.

Plugin `-WhatIf` delegates to CLI `--dry-run`, which may authenticate and read the environment. PowerShell confirmation remains in effect for regular deployment and cleanup. No wrapper adds a CLI force or safety-bypass flag implicitly. Authentication keeps the console attached for browser/device-code prompts. Wrapper diagnostics never print assembled credential arguments, and captured failure details redact supplied secrets.

## Reproduce offline validation

Use PowerShell 7 and Pester **5.7.1**. The normal tests use synthetic values and a mock CLI process boundary. Process tests launch only synthetic PowerShell children. Optional packaged tests run only extraction and local schema analysis.

```powershell
# Point to an exact, fully extracted ppds.dll with its dependency files.
$env:PPDS_TEST_CLI_PATH = '/path/to/packaged/net8.0/any/ppds.dll'
dotnet build ./tests/fixtures/ContractPlugin/ContractPlugin.csproj --configuration Release `
    "-p:PpdsCliDirectory=$(Split-Path $env:PPDS_TEST_CLI_PATH)"
$env:PPDS_TEST_PLUGIN_PATH = (Resolve-Path ./tests/fixtures/ContractPlugin/bin/Release/net462/ContractPlugin.dll).Path

Import-Module Pester -RequiredVersion 5.7.1
$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Run.PassThru = $true
$config.TestRegistry.Enabled = $false # Tests do not need Windows registry access.
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) { throw 'Tests failed' }
```

Without both environment variables, packaged CLI tests are skipped. CI installs 1.4.1 into a runner-local tool directory and runs those tests. PSScriptAnalyzer **1.24.0** uses the repository settings. Required CI contexts remain `lint`, `test` and `validate-module`.
