BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PPDS.Tools') -Force
}

Describe 'CLI wrapper contracts' {
    BeforeEach {
        $fixture = Join-Path $TestDrive 'fixture with spaces'
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        foreach ($name in @('plugin.dll', 'config.json', 'schema.xml', 'data.zip', 'users.xml')) {
            Set-Content -LiteralPath (Join-Path $fixture $name) -Value 'fixture'
        }
        InModuleScope PPDS.Tools -Parameters @{ fixture = $fixture } {
            $script:fixture = $fixture
            $script:response = [PSCustomObject]@{
                ExitCode = 0
                StdOut = '{"version":"1.0","success":true,"data":{"assemblies":[{"name":"Fixture"}]}}'
                StdErr = 'diagnostic text which must not be parsed as stdout'
            }
            $script:calls = [System.Collections.Generic.List[object]]::new()
            Mock Get-PpdsCli { 'fake-ppds-must-never-execute' }
            Mock Invoke-PpdsProcess {
                param($FilePath, $Arguments, $Interactive, $StandardErrorHandler)
                $script:calls.Add([PSCustomObject]@{
                    Path = $FilePath; Arguments = $Arguments; Interactive = $Interactive
                })
                return $script:response
            }
        }
    }

    It 'extracts through the real wrapper, unwraps data, and preserves spaced arguments' {
        InModuleScope PPDS.Tools {
            $value = Get-DataversePluginRegistrations -InputPath "$script:fixture/plugin.dll" -Solution 'A solution' -Force -PassThru
            $value.assemblies[0].name | Should -Be 'Fixture'
            $script:calls[0].Arguments | Should -Contain "$script:fixture/plugin.dll".Replace('/', [IO.Path]::DirectorySeparatorChar)
            $script:calls[0].Arguments | Should -Contain 'A solution'
            ($script:calls[0].Arguments -join '|') | Should -Match '--force\|--output-format\|Json$'
            $script:calls[0].Arguments | Should -Not -Contain '--json'
        }
    }

    It 'uses file-writing extraction mode when PassThru is absent' {
        InModuleScope PPDS.Tools {
            Get-DataversePluginRegistrations -InputPath "$script:fixture/plugin.dll" -OutputPath "$script:fixture/result.json"
            $script:calls[0].Arguments | Should -Contain '--output'
            $script:calls[0].Arguments | Should -Not -Contain '--output-format'
        }
    }

    It 'returns complete multiline profile JSON without mixing stderr' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = "{`n  `"active`": {`n    `"name`": `"offline`", `"index`": 1`n  }`n}"
            (Get-DataverseProfile).name | Should -Be 'offline'
            (Get-DataverseProfile -AsJson | ConvertFrom-Json).active.name | Should -Be 'offline'
            ($script:calls[0].Arguments -join ' ') | Should -Be 'auth who --output-format Json'
        }
    }

    It 'returns the profiles collection and handles no active profile' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = '{"profiles":[{"name":"one"},{"name":"two"}]}'
            @(Get-DataverseProfiles).Count | Should -Be 2
            ($script:calls[0].Arguments -join ' ') | Should -Be 'auth list --output-format Json'
            $script:response.StdOut = '{"active":null}'
            Get-DataverseProfile -WarningAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    It 'returns a raw dependency document, including nested multiline arrays' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = "{`n `"entityCount`": 1,`n `"tiers`": [{`"tier`": 0, `"entities`": [`"account`"]}]`n}"
            (Get-DataverseDependencyGraph -SchemaPath "$script:fixture/schema.xml").tiers[0].entities[0] | Should -Be 'account'
            (Get-DataverseDependencyGraph -SchemaPath "$script:fixture/schema.xml" -AsJson | ConvertFrom-Json).entityCount | Should -Be 1
        }
    }

    It 'unwraps plugin collection payloads and forwards profile/environment/filter options' {
        InModuleScope PPDS.Tools {
            $value = Get-DataversePlugins -Profile 'offline profile' -Environment 'offline environment' -Assembly 'A' -PassThru
            $value.assemblies[0].name | Should -Be 'Fixture'
            $script:calls[0].Arguments | Should -Contain 'offline profile'
            $script:calls[0].Arguments | Should -Contain 'offline environment'
            $script:calls[0].Arguments | Should -Contain '--assembly'
        }
    }

    It 'recognizes exit one only as successful drift evidence' {
        InModuleScope PPDS.Tools {
            $script:response.ExitCode = 1
            $script:response.StdOut = '{"version":"1.0","success":true,"data":[{"hasDrift":true}]}'
            (Get-DataversePluginDrift -ConfigPath "$script:fixture/config.json" -PassThru).hasDrift | Should -BeTrue
            { Get-DataversePluginDrift -ConfigPath "$script:fixture/config.json" } | Should -Not -Throw
            $script:response.StdOut = '{"version":"1.0","success":false,"error":{"code":"Auth.Failed","message":"fixture refusal"}}'
            { Get-DataversePluginDrift -ConfigPath "$script:fixture/config.json" -PassThru } | Should -Throw '*Auth.Failed*fixture refusal*'
        }
    }

    It 'maps WhatIf to dry-run for both plugin mutation wrappers' {
        InModuleScope PPDS.Tools {
            Deploy-DataversePlugins -ConfigPath "$script:fixture/config.json" -WhatIf -PassThru | Out-Null
            Remove-DataverseOrphanedSteps -ConfigPath "$script:fixture/config.json" -WhatIf -PassThru | Out-Null
            $script:calls.Count | Should -Be 2
            foreach ($call in $script:calls) {
                $call.Arguments | Should -Contain '--dry-run'
                $call.Arguments | Should -Not -Contain '--what-if'
                $call.Arguments | Should -Not -Contain '--force'
            }
        }
    }

    It 'does not add bypass or confirmation flags during regular deployment' {
        InModuleScope PPDS.Tools {
            Deploy-DataversePlugins -ConfigPath "$script:fixture/config.json" -Clean -Confirm:$false
            $script:calls[0].Arguments | Should -Contain '--clean'
            $script:calls[0].Arguments | Should -Not -Contain '--dry-run'
            $script:calls[0].Arguments | Should -Not -Contain '--force'
        }
    }

    It 'keeps a visible default drift warning using the successful CLI exit contract' {
        InModuleScope PPDS.Tools {
            $script:response.ExitCode = 1
            $script:response.StdOut = '{"version":"1.0","success":true,"data":[{"assemblyName":"Fixture","missingSteps":[{"stepName":"Update"}]}]}'
            $messages = Get-DataversePluginDrift -ConfigPath "$script:fixture/config.json" 3>&1
            ($messages | Out-String) | Should -Match 'Drift detected'
            $script:response.ExitCode = 0
            $script:response.StdOut = '{"version":"1.0","success":true,"data":[{"assemblyName":"Fixture","missingSteps":[]}]}'
            Get-DataversePluginDrift -ConfigPath "$script:fixture/config.json" 3>&1 | Should -BeNullOrEmpty
        }
    }

    It 'never logs synthetic credential values and preserves auth argument values' {
        InModuleScope PPDS.Tools {
            $secret = 'synthetic secret $value with "quotes"'
            $script:response.StdOut = ''
            $script:response.StdErr = ''
            $messages = Connect-DataverseEnvironment -Name fixture -ClientSecret $secret -CertificatePassword 'synthetic-cert' -Password 'synthetic-password' -Verbose 4>&1 | Out-String
            $messages | Should -Not -Match ([regex]::Escape($secret))
            $messages | Should -Not -Match 'synthetic-cert|synthetic-password'
            $script:calls[0].Arguments | Should -Contain $secret
            $script:calls[0].Interactive | Should -BeTrue
        }
    }

    It 'uses the canonical auth who result for unnamed authentication PassThru' {
        InModuleScope PPDS.Tools {
            Mock Invoke-PpdsProcess {
                param($FilePath, $Arguments, $Interactive)
                $script:calls.Add([PSCustomObject]@{ Arguments = $Arguments })
                if ($Interactive) { return [PSCustomObject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
                return [PSCustomObject]@{ ExitCode = 0; StdOut = '{"active":{"name":"created"}}'; StdErr = '' }
            }
            Connect-DataverseEnvironment -DeviceCode -PassThru | Should -Be 'created'
            ($script:calls[1].Arguments -join ' ') | Should -Be 'auth who --output-format Json'
        }
    }

    It 'redacts synthetic credential values from captured failure details' {
        InModuleScope PPDS.Tools {
            $script:response.ExitCode = 5
            $script:response.StdOut = ''
            $script:response.StdErr = 'synthetic-secret was rejected'
            try { Connect-DataverseEnvironment -ClientSecret 'synthetic-secret' -ErrorAction Stop }
            catch { $message = $_.Exception.Message }
            $message | Should -Match 'exit code 5'
            $message | Should -Match '\[REDACTED\]'
            $message | Should -Not -Match 'synthetic-secret'
        }
    }

    It 'rejects malformed JSON and success-false envelopes even on exit zero' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = 'not json'
            { Get-DataversePlugins -PassThru } | Should -Throw '*invalid JSON*'
            $script:response.StdOut = '{"version":"1.0","success":false,"error":{"code":"Forbidden","message":"fixture refusal"}}'
            { Get-DataversePlugins -PassThru } | Should -Throw '*Forbidden*fixture refusal*'
        }
    }

    It 'reads migration results from stderr and ignores copy cleanup messages' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = ''
            $script:response.StdErr = @'
CLI banner
{"phase":"complete","operation":"Export","recordsProcessed":10,"failureCount":0,"duration":"00:00:01","success":true}
{"phase":"complete","operation":"Import","recordsProcessed":8,"failureCount":0,"duration":"00:00:02","success":true}
{"phase":"complete","message":"Cleaned up temporary file."}
'@
            $result = Copy-DataverseData -SchemaPath "$script:fixture/schema.xml" -SourceEnvironment 'source fixture' -TargetEnvironment 'target fixture' -SourceProfile a -TargetProfile b -Parallel 4 -BatchSize 100 -PassThru
            $result.RecordsProcessed | Should -Be 8
            $result.RecordsFailed | Should -Be 0
            $result.Duration.TotalSeconds | Should -Be 2
            $script:calls[0].Arguments | Should -Contain '--source-env'
            $script:calls[0].Arguments | Should -Contain 'source fixture'
            $script:calls[0].Arguments | Should -Contain '--output-format'
            $script:calls[0].Arguments | Should -Not -Contain '--json'
        }
    }

    It 'forwards import options and uses failureCount instead of nonexistent errors' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = ''
            $script:response.StdErr = '{"phase":"complete","recordsProcessed":4,"failureCount":0,"duration":"00:00:01","success":true}'
            $result = Import-DataverseData -DataPath "$script:fixture/data.zip" -UserMappingPath "$script:fixture/users.xml" -BypassPlugins sync -BypassFlows -ContinueOnError -Mode Update -StripOwnerFields -SkipMissingColumns -PassThru
            $result.RecordsProcessed | Should -Be 4
            $script:calls[0].Arguments | Should -Contain '--user-mapping'
            $script:calls[0].Arguments | Should -Contain '--bypass-plugins'
            $script:calls[0].Arguments | Should -Contain '--mode'
            $script:response.StdErr = '{"phase":"complete","recordsProcessed":4,"failureCount":2,"duration":"00:00:01","success":false}'
            { Import-DataverseData -DataPath "$script:fixture/data.zip" -PassThru } | Should -Throw '*2 failed records*'
        }
    }

    It 'returns the export file only after a verified successful completion' {
        InModuleScope PPDS.Tools {
            $script:response.StdOut = ''
            $script:response.StdErr = '{"phase":"complete","recordsProcessed":4,"failureCount":0,"duration":"00:00:01","success":true}'
            $result = Export-DataverseData -SchemaPath "$script:fixture/schema.xml" -OutputPath "$script:fixture/data.zip" -PassThru
            $result | Should -BeOfType System.IO.FileInfo
            $script:response.StdErr = ''
            { Export-DataverseData -SchemaPath "$script:fixture/schema.xml" -OutputPath "$script:fixture/data.zip" -PassThru } | Should -Throw '*no completion result*'
        }
    }

    It 'does not swallow migration exit code <Code>' -TestCases @(
        @{ Code = 1 }, @{ Code = 2 }, @{ Code = 3 }, @{ Code = 4 }, @{ Code = 5 },
        @{ Code = 6 }, @{ Code = 7 }, @{ Code = 8 }, @{ Code = 9 }, @{ Code = 10 }, @{ Code = 11 }
    ) {
        param($Code)
        InModuleScope PPDS.Tools -Parameters @{ Code = $Code } {
            $script:response.ExitCode = $Code
            $script:response.StdOut = ''
            $script:response.StdErr = 'fixture failure'
            { Import-DataverseData -DataPath "$script:fixture/data.zip" -PassThru } | Should -Throw "*exit code $Code*"
            { Copy-DataverseData -SchemaPath "$script:fixture/schema.xml" -SourceEnvironment source -TargetEnvironment target } | Should -Throw "*exit code $Code*"
        }
    }
}
