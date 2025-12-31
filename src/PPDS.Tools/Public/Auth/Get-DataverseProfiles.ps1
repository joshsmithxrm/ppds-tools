function Get-DataverseProfiles {
    <#
    .SYNOPSIS
        Lists all authentication profiles.

    .DESCRIPTION
        Returns all configured authentication profiles.
        Uses the ppds CLI 'auth list' command.

        This cmdlet wraps the ppds CLI tool.

    .EXAMPLE
        Get-DataverseProfiles

        Lists all profiles.

    .OUTPUTS
        Array of PSCustomObject with profile details.
    #>
    [CmdletBinding()]
    param()

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @('auth', 'list', '--json')

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and capture output
    $output = & $cliPath @cliArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        if ($errorMessage) {
            throw "Failed to list profiles: $($errorMessage -join "`n")"
        }
        throw "Failed to list profiles with exit code $LASTEXITCODE"
    }

    try {
        $result = $output | Out-String | ConvertFrom-Json
        return $result.profiles
    }
    catch {
        throw "Failed to parse profiles output: $_"
    }
}
