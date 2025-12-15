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
        It "Should export Connect-DataverseEnvironment" {
            Get-Command -Module PPDS.Tools -Name Connect-DataverseEnvironment | Should -Not -BeNullOrEmpty
        }

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

        It "Should export exactly 5 public functions" {
            $commands = Get-Command -Module PPDS.Tools
            $commands.Count | Should -Be 5
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
            # Note: This function has a typed parameter that requires Microsoft.Xrm.Tooling.Connector
            # which may not be available in CI. We test that the function exists and is documented.
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
