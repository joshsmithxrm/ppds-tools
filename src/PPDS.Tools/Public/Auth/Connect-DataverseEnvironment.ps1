function Connect-DataverseEnvironment {
    <#
    .SYNOPSIS
        Connects to a Dataverse environment for plugin deployment operations.

    .DESCRIPTION
        Establishes an authenticated connection to a Dataverse environment using
        the authentication hierarchy:
        1. Explicit parameters (ConnectionString or SPN credentials)
        2. Environment variables (from .env file)
        3. Interactive OAuth (if -Interactive specified)

    .PARAMETER ConnectionString
        Full connection string for Dataverse.

    .PARAMETER EnvironmentUrl
        The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com).

    .PARAMETER ClientId
        Azure AD application (client) ID for service principal authentication.

    .PARAMETER ClientSecret
        Client secret for service principal authentication.

    .PARAMETER TenantId
        Azure AD tenant ID.

    .PARAMETER EnvFile
        Path to .env file with credentials.

    .PARAMETER Interactive
        Use interactive browser-based OAuth login.

    .EXAMPLE
        Connect-DataverseEnvironment -EnvironmentUrl "https://myorg.crm.dynamics.com" -Interactive
        Connects using browser-based authentication.

    .EXAMPLE
        Connect-DataverseEnvironment -ClientId $id -ClientSecret $secret -TenantId $tenant -EnvironmentUrl $url
        Connects using service principal credentials.

    .OUTPUTS
        Microsoft.Xrm.Tooling.Connector.CrmServiceClient
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConnectionString,

        [Parameter()]
        [string]$EnvironmentUrl,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [string]$ClientSecret,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$EnvFile,

        [Parameter()]
        [switch]$Interactive
    )

    # Ensure module is available
    if (-not (Get-Module -ListAvailable -Name Microsoft.Xrm.Data.PowerShell)) {
        Write-LogError "Microsoft.Xrm.Data.PowerShell module not found."
        Write-Log "Install with: Install-Module Microsoft.Xrm.Data.PowerShell -Scope CurrentUser"
        throw "Required module not installed"
    }
    Import-Module Microsoft.Xrm.Data.PowerShell -ErrorAction Stop

    # Load environment file if specified or by default
    if (-not [string]::IsNullOrWhiteSpace($EnvFile)) {
        Import-EnvFile -Path $EnvFile | Out-Null
    }
    elseif ([string]::IsNullOrWhiteSpace($ConnectionString) -and
            [string]::IsNullOrWhiteSpace($ClientId)) {
        Import-EnvFile | Out-Null
    }

    # Build connection string using hierarchy
    $finalConnectionString = $null
    $authMethod = $null

    # Priority 1: Explicit connection string
    if (-not [string]::IsNullOrWhiteSpace($ConnectionString)) {
        $finalConnectionString = $ConnectionString
        $authMethod = "Explicit Connection String"
    }
    # Priority 2: Explicit SPN parameters
    elseif (-not [string]::IsNullOrWhiteSpace($ClientId) -and
            -not [string]::IsNullOrWhiteSpace($ClientSecret) -and
            -not [string]::IsNullOrWhiteSpace($TenantId)) {

        $url = if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
            $EnvironmentUrl
        } else {
            Get-EnvVar "DATAVERSE_URL"
        }

        if ([string]::IsNullOrWhiteSpace($url)) {
            throw "EnvironmentUrl required when using service principal parameters"
        }

        $finalConnectionString = "AuthType=ClientSecret;Url=$url;ClientId=$ClientId;ClientSecret=$ClientSecret"
        $authMethod = "Service Principal (Parameters)"
    }
    # Priority 3: Environment variables for SPN
    else {
        $envUrl = Get-EnvVar "DATAVERSE_URL"
        $envClientId = Get-EnvVar "SP_APPLICATION_ID"
        $envClientSecret = Get-EnvVar "SP_CLIENT_SECRET"
        # Note: TenantId not currently used in connection string but kept for future use
        $null = Get-EnvVar "SP_TENANT_ID"

        $url = if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
            $EnvironmentUrl
        } else {
            $envUrl
        }

        if (-not [string]::IsNullOrWhiteSpace($envClientId) -and
            -not [string]::IsNullOrWhiteSpace($envClientSecret) -and
            -not [string]::IsNullOrWhiteSpace($url)) {

            $finalConnectionString = "AuthType=ClientSecret;Url=$url;ClientId=$envClientId;ClientSecret=$envClientSecret"
            $authMethod = "Service Principal (Environment)"
        }
        # Priority 4: Interactive OAuth
        elseif ($Interactive) {
            if ([string]::IsNullOrWhiteSpace($url)) {
                throw "EnvironmentUrl required for interactive authentication"
            }

            $finalConnectionString = "AuthType=OAuth;Url=$url;AppId=$script:DefaultOAuthAppId;RedirectUri=http://localhost;LoginPrompt=Auto"
            $authMethod = "Interactive OAuth"
        }
        else {
            Write-LogError "No authentication method available."
            Write-Log "Options:"
            Write-Log "  1. Provide -ConnectionString parameter"
            Write-Log "  2. Provide -ClientId, -ClientSecret, -TenantId, -EnvironmentUrl parameters"
            Write-Log "  3. Create .env.dev file with SP_APPLICATION_ID, SP_CLIENT_SECRET, DATAVERSE_URL"
            Write-Log "  4. Use -Interactive flag for browser-based login"
            throw "No authentication credentials available"
        }
    }

    # Log connection attempt (redacted)
    $sanitized = $finalConnectionString -replace "(ClientSecret=)[^;]+", '$1***REDACTED***'
    Write-Log "Auth method: $authMethod"
    Write-LogDebug "Connection: $sanitized"

    # Connect
    try {
        Write-Log "Connecting to Dataverse..."
        $conn = Get-CrmConnection -ConnectionString $finalConnectionString

        if (-not $conn -or -not $conn.IsReady) {
            throw "Connection failed - IsReady is false"
        }

        Write-LogSuccess "Connected to: $($conn.ConnectedOrgFriendlyName)"
        return $conn
    }
    catch {
        Write-LogError "Connection failed: $($_.Exception.Message)"
        throw
    }
}
