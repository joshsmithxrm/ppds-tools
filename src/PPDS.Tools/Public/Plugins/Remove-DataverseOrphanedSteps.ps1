function Remove-DataverseOrphanedSteps {
    <#
    .SYNOPSIS
        Removes orphaned plugin registrations not in configuration.

    .DESCRIPTION
        Compares the registrations.json configuration with Dataverse and removes
        any steps that exist in Dataverse but are not defined in the configuration.
        This is useful for cleaning up after plugin refactoring or removal.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER ConfigPath
        Path to the registrations.json file.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER WhatIf
        Show what would be removed without making changes.

    .PARAMETER PassThru
        Return cleanup results as an object.

    .EXAMPLE
        Remove-DataverseOrphanedSteps -ConfigPath "./registrations.json"

        Removes orphaned steps using the active profile.

    .EXAMPLE
        Remove-DataverseOrphanedSteps -ConfigPath "./registrations.json" -WhatIf

        Shows what would be removed without making changes.

    .OUTPUTS
        None by default. PSCustomObject with cleanup results if -PassThru is specified.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [Alias('RegistrationFile')]
        [string]$ConfigPath,

        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate config file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Determine WhatIf from PowerShell preference
    $isWhatIf = $WhatIfPreference -or $PSCmdlet.MyInvocation.BoundParameters["WhatIf"]

    # Build arguments
    $cliArgs = @(
        'plugins', 'clean'
        '--config', (Resolve-Path $ConfigPath).Path
    )

    if ($Profile) {
        $cliArgs += '--profile'
        $cliArgs += $Profile
    }

    if ($Environment) {
        $cliArgs += '--environment'
        $cliArgs += $Environment
    }

    if ($isWhatIf) {
        $cliArgs += '--dry-run'
    }
    elseif (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Remove orphaned plugin steps')) {
        return
    }

    $result = Invoke-PpdsCli -Arguments $cliArgs -Json:$PassThru
    if ($PassThru) {
        return $result
    }
}
