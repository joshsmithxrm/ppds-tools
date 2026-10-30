BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PPDS.Tools') -Force
}

Describe 'CLI process boundary' {
    BeforeAll {
        $childPath = Join-Path $TestDrive 'synthetic child.ps1'
        @'
param([string]$Value, [int]$ExitCode = 0)
[Console]::Out.WriteLine((@{ value = $Value; directory = (Get-Location).Path } | ConvertTo-Json))
# Fill both pipes beyond their buffers to expose sequential stream-read deadlocks.
for ($i = 0; $i -lt 500; $i++) {
    [Console]::Error.WriteLine(('diagnostic-' + ('x' * 200)))
}
exit $ExitCode
'@ | Set-Content -LiteralPath $childPath
        $pwshPath = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    }

    It 'preserves quoted arguments, multiline stdout, stderr and exit code' {
        InModuleScope PPDS.Tools -Parameters @{ childPath = $childPath; pwshPath = $pwshPath } {
            $value = 'spaces and "quotes" and $literal; punctuation'
            $result = Invoke-PpdsProcess -FilePath $pwshPath -Arguments @('-NoProfile', '-File', $childPath, '-Value', $value, '-ExitCode', '7')
            $result.ExitCode | Should -Be 7
            ($result.StdOut | ConvertFrom-Json).value | Should -BeExactly $value
            $result.StdOut | Should -Not -Match 'diagnostic'
            @($result.StdErr -split '\r?\n' | Where-Object { $_ }).Count | Should -Be 500
        }
    }

    It 'runs in the PowerShell filesystem location and streams stderr callbacks' {
        $workingPath = Join-Path $TestDrive 'working directory'
        New-Item -ItemType Directory -Path $workingPath | Out-Null
        Push-Location $workingPath
        try {
            InModuleScope PPDS.Tools -Parameters @{ childPath = $childPath; pwshPath = $pwshPath; workingPath = $workingPath } {
                $lines = [Collections.Generic.List[string]]::new()
                $result = Invoke-PpdsProcess -FilePath $pwshPath -Arguments @('-NoProfile', '-File', $childPath, '-Value', 'fixture') -StandardErrorHandler { param($line) $lines.Add($line) }
                ($result.StdOut | ConvertFrom-Json).directory | Should -Be $workingPath
                $lines.Count | Should -Be 500
                $result.ExitCode | Should -Be 0
            }
        }
        finally { Pop-Location }
    }

    It 'rejects a non-filesystem working location before starting the process' {
        Push-Location Env:
        try {
            InModuleScope PPDS.Tools -Parameters @{ pwshPath = $pwshPath } {
                { Invoke-PpdsProcess -FilePath $pwshPath -Arguments @('-NoProfile') } | Should -Throw '*filesystem working directory*'
            }
        }
        finally { Pop-Location }
    }

    It 'preserves inherited stdout and stderr for interactive authentication prompts' {
        $parentPath = Join-Path $TestDrive 'synthetic parent.ps1'
        @'
param($ModulePath, $PwshPath)
Import-Module $ModulePath -Force
& (Get-Module PPDS.Tools) {
    param($PwshPath)
    Invoke-PpdsProcess -FilePath $PwshPath -Interactive -Arguments @('-NoProfile', '-Command', '[Console]::Out.WriteLine("synthetic device prompt"); [Console]::Error.WriteLine("synthetic stderr prompt")') | Out-Null
} $PwshPath
'@ | Set-Content -LiteralPath $parentPath
        $modulePath = (Get-Module PPDS.Tools).Path
        InModuleScope PPDS.Tools -Parameters @{ parentPath = $parentPath; pwshPath = $pwshPath; modulePath = $modulePath } {
            $result = Invoke-PpdsProcess -FilePath $pwshPath -Arguments @('-NoProfile', '-File', $parentPath, '-ModulePath', $modulePath, '-PwshPath', $pwshPath)
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'synthetic device prompt'
            $result.StdErr | Should -Match 'synthetic stderr prompt'
        }
    }
}
