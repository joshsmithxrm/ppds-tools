# Opt in with an exact packaged ppds.dll (or executable) and a built synthetic fixture.
# These tests only run local extraction and schema analysis; they never use profiles.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PPDS.Tools') -Force
}

Describe 'Packaged CLI offline contracts' -Tag 'OfflineCli' -Skip:(-not $env:PPDS_TEST_CLI_PATH -or -not $env:PPDS_TEST_PLUGIN_PATH) {
    BeforeAll {
        $fixtureDir = Join-Path $TestDrive 'fixture with spaces'
        New-Item -ItemType Directory -Path $fixtureDir | Out-Null
        Copy-Item (Join-Path (Split-Path $env:PPDS_TEST_PLUGIN_PATH) '*.dll') -Destination $fixtureDir
        $pluginPath = Join-Path $fixtureDir (Split-Path $env:PPDS_TEST_PLUGIN_PATH -Leaf)
        $schemaPath = Join-Path $fixtureDir 'schema.xml'
        '<entities><entity name="account" displayname="Account" etc="1" primaryidfield="accountid" primarynamefield="name"><fields><field name="accountid" type="guid" primaryKey="true"/><field name="name" type="string"/></fields></entity></entities>' | Set-Content -LiteralPath $schemaPath
        Mock Get-PpdsCli { $env:PPDS_TEST_CLI_PATH } -ModuleName PPDS.Tools
    }

    It 'analyzes a synthetic schema through the public wrapper' {
        $graph = Get-DataverseDependencyGraph -SchemaPath $schemaPath
        $graph.entityCount | Should -Be 1
        $graph.dependencyCount | Should -Be 0
        ($graph.tiers | ConvertTo-Json -Depth 10) | Should -Match 'account'
        (Get-DataverseDependencyGraph -SchemaPath $schemaPath -AsJson | ConvertFrom-Json).entityCount | Should -Be 1
    }

    It 'extracts an unwrapped registration object without writing a PassThru output file' {
        $outputPath = Join-Path $fixtureDir 'stdout only.json'
        $registration = Get-DataversePluginRegistrations -InputPath $pluginPath -OutputPath $outputPath -Solution 'fixture_solution' -PassThru
        $registration.assemblies.Count | Should -Be 1
        $registration.assemblies[0].name | Should -Be 'ContractPlugin'
        $registration.assemblies[0].solution | Should -Be 'fixture_solution'
        $registration.assemblies[0].types[0].typeName | Should -Be 'ContractFixture.AccountPlugin'
        $registration.assemblies[0].types[0].steps[0].message | Should -Be 'Update'
        $registration.PSObject.Properties.Name | Should -Not -Contain 'success'
        Test-Path -LiteralPath $outputPath | Should -BeFalse
    }

    It 'writes extraction output relative to the PowerShell working location' {
        Push-Location $fixtureDir
        try {
            Get-DataversePluginRegistrations -InputPath $pluginPath -OutputPath './written registrations.json' -Force
            $registration = Get-Content './written registrations.json' -Raw | ConvertFrom-Json
            $registration.assemblies[0].name | Should -Be 'ContractPlugin'
            $registration.assemblies[0].types[0].typeName | Should -Be 'ContractFixture.AccountPlugin'
        }
        finally { Pop-Location }
    }
}
