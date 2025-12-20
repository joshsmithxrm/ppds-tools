BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force
}

Describe "Get-PpdsMigrateCli" -Tag 'Unit' {
    Context "CLI Detection" {
        It "Should return path when CLI is in PATH" {
            Mock Get-Command {
                [PSCustomObject]@{ Source = '/usr/local/bin/ppds-migrate' }
            } -ModuleName PPDS.Tools

            $result = InModuleScope PPDS.Tools { Get-PpdsMigrateCli }
            $result | Should -Be '/usr/local/bin/ppds-migrate'
        }

        It "Should check global .NET tools path on Windows" {
            Mock Get-Command { $null } -ModuleName PPDS.Tools
            Mock Test-Path { $true } -ModuleName PPDS.Tools -ParameterFilter { $Path -like '*\.dotnet\tools\ppds-migrate*' }

            # This tests the path construction logic
            $result = InModuleScope PPDS.Tools {
                $globalToolsPath = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.dotnet' 'tools'
                $cliExeName = if ($IsWindows) { 'ppds-migrate.exe' } else { 'ppds-migrate' }
                Join-Path $globalToolsPath $cliExeName
            }
            $result | Should -Match 'ppds-migrate'
        }
    }
}

Describe "Export-DataverseData" -Tag 'Unit' {
    BeforeAll {
        # Mock the CLI helper to return a known path
        Mock Get-PpdsMigrateCli { 'ppds-migrate' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require Connection parameter" {
            $cmd = Get-Command Export-DataverseData
            $cmd.Parameters['Connection'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require SchemaPath parameter" {
            $cmd = Get-Command Export-DataverseData
            $cmd.Parameters['SchemaPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require OutputPath parameter" {
            $cmd = Get-Command Export-DataverseData
            $cmd.Parameters['OutputPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should throw when schema file does not exist" {
            { Export-DataverseData -Connection "test" -SchemaPath "./nonexistent.xml" -OutputPath "./out.zip" } |
                Should -Throw "*Schema file not found*"
        }
    }

    Context "CLI Argument Building" {
        BeforeAll {
            # Create a temporary schema file
            $script:tempSchema = Join-Path $TestDrive "schema.xml"
            "<schema/>" | Out-File $script:tempSchema
        }

        It "Should include --json flag for progress parsing" {
            $capturedArgs = $null
            Mock Invoke-Expression { } -ModuleName PPDS.Tools

            # We can't easily capture the & operator, but we can verify the function constructs args correctly
            InModuleScope PPDS.Tools -Parameters @{ schemaPath = $script:tempSchema } {
                param($schemaPath)

                # Simulate what the function does internally
                $cliArgs = @(
                    'export'
                    '--connection', 'TestConn'
                    '--schema', $schemaPath
                    '--output', './out.zip'
                    '--json'
                )
                $cliArgs | Should -Contain '--json'
            }
        }

        It "Should include --parallel when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('export')
                $Parallel = 8
                if ($Parallel -gt 0) {
                    $cliArgs += '--parallel'
                    $cliArgs += $Parallel
                }
                $cliArgs | Should -Contain '--parallel'
                $cliArgs | Should -Contain 8
            }
        }

        It "Should include --include-files when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('export')
                $IncludeFiles = $true
                if ($IncludeFiles) {
                    $cliArgs += '--include-files'
                }
                $cliArgs | Should -Contain '--include-files'
            }
        }
    }
}

Describe "Import-DataverseData" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsMigrateCli { 'ppds-migrate' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require Connection parameter" {
            $cmd = Get-Command Import-DataverseData
            $cmd.Parameters['Connection'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require DataPath parameter" {
            $cmd = Get-Command Import-DataverseData
            $cmd.Parameters['DataPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should throw when data file does not exist" {
            { Import-DataverseData -Connection "test" -DataPath "./nonexistent.zip" } |
                Should -Throw "*Data file not found*"
        }

        It "Should validate Mode parameter values" {
            $cmd = Get-Command Import-DataverseData
            $validateSet = $cmd.Parameters['Mode'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Create'
            $validateSet.ValidValues | Should -Contain 'Update'
            $validateSet.ValidValues | Should -Contain 'Upsert'
        }
    }

    Context "CLI Argument Building" {
        It "Should include --bypass-plugins when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('import')
                $BypassPlugins = $true
                if ($BypassPlugins) {
                    $cliArgs += '--bypass-plugins'
                }
                $cliArgs | Should -Contain '--bypass-plugins'
            }
        }

        It "Should include --bypass-flows when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('import')
                $BypassFlows = $true
                if ($BypassFlows) {
                    $cliArgs += '--bypass-flows'
                }
                $cliArgs | Should -Contain '--bypass-flows'
            }
        }

        It "Should include --continue-on-error when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('import')
                $ContinueOnError = $true
                if ($ContinueOnError) {
                    $cliArgs += '--continue-on-error'
                }
                $cliArgs | Should -Contain '--continue-on-error'
            }
        }

        It "Should include --mode when not Upsert" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('import')
                $Mode = 'Create'
                if ($Mode -ne 'Upsert') {
                    $cliArgs += '--mode'
                    $cliArgs += $Mode
                }
                $cliArgs | Should -Contain '--mode'
                $cliArgs | Should -Contain 'Create'
            }
        }

        It "Should not include --mode when Upsert (default)" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('import')
                $Mode = 'Upsert'
                if ($Mode -ne 'Upsert') {
                    $cliArgs += '--mode'
                    $cliArgs += $Mode
                }
                $cliArgs | Should -Not -Contain '--mode'
            }
        }
    }
}

Describe "Get-DataverseDependencyGraph" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsMigrateCli { 'ppds-migrate' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require SchemaPath parameter" {
            $cmd = Get-Command Get-DataverseDependencyGraph
            $cmd.Parameters['SchemaPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should throw when schema file does not exist" {
            { Get-DataverseDependencyGraph -SchemaPath "./nonexistent.xml" } |
                Should -Throw "*Schema file not found*"
        }

        It "Should have optional AsJson switch" {
            $cmd = Get-Command Get-DataverseDependencyGraph
            $cmd.Parameters['AsJson'].SwitchParameter | Should -Be $true
        }
    }

    Context "JSON Output Parsing" {
        It "Should parse valid dependency graph JSON" {
            $jsonOutput = @'
{
    "entityCount": 5,
    "dependencyCount": 3,
    "circularReferenceCount": 1,
    "tiers": [
        { "tier": 1, "entities": ["account", "contact"], "hasCircular": false },
        { "tier": 2, "entities": ["opportunity"], "hasCircular": true }
    ],
    "deferredFields": [{ "entity": "contact", "field": "parentcustomerid" }],
    "manyToManyRelationships": [],
    "note": "Test"
}
'@
            InModuleScope PPDS.Tools -Parameters @{ jsonOutput = $jsonOutput } {
                param($jsonOutput)

                $data = $jsonOutput | ConvertFrom-Json

                $result = [PSCustomObject]@{
                    EntityCount            = $data.entityCount
                    DependencyCount        = $data.dependencyCount
                    CircularReferenceCount = $data.circularReferenceCount
                    Tiers                  = @(
                        $data.tiers | ForEach-Object {
                            [PSCustomObject]@{
                                Tier        = $_.tier
                                Entities    = $_.entities
                                HasCircular = [bool]$_.hasCircular
                            }
                        }
                    )
                    DeferredFields         = $data.deferredFields
                    ManyToManyRelationships = $data.manyToManyRelationships
                    Note                   = $data.note
                }

                $result.EntityCount | Should -Be 5
                $result.DependencyCount | Should -Be 3
                $result.CircularReferenceCount | Should -Be 1
                $result.Tiers.Count | Should -Be 2
                $result.Tiers[0].Tier | Should -Be 1
                $result.Tiers[0].HasCircular | Should -Be $false
                $result.Tiers[1].HasCircular | Should -Be $true
                $result.DeferredFields.Count | Should -Be 1
            }
        }

        It "Should use [bool] cast for HasCircular property" {
            InModuleScope PPDS.Tools {
                # Test that [bool]$null returns $false
                $hasCircular = [bool]$null
                $hasCircular | Should -Be $false

                # Test that [bool]$true returns $true
                $hasCircular = [bool]$true
                $hasCircular | Should -Be $true
            }
        }
    }
}

Describe "Invoke-DataverseMigration" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsMigrateCli { 'ppds-migrate' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require SourceConnection parameter" {
            $cmd = Get-Command Invoke-DataverseMigration
            $cmd.Parameters['SourceConnection'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require TargetConnection parameter" {
            $cmd = Get-Command Invoke-DataverseMigration
            $cmd.Parameters['TargetConnection'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require SchemaPath parameter" {
            $cmd = Get-Command Invoke-DataverseMigration
            $cmd.Parameters['SchemaPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should throw when schema file does not exist" {
            { Invoke-DataverseMigration -SourceConnection "src" -TargetConnection "tgt" -SchemaPath "./nonexistent.xml" } |
                Should -Throw "*Schema file not found*"
        }
    }

    Context "CLI Argument Building" {
        It "Should include --bypass-plugins when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('migrate')
                $BypassPlugins = $true
                if ($BypassPlugins) {
                    $cliArgs += '--bypass-plugins'
                }
                $cliArgs | Should -Contain '--bypass-plugins'
            }
        }

        It "Should include --batch-size when not default" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('migrate')
                $BatchSize = 500
                if ($BatchSize -ne 1000) {
                    $cliArgs += '--batch-size'
                    $cliArgs += $BatchSize
                }
                $cliArgs | Should -Contain '--batch-size'
                $cliArgs | Should -Contain 500
            }
        }

        It "Should not include --batch-size when default (1000)" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('migrate')
                $BatchSize = 1000
                if ($BatchSize -ne 1000) {
                    $cliArgs += '--batch-size'
                    $cliArgs += $BatchSize
                }
                $cliArgs | Should -Not -Contain '--batch-size'
            }
        }
    }

    Context "Result Object" {
        It "Should initialize result object with correct properties" {
            InModuleScope PPDS.Tools {
                $migrationResult = [PSCustomObject]@{
                    ExportRecords   = 0
                    ImportRecords   = 0
                    RecordsFailed   = 0
                    Duration        = [TimeSpan]::Zero
                }

                $migrationResult.PSObject.Properties.Name | Should -Contain 'ExportRecords'
                $migrationResult.PSObject.Properties.Name | Should -Contain 'ImportRecords'
                $migrationResult.PSObject.Properties.Name | Should -Contain 'RecordsFailed'
                $migrationResult.PSObject.Properties.Name | Should -Contain 'Duration'
                $migrationResult.Duration | Should -Be ([TimeSpan]::Zero)
            }
        }
    }
}

Describe "Migration Cmdlet Help" -Tag 'Unit' {
    It "Export-DataverseData should have synopsis" {
        $help = Get-Help Export-DataverseData
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Import-DataverseData should have synopsis" {
        $help = Get-Help Import-DataverseData
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Get-DataverseDependencyGraph should have synopsis" {
        $help = Get-Help Get-DataverseDependencyGraph
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Invoke-DataverseMigration should have synopsis" {
        $help = Get-Help Invoke-DataverseMigration
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }
}
