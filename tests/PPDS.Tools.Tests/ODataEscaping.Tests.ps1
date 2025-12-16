BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force

    # Dot-source the private function for testing
    . (Join-Path $modulePath "Private/DataverseQueries.ps1")
}

Describe "Get-EscapedODataString" -Tag 'Unit' {
    Context "Basic Escaping" {
        It "Should return empty string unchanged" {
            $result = Get-EscapedODataString -Value ""
            $result | Should -Be ""
        }

        It "Should return string without quotes unchanged" {
            $result = Get-EscapedODataString -Value "SimpleValue"
            $result | Should -Be "SimpleValue"
        }

        It "Should escape single quotes by doubling them" {
            $result = Get-EscapedODataString -Value "Value with 'quote'"
            $result | Should -Be "Value with ''quote''"
        }

        It "Should escape multiple single quotes" {
            $result = Get-EscapedODataString -Value "It's John's plugin"
            $result | Should -Be "It''s John''s plugin"
        }

        It "Should handle consecutive single quotes" {
            $result = Get-EscapedODataString -Value "Test''Value"
            $result | Should -Be "Test''''Value"
        }
    }

    Context "Special Characters" {
        It "Should preserve double quotes" {
            $result = Get-EscapedODataString -Value 'Value with "double quotes"'
            $result | Should -Be 'Value with "double quotes"'
        }

        It "Should preserve backslashes" {
            $result = Get-EscapedODataString -Value "Path\To\File"
            $result | Should -Be "Path\To\File"
        }

        It "Should preserve spaces" {
            $result = Get-EscapedODataString -Value "Value With Spaces"
            $result | Should -Be "Value With Spaces"
        }

        It "Should handle mixed special characters" {
            $input = "O'Brien's `"Test`" Path\File"
            $result = Get-EscapedODataString -Value $input
            $result | Should -Be "O''Brien''s `"Test`" Path\File"
        }
    }

    Context "Real-World Plugin Names" {
        It "Should escape typical plugin type name" {
            $result = Get-EscapedODataString -Value "Contoso.Plugins.Account.PreCreate"
            $result | Should -Be "Contoso.Plugins.Account.PreCreate"
        }

        It "Should escape plugin name with apostrophe" {
            $result = Get-EscapedODataString -Value "O'Connor.Plugins.ContactHandler"
            $result | Should -Be "O''Connor.Plugins.ContactHandler"
        }

        It "Should escape step name with colon" {
            $result = Get-EscapedODataString -Value "MyPlugin: Create of account"
            $result | Should -Be "MyPlugin: Create of account"
        }
    }
}
