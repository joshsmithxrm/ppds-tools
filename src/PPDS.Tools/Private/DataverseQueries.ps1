# Constants for stage/mode/image type mappings
$script:PluginStageMap = @{
    10 = "PreValidation"
    20 = "PreOperation"
    40 = "PostOperation"
}

$script:PluginModeMap = @{
    0 = "Synchronous"
    1 = "Asynchronous"
}

$script:PluginImageTypeMap = @{
    0 = "PreImage"
    1 = "PostImage"
    2 = "Both"
}

$script:DataverseStageValues = @{
    "PreValidation" = 10
    "PreOperation" = 20
    "PostOperation" = 40
}

$script:DataverseModeValues = @{
    "Synchronous" = 0
    "Asynchronous" = 1
}

$script:DataverseImageTypeValues = @{
    "PreImage" = 0
    "PostImage" = 1
    "Both" = 2
}

$script:ComponentType = @{
    PluginAssembly = 91
    SdkMessageProcessingStep = 92
}

function Get-PluginAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $filter = "`$filter=name eq '$Name'"
    $select = "`$select=pluginassemblyid,name,version,publickeytoken"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "pluginassemblies?$filter&$select" -Method GET
    return $result.value | Select-Object -First 1
}

function Get-PluginPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter()]
        [string]$UniqueName
    )

    $select = "`$select=pluginpackageid,name,uniquename,version"
    try {
        if ($UniqueName) {
            $filter = "`$filter=uniquename eq '$UniqueName'"
            $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "pluginpackages?$filter&$select" -Method GET
            $package = $result.value | Select-Object -First 1
            if ($package) { return $package }
        }

        $filter = "`$filter=name eq '$Name'"
        $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "pluginpackages?$filter&$select" -Method GET
        return $result.value | Select-Object -First 1
    }
    catch {
        Write-LogDebug "Could not query plugin packages: $($_.Exception.Message)"
        return $null
    }
}

function Get-PluginType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyId,
        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    $filter = "`$filter=_pluginassemblyid_value eq '$AssemblyId' and typename eq '$TypeName'"
    $select = "`$select=plugintypeid,typename,friendlyname"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "plugintypes?$filter&$select" -Method GET
    return $result.value | Select-Object -First 1
}

function Get-PluginTypesForAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyId
    )

    $filter = "`$filter=_pluginassemblyid_value eq '$AssemblyId'"
    $select = "`$select=plugintypeid,typename,friendlyname"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "plugintypes?$filter&$select" -Method GET
    return $result.value
}

function Get-PluginTypeStepCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$PluginTypeId
    )

    $filter = "`$filter=_eventhandler_value eq '$PluginTypeId'"
    $select = "`$select=sdkmessageprocessingstepid"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps?$filter&$select" -Method GET
    return @($result.value).Count
}

function Remove-PluginType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$PluginTypeId,
        [Parameter()]
        [switch]$WhatIf
    )

    if ($WhatIf) {
        Write-Log "[WhatIf] Would delete plugin type: $PluginTypeId"
        return $true
    }

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "plugintypes($PluginTypeId)" -Method DELETE
}

function Get-SdkMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$MessageName
    )

    $filter = "`$filter=name eq '$MessageName'"
    $select = "`$select=sdkmessageid,name"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessages?$filter&$select" -Method GET
    return $result.value | Select-Object -First 1
}

function Get-SdkMessageFilter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$MessageId,
        [Parameter(Mandatory = $true)]
        [string]$EntityLogicalName,
        [Parameter()]
        [string]$SecondaryEntityLogicalName
    )

    $filter = "_sdkmessageid_value eq '$MessageId' and primaryobjecttypecode eq '$EntityLogicalName'"
    if ($SecondaryEntityLogicalName) {
        $filter += " and secondaryobjecttypecode eq '$SecondaryEntityLogicalName'"
    }

    $select = "`$select=sdkmessagefilterid,primaryobjecttypecode,secondaryobjecttypecode"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessagefilters?`$filter=$filter&$select" -Method GET
    return $result.value | Select-Object -First 1
}

function Get-ProcessingStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    $filter = "`$filter=name eq '$StepName'"
    $select = "`$select=sdkmessageprocessingstepid,name,stage,mode,rank,filteringattributes,configuration"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps?$filter&$select" -Method GET
    return $result.value | Select-Object -First 1
}

function Get-ProcessingStepsForAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyId
    )

    $typesFilter = "`$filter=_pluginassemblyid_value eq '$AssemblyId'"
    $types = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "plugintypes?$typesFilter" -Method GET

    $steps = @()
    foreach ($type in $types.value) {
        $stepsFilter = "`$filter=_plugintypeid_value eq '$($type.plugintypeid)'"
        $select = "`$select=sdkmessageprocessingstepid,name,stage,mode,rank,filteringattributes,configuration"
        $typeSteps = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps?$stepsFilter&$select" -Method GET
        $steps += $typeSteps.value
    }

    return $steps
}

function Get-StepImages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$StepId
    )

    $filter = "`$filter=_sdkmessageprocessingstepid_value eq '$StepId'"
    $select = "`$select=sdkmessageprocessingstepimageid,name,entityalias,imagetype,attributes"
    $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingstepimages?$filter&$select" -Method GET
    return $result.value
}

function Get-Solution {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$UniqueName
    )

    $filter = "`$filter=uniquename eq '$UniqueName'"
    $select = "`$select=solutionid,uniquename,friendlyname,version"
    $expand = "`$expand=publisherid(`$select=customizationprefix,uniquename)"
    try {
        $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "solutions?$filter&$select&$expand" -Method GET
        $solution = $result.value | Select-Object -First 1

        if ($solution -and $solution.publisherid) {
            $solution | Add-Member -MemberType NoteProperty -Name "publisherprefix" -Value $solution.publisherid.customizationprefix -Force
        }

        return $solution
    }
    catch {
        Write-LogDebug "Could not query solution: $($_.Exception.Message)"
        return $null
    }
}

function Add-SolutionComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$SolutionUniqueName,
        [Parameter(Mandatory = $true)]
        [string]$ComponentId,
        [Parameter(Mandatory = $true)]
        [ValidateSet(91, 92)]
        [int]$ComponentType,
        [Parameter()]
        [switch]$WhatIf
    )

    $componentTypeName = switch ($ComponentType) {
        91 { "Plugin Assembly" }
        92 { "SDK Message Processing Step" }
    }

    if ($WhatIf) {
        Write-Log "[WhatIf] Would add $componentTypeName ($ComponentId) to solution '$SolutionUniqueName'"
        return $true
    }

    $addRequired = $false

    $body = @{
        ComponentId = $ComponentId
        ComponentType = $ComponentType
        SolutionUniqueName = $SolutionUniqueName
        AddRequiredComponents = $addRequired
    }

    try {
        $result = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "AddSolutionComponent" -Method POST -Body $body
        Write-LogDebug "Added $componentTypeName to solution '$SolutionUniqueName'"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "already exists" -or $errorMsg -match "duplicate") {
            Write-LogDebug "$componentTypeName already in solution"
            return $true
        }
        Write-LogWarning "Failed to add $componentTypeName to solution: $errorMsg"
        return $false
    }
}
