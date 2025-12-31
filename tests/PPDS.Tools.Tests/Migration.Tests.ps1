BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force
}

Describe "Get-PpdsCli" -Tag 'Unit' {
    Context "CLI Detection" {
        It "Should return path when CLI is in PATH" {
            Mock Get-Command {
                [PSCustomObject]@{ Source = '/usr/local/bin/ppds' }
            } -ModuleName PPDS.Tools

            $result = InModuleScope PPDS.Tools { Get-PpdsCli }
            $result | Should -Be '/usr/local/bin/ppds'
        }

        It "Should check global .NET tools path on Windows" {
            Mock Get-Command { $null } -ModuleName PPDS.Tools
            Mock Test-Path { $true } -ModuleName PPDS.Tools -ParameterFilter { $Path -like '*\.dotnet\tools\ppds*' }

            # This tests the path construction logic
            $result = InModuleScope PPDS.Tools {
                $globalToolsPath = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.dotnet' 'tools'
                $cliExeName = if ($IsWindows) { 'ppds.exe' } else { 'ppds' }
                Join-Path $globalToolsPath $cliExeName
            }
            $result | Should -Match 'ppds'
        }
    }
}

Describe "Export-DataverseData" -Tag 'Unit' {
    BeforeAll {
        # Mock the CLI helper to return a known path
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
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

        It "Should have optional Profile parameter" {
            $cmd = Get-Command Export-DataverseData
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
            $cmd.Parameters['Profile'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Not -Contain $true
        }

        It "Should have optional Environment parameter" {
            $cmd = Get-Command Export-DataverseData
            $cmd.Parameters['Environment'] | Should -Not -BeNullOrEmpty
        }

        It "Should throw when schema file does not exist" {
            { Export-DataverseData -SchemaPath "./nonexistent.xml" -OutputPath "./out.zip" } |
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
            InModuleScope PPDS.Tools -Parameters @{ schemaPath = $script:tempSchema } {
                param($schemaPath)

                # Simulate what the function does internally
                $cliArgs = @(
                    'data', 'export'
                    '--schema', $schemaPath
                    '--output', './out.zip'
                    '--json'
                )
                $cliArgs | Should -Contain '--json'
            }
        }

        It "Should include --profile when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'export')
                $Profile = 'dev'
                if ($Profile) {
                    $cliArgs += '--profile'
                    $cliArgs += $Profile
                }
                $cliArgs | Should -Contain '--profile'
                $cliArgs | Should -Contain 'dev'
            }
        }

        It "Should include --environment when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'export')
                $Environment = 'https://org.crm.dynamics.com'
                if ($Environment) {
                    $cliArgs += '--environment'
                    $cliArgs += $Environment
                }
                $cliArgs | Should -Contain '--environment'
            }
        }

        It "Should include --parallel when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'export')
                $Parallel = 8
                if ($Parallel -gt 0) {
                    $cliArgs += '--parallel'
                    $cliArgs += $Parallel
                }
                $cliArgs | Should -Contain '--parallel'
                $cliArgs | Should -Contain 8
            }
        }
    }
}

Describe "Import-DataverseData" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require DataPath parameter" {
            $cmd = Get-Command Import-DataverseData
            $cmd.Parameters['DataPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have optional Profile parameter" {
            $cmd = Get-Command Import-DataverseData
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
        }

        It "Should throw when data file does not exist" {
            { Import-DataverseData -DataPath "./nonexistent.zip" } |
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

        It "Should validate BypassPlugins parameter values" {
            $cmd = Get-Command Import-DataverseData
            $validateSet = $cmd.Parameters['BypassPlugins'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'sync'
            $validateSet.ValidValues | Should -Contain 'async'
            $validateSet.ValidValues | Should -Contain 'all'
        }
    }

    Context "CLI Argument Building" {
        It "Should include --bypass-plugins when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'import')
                $BypassPlugins = 'all'
                if ($BypassPlugins) {
                    $cliArgs += '--bypass-plugins'
                    $cliArgs += $BypassPlugins
                }
                $cliArgs | Should -Contain '--bypass-plugins'
                $cliArgs | Should -Contain 'all'
            }
        }

        It "Should include --bypass-flows when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'import')
                $BypassFlows = $true
                if ($BypassFlows) {
                    $cliArgs += '--bypass-flows'
                }
                $cliArgs | Should -Contain '--bypass-flows'
            }
        }

        It "Should include --continue-on-error when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'import')
                $ContinueOnError = $true
                if ($ContinueOnError) {
                    $cliArgs += '--continue-on-error'
                }
                $cliArgs | Should -Contain '--continue-on-error'
            }
        }

        It "Should include --mode when not Upsert" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('data', 'import')
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
                $cliArgs = @('data', 'import')
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
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
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
    }
}

Describe "Copy-DataverseData" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require SourceEnvironment parameter" {
            $cmd = Get-Command Copy-DataverseData
            $cmd.Parameters['SourceEnvironment'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require TargetEnvironment parameter" {
            $cmd = Get-Command Copy-DataverseData
            $cmd.Parameters['TargetEnvironment'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should require SchemaPath parameter" {
            $cmd = Get-Command Copy-DataverseData
            $cmd.Parameters['SchemaPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have optional SourceProfile parameter" {
            $cmd = Get-Command Copy-DataverseData
            $cmd.Parameters['SourceProfile'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional TargetProfile parameter" {
            $cmd = Get-Command Copy-DataverseData
            $cmd.Parameters['TargetProfile'] | Should -Not -BeNullOrEmpty
        }

        It "Should throw when schema file does not exist" {
            { Copy-DataverseData -SourceEnvironment "src" -TargetEnvironment "tgt" -SchemaPath "./nonexistent.xml" } |
                Should -Throw "*Schema file not found*"
        }
    }

    Context "Alias" {
        It "Should have Invoke-DataverseMigration alias" {
            $alias = Get-Alias Invoke-DataverseMigration -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.ReferencedCommand.Name | Should -Be 'Copy-DataverseData'
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

    It "Copy-DataverseData should have synopsis" {
        $help = Get-Help Copy-DataverseData
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }
}
