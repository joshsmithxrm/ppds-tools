function Invoke-DataverseApi {
    <#
    .SYNOPSIS
        Makes a Web API call to Dataverse.
    .PARAMETER ApiUrl
        The base Web API URL.
    .PARAMETER Endpoint
        The API endpoint (relative to ApiUrl).
    .PARAMETER AuthHeaders
        Authentication headers including Authorization bearer token.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,

        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,

        [Parameter()]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method = "GET",

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [switch]$WhatIf
    )

    $fullUrl = "$ApiUrl/$Endpoint"

    # Start with auth headers and add OData headers
    $headers = @{}
    foreach ($key in $AuthHeaders.Keys) {
        $headers[$key] = $AuthHeaders[$key]
    }
    $headers["OData-MaxVersion"] = "4.0"
    $headers["OData-Version"] = "4.0"
    $headers["Accept"] = "application/json"
    $headers["Prefer"] = "return=representation"

    if ($WhatIf) {
        Write-Log "[WhatIf] $Method $fullUrl"
        if ($Body) {
            Write-LogDebug ($Body | ConvertTo-Json -Depth 5 -Compress)
        }
        return $null
    }

    $params = @{
        Uri = $fullUrl
        Method = $Method
        Headers = $headers
        ContentType = "application/json; charset=utf-8"
    }

    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }

    try {
        $response = Invoke-RestMethod @params -UseBasicParsing
        return $response
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message
        Write-LogError "API Error ($statusCode): $errorBody"
        throw
    }
}

function Get-WebApiBaseUrl {
    <#
    .SYNOPSIS
        Gets the Web API base URL from a connection.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [DataverseConnection]$Connection
    )

    $webAppUrl = $Connection.ConnectedOrgPublishedEndpoints["WebApplication"].TrimEnd("/")
    return "$webAppUrl/api/data/v9.2"
}

function Get-AuthHeaders {
    <#
    .SYNOPSIS
        Gets HTTP headers for Dataverse Web API calls.
    .PARAMETER Connection
        DataverseConnection object from Connect-DataverseEnvironment.
    .PARAMETER SolutionName
        Optional solution name to include in headers.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [DataverseConnection]$Connection,
        [string]$SolutionName
    )

    $headers = @{
        "Authorization"    = "Bearer $($Connection.CurrentAccessToken)"
        "OData-MaxVersion" = "4.0"
        "OData-Version"    = "4.0"
        "Accept"           = "application/json"
        "Content-Type"     = "application/json; charset=utf-8"
    }

    if (-not [string]::IsNullOrWhiteSpace($SolutionName)) {
        $headers["MSCRM.SolutionName"] = $SolutionName
    }

    return $headers
}
