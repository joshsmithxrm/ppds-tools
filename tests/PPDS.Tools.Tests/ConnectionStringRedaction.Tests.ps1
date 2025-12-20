BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "../../src/PPDS.Tools"
    Import-Module $modulePath -Force
}

Describe "Get-RedactedConnectionString" -Tag 'Unit', 'Security' {
    Context "Basic Redaction" {
        It "Should redact ClientSecret" {
            $input = "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc;ClientSecret=super-secret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc;ClientSecret=***REDACTED***"
        }

        It "Should redact Password" {
            $input = "AuthType=OAuth;Url=https://org.crm.dynamics.com;Username=user;Password=secret123"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "AuthType=OAuth;Url=https://org.crm.dynamics.com;Username=user;Password=***REDACTED***"
        }

        It "Should redact multiple sensitive keys" {
            $input = "ClientSecret=secret1;Password=secret2;Token=secret3"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "ClientSecret=***REDACTED***;Password=***REDACTED***;Token=***REDACTED***"
        }
    }

    Context "All Sensitive Keys" {
        # Test all 12 sensitive keys from SDK
        $testCases = @(
            @{ Key = 'ClientSecret'; Value = 'secret123' }
            @{ Key = 'Password'; Value = 'pass123' }
            @{ Key = 'Secret'; Value = 'mysecret' }
            @{ Key = 'Key'; Value = 'mykey' }
            @{ Key = 'Pwd'; Value = 'mypwd' }
            @{ Key = 'Token'; Value = 'mytoken' }
            @{ Key = 'ApiKey'; Value = 'myapikey' }
            @{ Key = 'AccessToken'; Value = 'myaccesstoken' }
            @{ Key = 'RefreshToken'; Value = 'myrefreshtoken' }
            @{ Key = 'SharedAccessKey'; Value = 'mysharedkey' }
            @{ Key = 'AccountKey'; Value = 'myaccountkey' }
            @{ Key = 'Credential'; Value = 'mycredential' }
        )

        It "Should redact <Key>" -ForEach $testCases {
            $input = "$Key=$Value"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "$Key=***REDACTED***"
        }
    }

    Context "Case Insensitivity" {
        It "Should redact lowercase clientsecret" {
            $input = "clientsecret=mysecret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "clientsecret=***REDACTED***"
        }

        It "Should redact uppercase CLIENTSECRET" {
            $input = "CLIENTSECRET=mysecret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "CLIENTSECRET=***REDACTED***"
        }

        It "Should redact mixed case ClientSecret" {
            $input = "ClIeNtSeCrEt=mysecret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "ClIeNtSeCrEt=***REDACTED***"
        }
    }

    Context "Quoted Values" {
        It "Should redact quoted values with spaces" {
            $input = 'ClientSecret="my secret with spaces"'
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "ClientSecret=***REDACTED***"
        }

        It "Should redact quoted values in middle of string" {
            $input = 'Url=https://org.crm.dynamics.com;ClientSecret="secret value";Timeout=30'
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "Url=https://org.crm.dynamics.com;ClientSecret=***REDACTED***;Timeout=30"
        }
    }

    Context "Non-Sensitive Values Preserved" {
        It "Should preserve Url" {
            $input = "Url=https://org.crm.dynamics.com"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "Url=https://org.crm.dynamics.com"
        }

        It "Should preserve AuthType" {
            $input = "AuthType=ClientSecret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "AuthType=ClientSecret"
        }

        It "Should preserve ClientId" {
            $input = "ClientId=12345-abcde"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "ClientId=12345-abcde"
        }

        It "Should preserve non-sensitive keys while redacting sensitive ones" {
            $input = "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc123;ClientSecret=secret;Timeout=120"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "AuthType=ClientSecret;Url=https://org.crm.dynamics.com;ClientId=abc123;ClientSecret=***REDACTED***;Timeout=120"
        }
    }

    Context "Edge Cases" {
        It "Should handle null input" {
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $null }
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty string" {
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString "" }
            $result | Should -Be ""
        }

        It "Should handle string without any key-value pairs" {
            $input = "just some random text"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "just some random text"
        }

        It "Should handle value at end of string (no trailing semicolon)" {
            $input = "Url=https://org.crm.dynamics.com;ClientSecret=endsecret"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "Url=https://org.crm.dynamics.com;ClientSecret=***REDACTED***"
        }
    }

    Context "Real-World Connection Strings" {
        It "Should redact typical Dataverse ClientSecret connection string" {
            $input = "AuthType=ClientSecret;Url=https://contoso.crm.dynamics.com;ClientId=51f81489-12ee-4a9e-aaae-a2591f45987d;ClientSecret=A8Q~abcdefghijklmnop~123456789"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Match "ClientSecret=\*\*\*REDACTED\*\*\*"
            $result | Should -Not -Match "A8Q~"
            $result | Should -Match "ClientId=51f81489"
        }

        It "Should redact OAuth connection string with password" {
            $input = "AuthType=OAuth;Url=https://contoso.crm.dynamics.com;Username=admin@contoso.com;Password=P@ssw0rd!;AppId=51f81489;RedirectUri=http://localhost"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Match "Password=\*\*\*REDACTED\*\*\*"
            $result | Should -Not -Match "P@ssw0rd!"
            $result | Should -Match "Username=admin@contoso.com"
        }
    }

    Context "Idempotency" {
        It "Should produce same result when redacting already redacted string" {
            $input = "ClientSecret=***REDACTED***"
            $result = InModuleScope PPDS.Tools { Get-RedactedConnectionString $args[0] } -ArgumentList $input
            $result | Should -Be "ClientSecret=***REDACTED***"
        }
    }
}

Describe "Verbose Logging Redaction" -Tag 'Unit', 'Security' {
    It "Should have redaction in Export-DataverseData" {
        $content = Get-Content (Join-Path $PSScriptRoot "../../src/PPDS.Tools/Public/Migration/Export-DataverseData.ps1") -Raw
        $content | Should -Match "Get-RedactedConnectionString"
        $content | Should -Match "redactedArgs"
    }

    It "Should have redaction in Import-DataverseData" {
        $content = Get-Content (Join-Path $PSScriptRoot "../../src/PPDS.Tools/Public/Migration/Import-DataverseData.ps1") -Raw
        $content | Should -Match "Get-RedactedConnectionString"
        $content | Should -Match "redactedArgs"
    }

    It "Should have redaction in Invoke-DataverseMigration" {
        $content = Get-Content (Join-Path $PSScriptRoot "../../src/PPDS.Tools/Public/Migration/Invoke-DataverseMigration.ps1") -Raw
        $content | Should -Match "Get-RedactedConnectionString"
        $content | Should -Match "redactedArgs"
    }
}
