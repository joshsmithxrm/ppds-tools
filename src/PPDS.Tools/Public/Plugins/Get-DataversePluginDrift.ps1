function Get-DataversePluginDrift {
    <#
    .SYNOPSIS
        Compares plugin configuration against Dataverse environment state.

    .DESCRIPTION
        Analyzes differences between the registrations.json configuration and actual
        Dataverse plugin registrations. Reports orphaned components, missing components,
        and configuration differences.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER ConfigPath
        Path to the registrations.json file to compare.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER PassThru
        Return drift results as structured objects.

    .EXAMPLE
        Get-DataversePluginDrift -ConfigPath "./registrations.json"

        Shows drift for all assemblies using the active profile.

    .EXAMPLE
        Get-DataversePluginDrift -ConfigPath "./registrations.json" -Profile "dev" -PassThru

        Returns drift as objects for programmatic use.

    .OUTPUTS
        Text output by default. PSCustomObject with drift details if -PassThru is specified.
    #>
    [CmdletBinding()]
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

    # Build arguments
    $cliArgs = @(
        'plugins', 'diff'
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

    $result = Invoke-PpdsCli -Arguments $cliArgs -Json -AllowDrift -WarnOnDrift:(-not $PassThru)
    if ($PassThru) {
        return $result
    }
    Write-Verbose ($result | ConvertTo-Json -Depth 20)
}
