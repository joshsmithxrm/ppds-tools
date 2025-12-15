function New-ProcessingStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [hashtable]$StepData,
        [Parameter()]
        [switch]$WhatIf
    )

    $body = @{
        name = $StepData.Name
        stage = $StepData.Stage
        mode = $StepData.Mode
        rank = $StepData.ExecutionOrder
        "plugintypeid@odata.bind" = "/plugintypes($($StepData.PluginTypeId))"
        "sdkmessageid@odata.bind" = "/sdkmessages($($StepData.MessageId))"
        "sdkmessagefilterid@odata.bind" = "/sdkmessagefilters($($StepData.FilterId))"
    }

    if ($StepData.FilteringAttributes) {
        $body.filteringattributes = $StepData.FilteringAttributes
    }

    if ($StepData.Configuration) {
        $body.configuration = $StepData.Configuration
    }

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps" -Method POST -Body $body -WhatIf:$WhatIf
}

function Update-ProcessingStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$StepId,
        [Parameter(Mandatory = $true)]
        [hashtable]$StepData,
        [Parameter()]
        [switch]$WhatIf
    )

    $body = @{
        stage = $StepData.Stage
        mode = $StepData.Mode
        rank = $StepData.ExecutionOrder
    }

    if ($StepData.FilteringAttributes) {
        $body.filteringattributes = $StepData.FilteringAttributes
    } else {
        $body.filteringattributes = $null
    }

    if ($StepData.Configuration) {
        $body.configuration = $StepData.Configuration
    }

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps($StepId)" -Method PATCH -Body $body -WhatIf:$WhatIf
}

function Remove-ProcessingStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$StepId,
        [Parameter()]
        [switch]$WhatIf
    )

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingsteps($StepId)" -Method DELETE -WhatIf:$WhatIf
}

function New-StepImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [hashtable]$ImageData,
        [Parameter()]
        [switch]$WhatIf
    )

    $body = @{
        name = $ImageData.Name
        entityalias = $ImageData.EntityAlias
        imagetype = $ImageData.ImageType
        messagepropertyname = "Target"
        "sdkmessageprocessingstepid@odata.bind" = "/sdkmessageprocessingsteps($($ImageData.StepId))"
    }

    if ($ImageData.Attributes) {
        $body.attributes = $ImageData.Attributes
    }

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingstepimages" -Method POST -Body $body -WhatIf:$WhatIf
}

function Update-StepImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$ImageId,
        [Parameter(Mandatory = $true)]
        [hashtable]$ImageData,
        [Parameter()]
        [switch]$WhatIf
    )

    $body = @{
        entityalias = $ImageData.EntityAlias
    }

    if ($ImageData.Attributes) {
        $body.attributes = $ImageData.Attributes
    }

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingstepimages($ImageId)" -Method PATCH -Body $body -WhatIf:$WhatIf
}

function Remove-StepImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$ImageId,
        [Parameter()]
        [switch]$WhatIf
    )

    return Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "sdkmessageprocessingstepimages($ImageId)" -Method DELETE -WhatIf:$WhatIf
}

function New-PluginType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyId,
        [Parameter(Mandatory = $true)]
        [string]$TypeName,
        [Parameter()]
        [switch]$WhatIf
    )

    $friendlyName = $TypeName.Split('.')[-1]

    $body = @{
        "pluginassemblyid@odata.bind" = "/pluginassemblies($AssemblyId)"
        typename = $TypeName
        friendlyname = $friendlyName
        name = $TypeName
    }

    if ($WhatIf) {
        Write-Log "[WhatIf] Would create plugin type: $TypeName"
        return $null
    }

    try {
        $response = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "plugintypes" -Method POST -Body $body
        return $response
    }
    catch {
        Write-LogError "Failed to create plugin type '$TypeName': $($_.Exception.Message)"
        throw
    }
}

function Deploy-PluginAssembly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Assembly", "Nuget")]
        [string]$Type,
        [Parameter()]
        [string]$SolutionUniqueName,
        [Parameter()]
        [string]$PublisherPrefix,
        [Parameter()]
        [switch]$WhatIf
    )

    if (-not (Test-Path $Path)) {
        Write-LogError "File not found: $Path"
        return $null
    }

    if ($Type -eq "Nuget") {
        $packageUniqueName = if ($PublisherPrefix) {
            "${PublisherPrefix}_$AssemblyName"
        } else {
            $AssemblyName
        }

        $existingPackage = Get-PluginPackage -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName -UniqueName $packageUniqueName

        if ($existingPackage) {
            Write-Log "Updating existing plugin package: $AssemblyName"
            $packageId = $existingPackage.pluginpackageid

            if ($WhatIf) {
                Write-Log "[WhatIf] pac plugin push --pluginId $packageId --pluginFile $Path"
                return $existingPackage
            }

            $result = pac plugin push --pluginId $packageId --pluginFile $Path 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-LogError "Failed to update plugin package: $result"
                return $null
            }
            Write-LogSuccess "Plugin package updated successfully"
            return Get-PluginAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName
        }
        else {
            Write-Log "Registering new plugin package: $AssemblyName"

            if (-not $SolutionUniqueName) {
                Write-LogError "Solution is required for registering new plugin packages"
                return $null
            }

            if ($WhatIf) {
                Write-Log "[WhatIf] Would register new plugin package via Web API to solution '$SolutionUniqueName'"
                return $null
            }

            $bytes = [System.IO.File]::ReadAllBytes($Path)
            $content = [System.Convert]::ToBase64String($bytes)

            $body = @{
                name = $AssemblyName
                uniquename = $packageUniqueName
                content = $content
                version = "1.0.0"
            }

            Write-LogDebug "Package unique name: $packageUniqueName"

            try {
                $null = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "pluginpackages" -Method POST -Body $body
                Write-LogSuccess "Plugin package registered successfully"
                return Get-PluginAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName
            }
            catch {
                Write-LogError "Failed to register plugin package: $($_.Exception.Message)"
                return $null
            }
        }
    }
    else {
        $existingAssembly = Get-PluginAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName

        if ($existingAssembly) {
            Write-Log "Updating existing assembly: $AssemblyName"
            $pluginId = $existingAssembly.pluginassemblyid

            if ($WhatIf) {
                Write-Log "[WhatIf] pac plugin push --pluginId $pluginId --pluginFile $Path"
                return $existingAssembly
            }

            $result = pac plugin push --pluginId $pluginId --pluginFile $Path 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-LogError "Failed to update assembly: $result"
                return $null
            }
            Write-LogSuccess "Assembly updated successfully"
            return $existingAssembly
        }
        else {
            Write-Log "Registering new assembly: $AssemblyName"

            if ($WhatIf) {
                Write-Log "[WhatIf] Would register new assembly via Web API"
                return $null
            }

            $bytes = [System.IO.File]::ReadAllBytes($Path)
            $content = [System.Convert]::ToBase64String($bytes)

            try {
                $assembly = [System.Reflection.Assembly]::LoadFrom($Path)
                $assemblyName = $assembly.GetName()
                $version = $assemblyName.Version.ToString()
                $culture = if ($assemblyName.CultureInfo.Name) { $assemblyName.CultureInfo.Name } else { "neutral" }
                $publicKeyToken = [System.BitConverter]::ToString($assemblyName.GetPublicKeyToken()).Replace("-", "").ToLower()
                if (-not $publicKeyToken) { $publicKeyToken = "null" }
            }
            catch {
                Write-LogWarning "Could not read assembly metadata: $($_.Exception.Message)"
                $version = "1.0.0.0"
                $culture = "neutral"
                $publicKeyToken = "null"
            }

            $body = @{
                name = $AssemblyName
                content = $content
                isolationmode = 2
                sourcetype = 0
                version = $version
                culture = $culture
                publickeytoken = $publicKeyToken
            }

            try {
                $null = Invoke-DataverseApi -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Endpoint "pluginassemblies" -Method POST -Body $body
                Write-LogSuccess "Assembly registered successfully"
                return Get-PluginAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName
            }
            catch {
                Write-LogError "Failed to register assembly: $($_.Exception.Message)"
                return $null
            }
        }
    }
}
