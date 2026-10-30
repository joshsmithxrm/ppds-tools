function Invoke-PpdsProcess {
    <#
    .SYNOPSIS
        Runs the CLI with separate stdout/stderr streams and an exact argument list.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [switch]$Interactive,
        [scriptblock]$StandardErrorHandler
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $location = Get-Location
    if ($location.Provider.Name -ne 'FileSystem') {
        throw 'PPDS CLI requires a filesystem working directory.'
    }
    # PowerShell's current location can differ from the host process directory.
    $startInfo.WorkingDirectory = $location.ProviderPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = -not $Interactive
    # Also supports a packaged .NET tool payload for offline contract tests.
    if ([System.IO.Path]::GetExtension($FilePath) -eq '.dll') {
        $startInfo.FileName = 'dotnet'
        $startInfo.ArgumentList.Add($FilePath)
    }
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $startInfo.RedirectStandardOutput = -not $Interactive
    $startInfo.RedirectStandardError = -not $Interactive
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $started = $false
    try {
        $started = $process.Start()
        if (-not $started) {
            throw 'Could not start PPDS CLI.'
        }
        if ($Interactive) {
            while (-not $process.HasExited) { Start-Sleep -Milliseconds 20 }
            return [PSCustomObject]@{ ExitCode = $process.ExitCode; StdOut = ''; StdErr = '' }
        }
        # Drain both pipes concurrently to avoid blocking on a full stderr buffer.
        # Never wait synchronously on process I/O: PowerShell must be able to stop
        # this pipeline and reach the finally block while the CLI is still running.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        if ($StandardErrorHandler) {
            $stderr = [System.Text.StringBuilder]::new()
            $stderrTask = $process.StandardError.ReadLineAsync()
        }
        else {
            $stderrTask = $process.StandardError.ReadToEndAsync()
        }
        $stderrComplete = $false
        while ($true) {
            if ($StandardErrorHandler) {
                while (-not $stderrComplete -and $stderrTask.IsCompleted) {
                    $line = $stderrTask.GetAwaiter().GetResult()
                    if ($null -eq $line) {
                        $stderrComplete = $true
                    }
                    else {
                        [void]$stderr.AppendLine($line)
                        & $StandardErrorHandler $line
                        $stderrTask = $process.StandardError.ReadLineAsync()
                    }
                }
            }
            else {
                $stderrComplete = $stderrTask.IsCompleted
            }
            if ($process.HasExited -and $stdoutTask.IsCompleted -and $stderrComplete) { break }
            Start-Sleep -Milliseconds 20
        }
        return [PSCustomObject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdoutTask.GetAwaiter().GetResult()
            StdErr = if ($StandardErrorHandler) { $stderr.ToString() } else { $stderrTask.GetAwaiter().GetResult() }
        }
    }
    finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
        }
        $process.Dispose()
    }
}
