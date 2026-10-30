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

    $result = Invoke-PpdsCli -Arguments @('auth', 'list') -Json
    return $result.profiles
}
