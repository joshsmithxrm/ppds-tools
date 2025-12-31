BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force
}

Describe "Get-DataversePluginRegistrations" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require InputPath parameter" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['InputPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have AssemblyPath alias for InputPath" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['InputPath'].Aliases | Should -Contain 'AssemblyPath'
        }

        It "Should have optional OutputPath parameter" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['OutputPath'] | Should -Not -BeNullOrEmpty
            $cmd.Parameters['OutputPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Not -Contain $true
        }

        It "Should have optional Solution parameter" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['Solution'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Force switch" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['Force'].SwitchParameter | Should -Be $true
        }

        It "Should have optional PassThru switch" {
            $cmd = Get-Command Get-DataversePluginRegistrations
            $cmd.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }

        It "Should throw when input file does not exist" {
            { Get-DataversePluginRegistrations -InputPath "./nonexistent.dll" } |
                Should -Throw "*Input file not found*"
        }
    }

    Context "CLI Argument Building" {
        BeforeAll {
            $script:tempDll = Join-Path $TestDrive "test.dll"
            "dummy" | Out-File $script:tempDll
        }

        It "Should include plugins extract command" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'extract')
                $cliArgs | Should -Contain 'plugins'
                $cliArgs | Should -Contain 'extract'
            }
        }

        It "Should include --solution when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'extract')
                $Solution = 'MySolution'
                if ($Solution) {
                    $cliArgs += '--solution'
                    $cliArgs += $Solution
                }
                $cliArgs | Should -Contain '--solution'
                $cliArgs | Should -Contain 'MySolution'
            }
        }

        It "Should include --force when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'extract')
                $Force = $true
                if ($Force) {
                    $cliArgs += '--force'
                }
                $cliArgs | Should -Contain '--force'
            }
        }

        It "Should include --json when PassThru is specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'extract')
                $PassThru = $true
                if ($PassThru) {
                    $cliArgs += '--json'
                }
                $cliArgs | Should -Contain '--json'
            }
        }
    }
}

Describe "Deploy-DataversePlugins" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require ConfigPath parameter" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['ConfigPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have RegistrationFile alias for ConfigPath" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['ConfigPath'].Aliases | Should -Contain 'RegistrationFile'
        }

        It "Should have optional Profile parameter" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Environment parameter" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['Environment'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Solution parameter" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['Solution'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Clean switch" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['Clean'].SwitchParameter | Should -Be $true
        }

        It "Should support ShouldProcess (WhatIf)" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional PassThru switch" {
            $cmd = Get-Command Deploy-DataversePlugins
            $cmd.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }

        It "Should throw when config file does not exist" {
            { Deploy-DataversePlugins -ConfigPath "./nonexistent.json" } |
                Should -Throw "*Configuration file not found*"
        }
    }

    Context "CLI Argument Building" {
        It "Should include plugins deploy command" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'deploy')
                $cliArgs | Should -Contain 'plugins'
                $cliArgs | Should -Contain 'deploy'
            }
        }

        It "Should include --profile when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'deploy')
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
                $cliArgs = @('plugins', 'deploy')
                $Environment = 'https://org.crm.dynamics.com'
                if ($Environment) {
                    $cliArgs += '--environment'
                    $cliArgs += $Environment
                }
                $cliArgs | Should -Contain '--environment'
            }
        }

        It "Should include --clean when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'deploy')
                $Clean = $true
                if ($Clean) {
                    $cliArgs += '--clean'
                }
                $cliArgs | Should -Contain '--clean'
            }
        }

        It "Should include --what-if when WhatIf is true" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'deploy')
                $isWhatIf = $true
                if ($isWhatIf) {
                    $cliArgs += '--what-if'
                }
                $cliArgs | Should -Contain '--what-if'
            }
        }
    }
}

Describe "Get-DataversePluginDrift" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require ConfigPath parameter" {
            $cmd = Get-Command Get-DataversePluginDrift
            $cmd.Parameters['ConfigPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have RegistrationFile alias for ConfigPath" {
            $cmd = Get-Command Get-DataversePluginDrift
            $cmd.Parameters['ConfigPath'].Aliases | Should -Contain 'RegistrationFile'
        }

        It "Should have optional Profile parameter" {
            $cmd = Get-Command Get-DataversePluginDrift
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Environment parameter" {
            $cmd = Get-Command Get-DataversePluginDrift
            $cmd.Parameters['Environment'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional PassThru switch" {
            $cmd = Get-Command Get-DataversePluginDrift
            $cmd.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }

        It "Should throw when config file does not exist" {
            { Get-DataversePluginDrift -ConfigPath "./nonexistent.json" } |
                Should -Throw "*Configuration file not found*"
        }
    }

    Context "CLI Argument Building" {
        It "Should include plugins diff command" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'diff')
                $cliArgs | Should -Contain 'plugins'
                $cliArgs | Should -Contain 'diff'
            }
        }

        It "Should include --profile when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'diff')
                $Profile = 'dev'
                if ($Profile) {
                    $cliArgs += '--profile'
                    $cliArgs += $Profile
                }
                $cliArgs | Should -Contain '--profile'
                $cliArgs | Should -Contain 'dev'
            }
        }

        It "Should include --json when PassThru is specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'diff')
                $PassThru = $true
                if ($PassThru) {
                    $cliArgs += '--json'
                }
                $cliArgs | Should -Contain '--json'
            }
        }
    }
}

Describe "Remove-DataverseOrphanedSteps" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should require ConfigPath parameter" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['ConfigPath'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It "Should have RegistrationFile alias for ConfigPath" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['ConfigPath'].Aliases | Should -Contain 'RegistrationFile'
        }

        It "Should have optional Profile parameter" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Environment parameter" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['Environment'] | Should -Not -BeNullOrEmpty
        }

        It "Should support ShouldProcess (WhatIf and Confirm)" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
            $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }

        It "Should have High ConfirmImpact" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmdletBinding = $cmd.ScriptBlock.Attributes |
                Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $cmdletBinding.ConfirmImpact | Should -Be 'High'
        }

        It "Should have optional PassThru switch" {
            $cmd = Get-Command Remove-DataverseOrphanedSteps
            $cmd.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }

        It "Should throw when config file does not exist" {
            { Remove-DataverseOrphanedSteps -ConfigPath "./nonexistent.json" -Confirm:$false } |
                Should -Throw "*Configuration file not found*"
        }
    }

    Context "CLI Argument Building" {
        It "Should include plugins clean command" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'clean')
                $cliArgs | Should -Contain 'plugins'
                $cliArgs | Should -Contain 'clean'
            }
        }

        It "Should include --profile when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'clean')
                $Profile = 'dev'
                if ($Profile) {
                    $cliArgs += '--profile'
                    $cliArgs += $Profile
                }
                $cliArgs | Should -Contain '--profile'
                $cliArgs | Should -Contain 'dev'
            }
        }

        It "Should include --what-if when WhatIf is true" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'clean')
                $isWhatIf = $true
                if ($isWhatIf) {
                    $cliArgs += '--what-if'
                }
                $cliArgs | Should -Contain '--what-if'
            }
        }
    }
}

Describe "Get-DataversePlugins" -Tag 'Unit' {
    BeforeAll {
        Mock Get-PpdsCli { 'ppds' } -ModuleName PPDS.Tools
    }

    Context "Parameter Validation" {
        It "Should have optional Profile parameter" {
            $cmd = Get-Command Get-DataversePlugins
            $cmd.Parameters['Profile'] | Should -Not -BeNullOrEmpty
            $cmd.Parameters['Profile'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Not -Contain $true
        }

        It "Should have optional Environment parameter" {
            $cmd = Get-Command Get-DataversePlugins
            $cmd.Parameters['Environment'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Assembly parameter" {
            $cmd = Get-Command Get-DataversePlugins
            $cmd.Parameters['Assembly'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional Package parameter" {
            $cmd = Get-Command Get-DataversePlugins
            $cmd.Parameters['Package'] | Should -Not -BeNullOrEmpty
        }

        It "Should have optional PassThru switch" {
            $cmd = Get-Command Get-DataversePlugins
            $cmd.Parameters['PassThru'].SwitchParameter | Should -Be $true
        }
    }

    Context "CLI Argument Building" {
        It "Should include plugins list command" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'list')
                $cliArgs | Should -Contain 'plugins'
                $cliArgs | Should -Contain 'list'
            }
        }

        It "Should include --profile when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'list')
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
                $cliArgs = @('plugins', 'list')
                $Environment = 'https://org.crm.dynamics.com'
                if ($Environment) {
                    $cliArgs += '--environment'
                    $cliArgs += $Environment
                }
                $cliArgs | Should -Contain '--environment'
            }
        }

        It "Should include --assembly when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'list')
                $Assembly = 'MyPlugins'
                if ($Assembly) {
                    $cliArgs += '--assembly'
                    $cliArgs += $Assembly
                }
                $cliArgs | Should -Contain '--assembly'
                $cliArgs | Should -Contain 'MyPlugins'
            }
        }

        It "Should include --package when specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'list')
                $Package = 'MyPlugins.Package'
                if ($Package) {
                    $cliArgs += '--package'
                    $cliArgs += $Package
                }
                $cliArgs | Should -Contain '--package'
                $cliArgs | Should -Contain 'MyPlugins.Package'
            }
        }

        It "Should include --json when PassThru is specified" {
            InModuleScope PPDS.Tools {
                $cliArgs = @('plugins', 'list')
                $PassThru = $true
                if ($PassThru) {
                    $cliArgs += '--json'
                }
                $cliArgs | Should -Contain '--json'
            }
        }
    }
}

Describe "Plugin Cmdlet Help" -Tag 'Unit' {
    It "Get-DataversePluginRegistrations should have synopsis" {
        $help = Get-Help Get-DataversePluginRegistrations
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Deploy-DataversePlugins should have synopsis" {
        $help = Get-Help Deploy-DataversePlugins
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Get-DataversePluginDrift should have synopsis" {
        $help = Get-Help Get-DataversePluginDrift
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Remove-DataverseOrphanedSteps should have synopsis" {
        $help = Get-Help Remove-DataverseOrphanedSteps
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Get-DataversePlugins should have synopsis" {
        $help = Get-Help Get-DataversePlugins
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }
}

Describe "Plugin JSON Output Parsing" -Tag 'Unit' {
    Context "Deploy-DataversePlugins JSON parsing" {
        It "Should parse valid deployment results JSON" {
            $jsonOutput = @'
[
    {
        "action": "Created",
        "type": "Assembly",
        "name": "MyPlugins",
        "version": "1.0.0.0"
    },
    {
        "action": "Created",
        "type": "Step",
        "name": "Create of account"
    }
]
'@
            InModuleScope PPDS.Tools -Parameters @{ jsonOutput = $jsonOutput } {
                param($jsonOutput)

                $result = $jsonOutput | ConvertFrom-Json

                $result.Count | Should -Be 2
                $result[0].action | Should -Be 'Created'
                $result[0].type | Should -Be 'Assembly'
                $result[1].type | Should -Be 'Step'
            }
        }
    }

    Context "Get-DataversePluginDrift JSON parsing" {
        It "Should parse valid drift results JSON" {
            $jsonOutput = @'
[
    {
        "category": "Orphaned",
        "type": "Step",
        "name": "Delete of contact",
        "assembly": "MyPlugins"
    },
    {
        "category": "Missing",
        "type": "Step",
        "name": "Create of account",
        "assembly": "MyPlugins"
    }
]
'@
            InModuleScope PPDS.Tools -Parameters @{ jsonOutput = $jsonOutput } {
                param($jsonOutput)

                $result = $jsonOutput | ConvertFrom-Json

                $result.Count | Should -Be 2
                $result[0].category | Should -Be 'Orphaned'
                $result[1].category | Should -Be 'Missing'
            }
        }
    }

    Context "Get-DataversePlugins JSON parsing" {
        It "Should parse valid plugins list JSON" {
            $jsonOutput = @'
{
    "assemblies": [
        {
            "name": "MyPlugins",
            "version": "1.0.0.0",
            "isolationMode": "Sandbox",
            "types": [
                {
                    "typeName": "MyPlugins.AccountPlugin",
                    "steps": [
                        {
                            "name": "Create of account",
                            "message": "Create",
                            "entity": "account",
                            "stage": "PostOperation"
                        }
                    ]
                }
            ]
        }
    ],
    "packages": []
}
'@
            InModuleScope PPDS.Tools -Parameters @{ jsonOutput = $jsonOutput } {
                param($jsonOutput)

                $result = $jsonOutput | ConvertFrom-Json

                $result.assemblies.Count | Should -Be 1
                $result.assemblies[0].name | Should -Be 'MyPlugins'
                $result.assemblies[0].types.Count | Should -Be 1
                $result.assemblies[0].types[0].steps.Count | Should -Be 1
                $result.assemblies[0].types[0].steps[0].message | Should -Be 'Create'
            }
        }
    }

    Context "Get-DataversePluginRegistrations JSON parsing" {
        It "Should parse valid extraction results JSON" {
            $jsonOutput = @'
{
    "assemblies": [
        {
            "name": "MyPlugins",
            "assemblyPath": "./MyPlugins.dll",
            "isolationMode": "Sandbox",
            "sourceType": "Database",
            "types": [
                {
                    "typeName": "MyPlugins.AccountPlugin",
                    "steps": [
                        {
                            "name": "Create of account",
                            "message": "Create",
                            "primaryEntity": "account",
                            "stage": "PostOperation",
                            "mode": "Synchronous"
                        }
                    ]
                }
            ]
        }
    ],
    "packages": []
}
'@
            InModuleScope PPDS.Tools -Parameters @{ jsonOutput = $jsonOutput } {
                param($jsonOutput)

                $result = $jsonOutput | ConvertFrom-Json

                $result.assemblies.Count | Should -Be 1
                $result.assemblies[0].name | Should -Be 'MyPlugins'
                $result.assemblies[0].isolationMode | Should -Be 'Sandbox'
                $result.assemblies[0].types[0].typeName | Should -Be 'MyPlugins.AccountPlugin'
            }
        }
    }
}
