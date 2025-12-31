BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force
}

Describe "PPDS.Tools Module" -Tag 'Unit' {
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module $modulePath -Force } | Should -Not -Throw
        }

        It "Should have a valid module manifest" {
            $manifestPath = Join-Path $modulePath "PPDS.Tools.psd1"
            { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
        }
    }

    Context "Exported Functions" {
        # Auth commands
        It "Should export Connect-DataverseEnvironment" {
            Get-Command -Module PPDS.Tools -Name Connect-DataverseEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DataverseProfile" {
            Get-Command -Module PPDS.Tools -Name Get-DataverseProfile | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DataverseProfiles" {
            Get-Command -Module PPDS.Tools -Name Get-DataverseProfiles | Should -Not -BeNullOrEmpty
        }

        # Plugin commands
        It "Should export Get-DataversePluginRegistrations" {
            Get-Command -Module PPDS.Tools -Name Get-DataversePluginRegistrations | Should -Not -BeNullOrEmpty
        }

        It "Should export Deploy-DataversePlugins" {
            Get-Command -Module PPDS.Tools -Name Deploy-DataversePlugins | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DataversePluginDrift" {
            Get-Command -Module PPDS.Tools -Name Get-DataversePluginDrift | Should -Not -BeNullOrEmpty
        }

        It "Should export Remove-DataverseOrphanedSteps" {
            Get-Command -Module PPDS.Tools -Name Remove-DataverseOrphanedSteps | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DataversePlugins" {
            Get-Command -Module PPDS.Tools -Name Get-DataversePlugins | Should -Not -BeNullOrEmpty
        }

        # Migration commands
        It "Should export Export-DataverseData" {
            Get-Command -Module PPDS.Tools -Name Export-DataverseData | Should -Not -BeNullOrEmpty
        }

        It "Should export Import-DataverseData" {
            Get-Command -Module PPDS.Tools -Name Import-DataverseData | Should -Not -BeNullOrEmpty
        }

        It "Should export Copy-DataverseData" {
            Get-Command -Module PPDS.Tools -Name Copy-DataverseData | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DataverseDependencyGraph" {
            Get-Command -Module PPDS.Tools -Name Get-DataverseDependencyGraph | Should -Not -BeNullOrEmpty
        }

        It "Should export exactly 12 public functions" {
            $commands = Get-Command -Module PPDS.Tools -CommandType Function
            $commands.Count | Should -Be 12
        }

        It "Should have Invoke-DataverseMigration alias for Copy-DataverseData" {
            $alias = Get-Alias Invoke-DataverseMigration -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.ReferencedCommand.Name | Should -Be 'Copy-DataverseData'
        }
    }

    Context "Function Help" {
        It "Connect-DataverseEnvironment should have synopsis" {
            $help = Get-Help Connect-DataverseEnvironment
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Get-DataversePluginRegistrations should have synopsis" {
            $help = Get-Help Get-DataversePluginRegistrations
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Deploy-DataversePlugins should have synopsis" {
            $cmd = Get-Command -Module PPDS.Tools -Name Deploy-DataversePlugins -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
            $cmd.Definition | Should -Match '\.SYNOPSIS'
        }
    }
}

Describe "Schema File" -Tag 'Unit' {
    It "Should include plugin-registration.schema.json" {
        $schemaPath = Join-Path $modulePath "Schemas/plugin-registration.schema.json"
        Test-Path $schemaPath | Should -Be $true
    }

    It "Should be valid JSON" {
        $schemaPath = Join-Path $modulePath "Schemas/plugin-registration.schema.json"
        { Get-Content $schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
}
