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

    $result = Invoke-PpdsCli -Arguments @('auth', 'who') -Json -AsJson:$AsJson
    if ($AsJson) {
        return $result
    }
    if ($null -eq $result.active) {
        Write-Warning 'No active profile. Use Connect-DataverseEnvironment to create one.'
        return $null
    }
    return $result.active
}
