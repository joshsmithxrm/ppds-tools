function Get-DataverseProfile {
    <#
    .SYNOPSIS
        Gets the current active authentication profile.

    .DESCRIPTION
        Returns information about the currently active authentication profile.
        Uses the ppds CLI 'auth who' command.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER AsJson
        Return raw JSON output.

    .EXAMPLE
        Get-DataverseProfile

        Shows the active profile information.

    .OUTPUTS
        PSCustomObject with profile details.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$AsJson
    )

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @('auth', 'who', '--json')

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and capture output
    $output = & $cliPath @cliArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        if ($errorMessage) {
            throw "Failed to get profile: $($errorMessage -join "`n")"
        }
        throw "Failed to get profile with exit code $LASTEXITCODE"
    }

    if ($AsJson) {
        return $output | Out-String
    }

    try {
        $result = $output | Out-String | ConvertFrom-Json
        if ($result.active) {
            return $result.active
        }
        else {
            Write-Warning "No active profile. Use Connect-DataverseEnvironment to create one."
            return $null
        }
    }
    catch {
        throw "Failed to parse profile output: $_"
    }
}
