function Connect-DataverseEnvironment {
    <#
    .SYNOPSIS
        Connects to a Dataverse environment for plugin deployment operations.

    .DESCRIPTION
        Establishes an authenticated connection to a Dataverse environment using
        the authentication hierarchy:
        1. Explicit parameters (ConnectionString or SPN credentials)
        2. Environment variables (from .env file)
        3. Interactive device code flow (if -Interactive specified)

    .PARAMETER ConnectionString
        Full connection string for Dataverse (legacy support - extracts URL and uses SPN auth).

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
        Use interactive device code flow for authentication.

    .EXAMPLE
        Connect-DataverseEnvironment -EnvironmentUrl "https://myorg.crm.dynamics.com" -Interactive
        Connects using device code flow (opens browser for authentication).

    .EXAMPLE
        Connect-DataverseEnvironment -ClientId $id -ClientSecret $secret -TenantId $tenant -EnvironmentUrl $url
        Connects using service principal credentials.

    .OUTPUTS
        DataverseConnection object with access token and environment information.
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

    # Load environment file if specified or by default
    if (-not [string]::IsNullOrWhiteSpace($EnvFile)) {
        Import-EnvFile -Path $EnvFile | Out-Null
    }
    elseif ([string]::IsNullOrWhiteSpace($ConnectionString) -and
            [string]::IsNullOrWhiteSpace($ClientId)) {
        Import-EnvFile | Out-Null
    }

    # Determine authentication method and parameters
    $authMethod = $null
    $finalUrl = $null
    $finalClientId = $null
    $finalClientSecret = $null
    $finalTenantId = $null

    # Priority 1: Explicit connection string (parse it for credentials)
    if (-not [string]::IsNullOrWhiteSpace($ConnectionString)) {
        # Use case-insensitive hashtable for connection string keys
        $parsed = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $ConnectionString -split ";" | ForEach-Object {
            $parts = $_ -split "=", 2
            if ($parts.Count -eq 2) {
                $parsed[$parts[0].Trim()] = $parts[1].Trim()
            }
        }

        $finalUrl = $parsed["Url"]
        if ($parsed["AuthType"] -eq "ClientSecret") {
            $finalClientId = $parsed["ClientId"]
            $finalClientSecret = $parsed["ClientSecret"]
            # Try to extract tenant from URL or use common
            $finalTenantId = if ($TenantId) { $TenantId } else { "organizations" }
            $authMethod = "Connection String (Service Principal)"
        }
        elseif ($parsed["AuthType"] -eq "OAuth") {
            # OAuth connection string - use interactive
            $Interactive = $true
            $authMethod = "Connection String (Interactive)"
        }
        else {
            throw "Unsupported AuthType in connection string. Supported: ClientSecret, OAuth"
        }
    }
    # Priority 2: Explicit SPN parameters
    elseif (-not [string]::IsNullOrWhiteSpace($ClientId) -and
            -not [string]::IsNullOrWhiteSpace($ClientSecret) -and
            -not [string]::IsNullOrWhiteSpace($TenantId)) {

        $finalUrl = if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
            $EnvironmentUrl
        } else {
            Get-EnvVar "DATAVERSE_URL"
        }

        if ([string]::IsNullOrWhiteSpace($finalUrl)) {
            throw "EnvironmentUrl required when using service principal parameters"
        }

        $finalClientId = $ClientId
        $finalClientSecret = $ClientSecret
        $finalTenantId = $TenantId
        $authMethod = "Service Principal (Parameters)"
    }
    # Priority 3: Environment variables for SPN
    else {
        $envUrl = Get-EnvVar "DATAVERSE_URL"
        $envClientId = Get-EnvVar "SP_APPLICATION_ID"
        $envClientSecret = Get-EnvVar "SP_CLIENT_SECRET"
        $envTenantId = Get-EnvVar "SP_TENANT_ID"

        $finalUrl = if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
            $EnvironmentUrl
        } else {
            $envUrl
        }

        if (-not [string]::IsNullOrWhiteSpace($envClientId) -and
            -not [string]::IsNullOrWhiteSpace($envClientSecret) -and
            -not [string]::IsNullOrWhiteSpace($finalUrl)) {

            $finalClientId = $envClientId
            $finalClientSecret = $envClientSecret
            $finalTenantId = if ($envTenantId) { $envTenantId } else { "organizations" }
            $authMethod = "Service Principal (Environment)"
        }
        # Priority 4: Interactive device code flow
        elseif ($Interactive) {
            if ([string]::IsNullOrWhiteSpace($finalUrl)) {
                throw "EnvironmentUrl required for interactive authentication"
            }
            $authMethod = "Interactive (Device Code)"
        }
        else {
            Write-LogError "No authentication method available."
            Write-Log "Options:"
            Write-Log "  1. Provide -ConnectionString parameter"
            Write-Log "  2. Provide -ClientId, -ClientSecret, -TenantId, -EnvironmentUrl parameters"
            Write-Log "  3. Create .env.dev file with SP_APPLICATION_ID, SP_CLIENT_SECRET, SP_TENANT_ID, DATAVERSE_URL"
            Write-Log "  4. Use -Interactive flag for device code authentication"
            throw "No authentication credentials available"
        }
    }

    # Log connection attempt
    Write-Log "Auth method: $authMethod"
    Write-Log "Environment: $finalUrl"

    # Connect using appropriate method
    try {
        if ($authMethod -eq "Interactive (Device Code)" -or $authMethod -eq "Connection String (Interactive)") {
            Write-Log "Starting interactive authentication..."
            $tenantForInteractive = if ($finalTenantId) { $finalTenantId } else { "organizations" }
            $connection = New-DataverseConnectionInteractive -EnvironmentUrl $finalUrl -TenantId $tenantForInteractive
        }
        else {
            Write-Log "Connecting to Dataverse..."
            $connection = New-DataverseConnection -EnvironmentUrl $finalUrl -TenantId $finalTenantId -ClientId $finalClientId -ClientSecret $finalClientSecret
        }

        if (-not $connection -or -not $connection.IsReady) {
            throw "Connection failed - IsReady is false"
        }

        Write-LogSuccess "Connected to: $($connection.ConnectedOrgFriendlyName)"
        return $connection
    }
    catch {
        Write-LogError "Connection failed: $($_.Exception.Message)"
        throw
    }
}
