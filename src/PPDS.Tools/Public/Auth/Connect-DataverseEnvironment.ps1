function Connect-DataverseEnvironment {
    <#
    .SYNOPSIS
        Creates an authentication profile for Dataverse operations.

    .DESCRIPTION
        Creates and stores an authentication profile using the ppds CLI.
        The profile can then be used by other cmdlets via the -Profile parameter.

        Authentication methods supported:
        - Interactive browser (default)
        - Device code flow (-DeviceCode)
        - Service principal with client secret (-ApplicationId, -ClientSecret, -TenantId)
        - Service principal with certificate file (-ApplicationId, -CertificatePath, -TenantId)
        - Service principal with certificate store (-ApplicationId, -CertificateThumbprint, -TenantId)
        - Managed identity (-ManagedIdentity)
        - Username/password (-Username, -Password)
        - GitHub federated (-GitHubFederated, -ApplicationId, -TenantId)
        - Azure DevOps federated (-AzureDevOpsFederated, -ApplicationId, -TenantId)

        This cmdlet wraps the ppds CLI tool.

    .PARAMETER Name
        Name for the profile (max 30 characters). If not specified, auto-generated.

    .PARAMETER Environment
        Default environment URL, ID, unique name, or partial name.
        Required for service principal authentication (must be full URL).

    .PARAMETER DeviceCode
        Use device code flow for interactive authentication.

    .PARAMETER ApplicationId
        Azure AD application (client) ID for service principal authentication.

    .PARAMETER ClientSecret
        Client secret for service principal authentication.

    .PARAMETER TenantId
        Azure AD tenant ID for service principal or federated authentication.

    .PARAMETER CertificatePath
        Path to certificate file (.pfx/.pem) for certificate authentication.

    .PARAMETER CertificatePassword
        Password for the certificate file.

    .PARAMETER CertificateThumbprint
        Certificate thumbprint for Windows certificate store authentication.

    .PARAMETER ManagedIdentity
        Use Azure Managed Identity.

    .PARAMETER Username
        Username for username/password authentication.

    .PARAMETER Password
        Password for username/password authentication.

    .PARAMETER GitHubFederated
        Use GitHub Actions OIDC federation.

    .PARAMETER AzureDevOpsFederated
        Use Azure DevOps OIDC federation.

    .PARAMETER Cloud
        Cloud environment: Public (default), USGov, USGovHigh, USGovDoD, China.

    .PARAMETER PassThru
        Return the profile name instead of just displaying success message.

    .EXAMPLE
        Connect-DataverseEnvironment -DeviceCode -Name "dev"

        Creates a profile using device code flow.

    .EXAMPLE
        Connect-DataverseEnvironment -DeviceCode -Environment "https://myorg.crm.dynamics.com" -Name "dev"

        Creates a profile with a default environment set.

    .EXAMPLE
        Connect-DataverseEnvironment -ApplicationId $appId -ClientSecret $secret -TenantId $tenant `
            -Environment "https://myorg.crm.dynamics.com" -Name "ci"

        Creates a service principal profile for CI/CD scenarios.

    .EXAMPLE
        $profile = Connect-DataverseEnvironment -DeviceCode -PassThru
        Deploy-DataversePlugins -ConfigPath "./registrations.json" -Profile $profile

        Creates a profile and uses it immediately.

    .OUTPUTS
        None by default. String (profile name) if -PassThru is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateLength(1, 30)]
        [string]$Name,

        [Parameter()]
        [Alias('EnvironmentUrl')]
        [string]$Environment,

        [Parameter()]
        [switch]$DeviceCode,

        [Parameter()]
        [string]$ApplicationId,

        [Parameter()]
        [string]$ClientSecret,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [string]$CertificatePassword,

        [Parameter()]
        [string]$CertificateThumbprint,

        [Parameter()]
        [switch]$ManagedIdentity,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [string]$Password,

        [Parameter()]
        [switch]$GitHubFederated,

        [Parameter()]
        [switch]$AzureDevOpsFederated,

        [Parameter()]
        [ValidateSet('Public', 'USGov', 'USGovHigh', 'USGovDoD', 'China')]
        [string]$Cloud = 'Public',

        [Parameter()]
        [switch]$PassThru
    )

    # Get the CLI tool
    $cliPath = Get-PpdsCli

    # Build arguments
    $cliArgs = @(
        'auth', 'create'
    )

    if ($Name) {
        $cliArgs += '--name'
        $cliArgs += $Name
    }

    if ($Environment) {
        $cliArgs += '--environment'
        $cliArgs += $Environment
    }

    if ($Cloud -ne 'Public') {
        $cliArgs += '--cloud'
        $cliArgs += $Cloud
    }

    if ($TenantId) {
        $cliArgs += '--tenant'
        $cliArgs += $TenantId
    }

    if ($DeviceCode) {
        $cliArgs += '--deviceCode'
    }

    if ($ApplicationId) {
        $cliArgs += '--applicationId'
        $cliArgs += $ApplicationId
    }

    if ($ClientSecret) {
        $cliArgs += '--clientSecret'
        $cliArgs += $ClientSecret
    }

    if ($CertificatePath) {
        $cliArgs += '--certificateDiskPath'
        $cliArgs += $CertificatePath
    }

    if ($CertificatePassword) {
        $cliArgs += '--certificatePassword'
        $cliArgs += $CertificatePassword
    }

    if ($CertificateThumbprint) {
        $cliArgs += '--certificateThumbprint'
        $cliArgs += $CertificateThumbprint
    }

    if ($ManagedIdentity) {
        $cliArgs += '--managedIdentity'
    }

    if ($Username) {
        $cliArgs += '--username'
        $cliArgs += $Username
    }

    if ($Password) {
        $cliArgs += '--password'
        $cliArgs += $Password
    }

    if ($GitHubFederated) {
        $cliArgs += '--githubFederated'
    }

    if ($AzureDevOpsFederated) {
        $cliArgs += '--azureDevOpsFederated'
    }

    Write-Verbose "Executing: $cliPath $($cliArgs -join ' ')"

    # Execute CLI - don't capture output so interactive prompts work
    & $cliPath @cliArgs

    # Check exit code
    if ($LASTEXITCODE -ne 0) {
        throw "Profile creation failed with exit code $LASTEXITCODE"
    }

    if ($PassThru) {
        # Return the profile name (either specified or we need to query the active one)
        if ($Name) {
            return $Name
        }
        else {
            # Query the active profile to get its name/identifier
            $whoOutput = & $cliPath 'auth' 'who' '--json' 2>&1 | Out-String
            try {
                $who = $whoOutput | ConvertFrom-Json
                if ($who.active -and $who.active.name) {
                    return $who.active.name
                }
                elseif ($who.active -and $who.active.index) {
                    return "[$($who.active.index)]"
                }
            }
            catch {
                Write-Warning "Could not determine profile name"
            }
        }
    }
}
