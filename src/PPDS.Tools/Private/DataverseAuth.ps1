# DataverseAuth.ps1 - OAuth2 authentication for Dataverse
# Replaces dependency on Microsoft.Xrm.Data.PowerShell
# NOTE: DataverseConnection class is defined in PPDS.Tools.psm1

# Well-known Azure AD application ID for Dynamics 365 (public client)
$script:DefaultClientId = "51f81489-12ee-4a9e-aaae-a2591f45987d"

function Get-DataverseToken {
    <#
    .SYNOPSIS
        Acquires an access token for Dataverse using client credentials (service principal).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentUrl,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret
    )

    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $scope = "$($EnvironmentUrl.TrimEnd('/'))/.default"

    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = $scope
    }

    try {
        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"

        return @{
            AccessToken = $response.access_token
            ExpiresIn   = $response.expires_in
            TokenType   = $response.token_type
        }
    }
    catch {
        $errorMessage = $_.ErrorDetails.Message
        if ($errorMessage) {
            $errorObj = $errorMessage | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorObj.error_description) {
                throw "Authentication failed: $($errorObj.error_description)"
            }
        }
        throw "Authentication failed: $($_.Exception.Message)"
    }
}

function Get-DataverseTokenDeviceCode {
    <#
    .SYNOPSIS
        Acquires an access token for Dataverse using device code flow (interactive).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentUrl,

        [Parameter()]
        [string]$TenantId = "organizations",

        [Parameter()]
        [string]$ClientId = $script:DefaultClientId
    )

    $deviceCodeEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode"
    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $scope = "$($EnvironmentUrl.TrimEnd('/'))/.default offline_access"

    # Request device code
    $deviceCodeBody = @{
        client_id = $ClientId
        scope     = $scope
    }

    try {
        $deviceCodeResponse = Invoke-RestMethod -Uri $deviceCodeEndpoint -Method POST -Body $deviceCodeBody -ContentType "application/x-www-form-urlencoded"
    }
    catch {
        throw "Failed to initiate device code flow: $($_.Exception.Message)"
    }

    # Display instructions to user
    Write-Host ""
    Write-Host "To sign in, use a web browser to open the page:" -ForegroundColor Cyan
    Write-Host "  $($deviceCodeResponse.verification_uri)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enter the code:" -ForegroundColor Cyan
    Write-Host "  $($deviceCodeResponse.user_code)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Waiting for authentication..." -ForegroundColor Gray

    # Poll for token
    $tokenBody = @{
        grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
        client_id   = $ClientId
        device_code = $deviceCodeResponse.device_code
    }

    $interval = $deviceCodeResponse.interval
    if (-not $interval) { $interval = 5 }
    $expiresAt = [datetime]::UtcNow.AddSeconds($deviceCodeResponse.expires_in)

    while ([datetime]::UtcNow -lt $expiresAt) {
        Start-Sleep -Seconds $interval

        try {
            $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method POST -Body $tokenBody -ContentType "application/x-www-form-urlencoded"

            Write-Host "Authentication successful!" -ForegroundColor Green

            return @{
                AccessToken  = $tokenResponse.access_token
                RefreshToken = $tokenResponse.refresh_token
                ExpiresIn    = $tokenResponse.expires_in
                TokenType    = $tokenResponse.token_type
            }
        }
        catch {
            $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($errorBody.error -eq "authorization_pending") {
                # Still waiting for user - continue polling
                continue
            }
            elseif ($errorBody.error -eq "slow_down") {
                # Increase polling interval
                $interval += 5
                continue
            }
            elseif ($errorBody.error -eq "expired_token") {
                throw "Device code expired. Please try again."
            }
            else {
                throw "Authentication failed: $($errorBody.error_description)"
            }
        }
    }

    throw "Device code flow timed out. Please try again."
}

function Get-DataverseOrgInfo {
    <#
    .SYNOPSIS
        Gets organization information from Dataverse to verify connection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentUrl,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $apiUrl = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2"

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Accept"        = "application/json"
    }

    try {
        # Query WhoAmI to verify token works
        $whoAmI = Invoke-RestMethod -Uri "$apiUrl/WhoAmI" -Headers $headers -Method GET

        # Get organization name
        $orgId = $whoAmI.OrganizationId
        $org = Invoke-RestMethod -Uri "$apiUrl/organizations($orgId)?`$select=name" -Headers $headers -Method GET

        return @{
            UserId         = $whoAmI.UserId
            OrganizationId = $whoAmI.OrganizationId
            OrgName        = $org.name
        }
    }
    catch {
        throw "Failed to connect to Dataverse: $($_.Exception.Message)"
    }
}

function New-DataverseConnection {
    <#
    .SYNOPSIS
        Creates a new DataverseConnection object using service principal authentication.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentUrl,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret
    )

    # Get token
    $tokenResult = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    # Get org info
    $orgInfo = Get-DataverseOrgInfo -EnvironmentUrl $EnvironmentUrl -AccessToken $tokenResult.AccessToken

    # Calculate expiry
    $expiry = [datetime]::UtcNow.AddSeconds($tokenResult.ExpiresIn)

    # Create connection
    $connection = [DataverseConnection]::new(
        $EnvironmentUrl,
        $tokenResult.AccessToken,
        $expiry,
        $orgInfo.OrgName
    )

    # Store auth context for potential token refresh
    $connection.TenantId = $TenantId
    $connection.ClientId = $ClientId
    $connection.ClientSecret = $ClientSecret

    return $connection
}

function New-DataverseConnectionInteractive {
    <#
    .SYNOPSIS
        Creates a new DataverseConnection object using device code (interactive) authentication.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentUrl,

        [Parameter()]
        [string]$TenantId = "organizations"
    )

    # Get token via device code flow
    $tokenResult = Get-DataverseTokenDeviceCode -EnvironmentUrl $EnvironmentUrl -TenantId $TenantId

    # Get org info
    $orgInfo = Get-DataverseOrgInfo -EnvironmentUrl $EnvironmentUrl -AccessToken $tokenResult.AccessToken

    # Calculate expiry
    $expiry = [datetime]::UtcNow.AddSeconds($tokenResult.ExpiresIn)

    # Create connection
    $connection = [DataverseConnection]::new(
        $EnvironmentUrl,
        $tokenResult.AccessToken,
        $expiry,
        $orgInfo.OrgName
    )

    # Store refresh token for potential token refresh
    $connection.TenantId = $TenantId
    $connection.ClientId = $script:DefaultClientId
    $connection.RefreshToken = $tokenResult.RefreshToken

    return $connection
}
