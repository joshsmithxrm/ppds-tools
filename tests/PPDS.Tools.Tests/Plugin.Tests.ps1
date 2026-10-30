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
