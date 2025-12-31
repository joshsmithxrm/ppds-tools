function Deploy-DataversePlugins {
    <#
    .SYNOPSIS
        Deploys plugin registrations to a Dataverse environment.

    .DESCRIPTION
        Deploys plugin assemblies and registers steps/images to Dataverse based
        on a registrations.json configuration file.

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER ConfigPath
        Path to the registrations.json file.

    .PARAMETER Profile
        Authentication profile name. If not specified, uses the active profile.

    .PARAMETER Environment
        Environment URL, friendly name, unique name, or ID.
        Overrides the profile's default environment if specified.

    .PARAMETER Solution
        Solution unique name to add components to.
        Overrides the solution specified in the configuration file.

    .PARAMETER Clean
        Also remove orphaned registrations not in configuration.

    .PARAMETER WhatIf
        Preview changes without applying them.

    .PARAMETER PassThru
        Return deployment results as an object.

    .EXAMPLE
        Deploy-DataversePlugins -ConfigPath "./registrations.json"

        Deploys plugins using the active profile.

    .EXAMPLE
        Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile "dev" -Clean

        Deploys plugins and removes orphaned registrations.

    .EXAMPLE
        Deploy-DataversePlugins -ConfigPath "./registrations.json" -WhatIf

        Preview what would be deployed without making changes.

    .OUTPUTS
        None by default. PSCustomObject with deployment results if -PassThru is specified.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [Alias('RegistrationFile')]
        [string]$ConfigPath,

        [Parameter()]
        [string]$Profile,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [string]$Solution,

        [Parameter()]
        [switch]$Clean,

        [Parameter()]
        [switch]$PassThru
    )

    # Validate config file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Determine WhatIf from PowerShell preference
    $isWhatIf = $WhatIfPreference -or $PSCmdlet.MyInvocation.BoundParameters["WhatIf"]

    # Build arguments
    $cliArgs = @(
        'plugins', 'deploy'
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

    if ($Solution) {
        $cliArgs += '--solution'
        $cliArgs += $Solution
    }

    if ($Clean) {
        $cliArgs += '--clean'
    }

    if ($isWhatIf) {
        $cliArgs += '--what-if'
    }

    if ($PassThru) {
        $cliArgs += '--json'
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI and capture output
    $output = & $cliPath @cliArgs 2>&1

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        $errorMessage = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        if ($errorMessage) {
            throw "Deployment failed: $($errorMessage -join "`n")"
        }
        throw "Deployment failed with exit code $LASTEXITCODE"
    }

    if ($PassThru) {
        # Parse JSON output
        $jsonOutput = $output | Where-Object { $_ -match '^\s*\[' } | Out-String
        try {
            return $jsonOutput | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse deployment output: $_"
        }
    }
    else {
        # Write CLI output to verbose or console as appropriate
        $output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning $_.ToString()
            }
            elseif ($_ -match '^\s*[\{\[]') {
                # JSON output - skip in non-PassThru mode
            }
            else {
                Write-Verbose $_
            }
        }
    }
}
