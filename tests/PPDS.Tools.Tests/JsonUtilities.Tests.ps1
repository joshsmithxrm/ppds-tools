BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force

    # Dot-source the private function for testing
    . (Join-Path $modulePath "Private/JsonUtilities.ps1")
}

Describe "ConvertTo-RegistrationJson" -Tag 'Unit' {
    Context "Basic JSON Generation" {
        It "Should produce valid JSON" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)

            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include `$schema property" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.'$schema' | Should -Not -BeNullOrEmpty
        }

        It "Should include version property" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.version | Should -Be "1.0"
        }

        It "Should include generatedAt timestamp" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.generatedAt | Should -Not -BeNullOrEmpty
            { [DateTime]::Parse($parsed.generatedAt) } | Should -Not -Throw
        }
    }

    Context "Assembly Serialization" {
        It "Should serialize assembly name and type" {
            $assembly = [PSCustomObject]@{
                name = "MyPlugins"
                type = "Assembly"
                solution = "MySolution"
                path = "./bin/MyPlugins.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].name | Should -Be "MyPlugins"
            $parsed.assemblies[0].type | Should -Be "Assembly"
            $parsed.assemblies[0].solution | Should -Be "MySolution"
            $parsed.assemblies[0].path | Should -Be "./bin/MyPlugins.dll"
        }

        It "Should handle null solution" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].solution | Should -Be $null
        }

        It "Should include allTypeNames when present" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                allTypeNames = @("Namespace.Plugin1", "Namespace.Plugin2")
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].allTypeNames | Should -HaveCount 2
            $parsed.assemblies[0].allTypeNames | Should -Contain "Namespace.Plugin1"
        }

        It "Should include packagePath for NuGet type" {
            $assembly = [PSCustomObject]@{
                name = "TestPackage"
                type = "Nuget"
                solution = "MySolution"
                path = "./bin/TestPackage.dll"
                packagePath = "./bin/TestPackage.1.0.0.nupkg"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].packagePath | Should -Be "./bin/TestPackage.1.0.0.nupkg"
        }
    }

    Context "Plugin and Step Serialization" {
        It "Should serialize plugin with steps" {
            $step = [PSCustomObject]@{
                name = "TestPlugin: Create of account"
                message = "Create"
                entity = "account"
                stage = "PreOperation"
                mode = "Synchronous"
                executionOrder = 1
                filteringAttributes = $null
                configuration = $null
                images = @()
            }

            $plugin = [PSCustomObject]@{
                typeName = "Namespace.TestPlugin"
                steps = @($step)
            }

            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @($plugin)
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].plugins | Should -HaveCount 1
            $parsed.assemblies[0].plugins[0].typeName | Should -Be "Namespace.TestPlugin"
            $parsed.assemblies[0].plugins[0].steps | Should -HaveCount 1
            $parsed.assemblies[0].plugins[0].steps[0].message | Should -Be "Create"
            $parsed.assemblies[0].plugins[0].steps[0].entity | Should -Be "account"
        }

        It "Should serialize step images" {
            $image = [PSCustomObject]@{
                name = "PreImage"
                imageType = "PreImage"
                attributes = "name,accountnumber"
                entityAlias = "PreImage"
            }

            $step = [PSCustomObject]@{
                name = "TestPlugin: Update of account"
                message = "Update"
                entity = "account"
                stage = "PreOperation"
                mode = "Synchronous"
                executionOrder = 1
                filteringAttributes = "name"
                configuration = $null
                images = @($image)
            }

            $plugin = [PSCustomObject]@{
                typeName = "Namespace.TestPlugin"
                steps = @($step)
            }

            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @($plugin)
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies[0].plugins[0].steps[0].images | Should -HaveCount 1
            $parsed.assemblies[0].plugins[0].steps[0].images[0].name | Should -Be "PreImage"
            $parsed.assemblies[0].plugins[0].steps[0].images[0].imageType | Should -Be "PreImage"
            $parsed.assemblies[0].plugins[0].steps[0].images[0].attributes | Should -Be "name,accountnumber"
        }
    }

    Context "Special Character Handling" {
        It "Should escape double quotes in strings" {
            $assembly = [PSCustomObject]@{
                name = 'Assembly with "quotes"'
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)

            { $result | ConvertFrom-Json } | Should -Not -Throw
            $parsed = $result | ConvertFrom-Json
            $parsed.assemblies[0].name | Should -Be 'Assembly with "quotes"'
        }

        It "Should handle backslashes in paths" {
            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = ".\bin\Release\Test.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)

            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should handle newlines in configuration" {
            $step = [PSCustomObject]@{
                name = "TestPlugin: Create of account"
                message = "Create"
                entity = "account"
                stage = "PreOperation"
                mode = "Synchronous"
                executionOrder = 1
                filteringAttributes = $null
                configuration = "Line1`nLine2"
                images = @()
            }

            $plugin = [PSCustomObject]@{
                typeName = "Namespace.TestPlugin"
                steps = @($step)
            }

            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = $null
                path = "./bin/Test.dll"
                plugins = @($plugin)
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly)

            { $result | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "Multiple Assemblies" {
        It "Should serialize multiple assemblies" {
            $assembly1 = [PSCustomObject]@{
                name = "Assembly1"
                type = "Assembly"
                solution = $null
                path = "./bin/Assembly1.dll"
                plugins = @()
            }

            $assembly2 = [PSCustomObject]@{
                name = "Assembly2"
                type = "Assembly"
                solution = $null
                path = "./bin/Assembly2.dll"
                plugins = @()
            }

            $result = ConvertTo-RegistrationJson -Assemblies @($assembly1, $assembly2)
            $parsed = $result | ConvertFrom-Json

            $parsed.assemblies | Should -HaveCount 2
            $parsed.assemblies[0].name | Should -Be "Assembly1"
            $parsed.assemblies[1].name | Should -Be "Assembly2"
        }
    }
}

Describe "Read-RegistrationJson" -Tag 'Unit' {
    BeforeAll {
        $testDir = Join-Path $TestDrive "registrations"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }

    Context "File Reading" {
        It "Should return null for non-existent file" {
            $result = Read-RegistrationJson -Path (Join-Path $TestDrive "nonexistent.json")

            $result | Should -Be $null
        }

        It "Should parse valid JSON file" {
            $jsonContent = @'
{
  "version": "1.0",
  "assemblies": [
    {
      "name": "TestAssembly",
      "type": "Assembly",
      "path": "./bin/Test.dll",
      "plugins": []
    }
  ]
}
'@
            $testFile = Join-Path $testDir "valid.json"
            Set-Content -Path $testFile -Value $jsonContent -Encoding UTF8

            $result = Read-RegistrationJson -Path $testFile

            $result | Should -Not -BeNullOrEmpty
            $result.version | Should -Be "1.0"
            $result.assemblies | Should -HaveCount 1
        }

        It "Should handle UTF-8 encoding with special characters" {
            $jsonContent = @'
{
  "version": "1.0",
  "assemblies": [
    {
      "name": "Test with special chars: \u00e9\u00e0\u00fc",
      "type": "Assembly",
      "path": "./bin/Test.dll",
      "plugins": []
    }
  ]
}
'@
            $testFile = Join-Path $testDir "utf8.json"
            Set-Content -Path $testFile -Value $jsonContent -Encoding UTF8

            $result = Read-RegistrationJson -Path $testFile

            $result | Should -Not -BeNullOrEmpty
            $result.assemblies[0].name | Should -Not -BeNullOrEmpty
        }
    }

    Context "Round-Trip Serialization" {
        It "Should round-trip serialize and deserialize" {
            $image = [PSCustomObject]@{
                name = "PreImage"
                imageType = "PreImage"
                attributes = "name,accountnumber"
                entityAlias = "PreImage"
            }

            $step = [PSCustomObject]@{
                name = "TestPlugin: Update of account"
                message = "Update"
                entity = "account"
                stage = "PreOperation"
                mode = "Synchronous"
                executionOrder = 1
                filteringAttributes = "name"
                configuration = $null
                images = @($image)
            }

            $plugin = [PSCustomObject]@{
                typeName = "Namespace.TestPlugin"
                steps = @($step)
            }

            $assembly = [PSCustomObject]@{
                name = "TestAssembly"
                type = "Assembly"
                solution = "TestSolution"
                path = "./bin/Test.dll"
                plugins = @($plugin)
            }

            # Serialize
            $json = ConvertTo-RegistrationJson -Assemblies @($assembly)

            # Write to file
            $testFile = Join-Path $testDir "roundtrip.json"
            Set-Content -Path $testFile -Value $json -Encoding UTF8 -NoNewline

            # Read back
            $result = Read-RegistrationJson -Path $testFile

            # Verify
            $result.assemblies[0].name | Should -Be "TestAssembly"
            $result.assemblies[0].type | Should -Be "Assembly"
            $result.assemblies[0].solution | Should -Be "TestSolution"
            $result.assemblies[0].plugins[0].typeName | Should -Be "Namespace.TestPlugin"
            $result.assemblies[0].plugins[0].steps[0].message | Should -Be "Update"
            $result.assemblies[0].plugins[0].steps[0].images[0].name | Should -Be "PreImage"
        }
    }
}
