function Get-DataversePluginDrift {
    <#
    .SYNOPSIS
        Compares plugin registration configuration with Dataverse state to detect drift.

    .DESCRIPTION
        Analyzes differences between the registrations.json configuration and actual
        Dataverse plugin registrations. Reports orphaned components, missing components,
        and configuration differences.

    .PARAMETER RegistrationFile
        Path to the registrations.json file to compare.

    .PARAMETER Connection
        DataverseConnection object from Connect-DataverseEnvironment.

    .PARAMETER AssemblyName
        Specific assembly name to check. If not provided, checks all assemblies in the file.

    .EXAMPLE
        Get-DataversePluginDrift -RegistrationFile "./registrations.json"
        Checks drift for all assemblies in the registration file.

    .EXAMPLE
        $conn = Connect-DataverseEnvironment -Interactive
        Get-DataversePluginDrift -RegistrationFile "./registrations.json" -Connection $conn

    .OUTPUTS
        Array of drift report objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistrationFile,

        [Parameter(Mandatory = $true)]
        [DataverseConnection]$Connection,

        [Parameter()]
        [string]$AssemblyName
    )

    if (-not (Test-Path $RegistrationFile)) {
        throw "Registration file not found: $RegistrationFile"
    }

    $registrations = Read-RegistrationJson -Path $RegistrationFile
    if (-not $registrations -or -not $registrations.assemblies) {
        throw "Invalid or empty registrations.json"
    }

    # Get API connection
    $apiUrl = Get-WebApiBaseUrl -Connection $Connection
    $authHeaders = Get-AuthHeaders -Connection $Connection

    $allDriftReports = @()

    foreach ($asmReg in $registrations.assemblies) {
        if ($AssemblyName -and $asmReg.name -ne $AssemblyName) {
            continue
        }

        Write-Log "Checking drift for: $($asmReg.name)"

        $drift = Get-AssemblyDrift -ApiUrl $apiUrl -AuthHeaders $authHeaders `
            -AssemblyName $asmReg.name -ConfiguredPlugins $asmReg.plugins

        Write-DriftReport -Drift $drift
        $allDriftReports += $drift
    }

    return $allDriftReports
}

function Get-AssemblyDrift {
    <#
    .SYNOPSIS
        Internal function to get drift for a single assembly.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApiUrl,
        [Parameter(Mandatory = $true)]
        [hashtable]$AuthHeaders,
        [Parameter(Mandatory = $true)]
        [string]$AssemblyName,
        [Parameter(Mandatory = $true)]
        [array]$ConfiguredPlugins
    )

    $drift = [PSCustomObject]@{
        AssemblyName = $AssemblyName
        HasDrift = $false
        OrphanedSteps = @()
        MissingSteps = @()
        ModifiedSteps = @()
        OrphanedImages = @()
        MissingImages = @()
        ModifiedImages = @()
    }

    $assembly = Get-PluginAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -Name $AssemblyName
    if (-not $assembly) {
        foreach ($plugin in $ConfiguredPlugins) {
            foreach ($step in $plugin.steps) {
                $drift.MissingSteps += [PSCustomObject]@{
                    StepName = $step.name
                    PluginType = $plugin.typeName
                    Message = $step.message
                    Entity = $step.entity
                    Reason = "Assembly not registered"
                }
            }
        }
        $drift.HasDrift = $drift.MissingSteps.Count -gt 0
        return $drift
    }

    $dataverseSteps = Get-ProcessingStepsForAssembly -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -AssemblyId $assembly.pluginassemblyid

    $configuredStepLookup = @{}
    foreach ($plugin in $ConfiguredPlugins) {
        foreach ($step in $plugin.steps) {
            $configuredStepLookup[$step.name] = @{
                Step = $step
                Plugin = $plugin
            }
        }
    }

    # Check for orphaned steps
    foreach ($dvStep in $dataverseSteps) {
        if (-not $configuredStepLookup.ContainsKey($dvStep.name)) {
            $drift.OrphanedSteps += [PSCustomObject]@{
                StepName = $dvStep.name
                StepId = $dvStep.sdkmessageprocessingstepid
                Stage = $script:PluginStageMap[[int]$dvStep.stage]
                Mode = $script:PluginModeMap[[int]$dvStep.mode]
            }
        }
    }

    # Check for missing steps and configuration differences
    foreach ($stepName in $configuredStepLookup.Keys) {
        $config = $configuredStepLookup[$stepName]
        $configStep = $config.Step
        $configPlugin = $config.Plugin

        $dvStep = $dataverseSteps | Where-Object { $_.name -eq $stepName } | Select-Object -First 1

        if (-not $dvStep) {
            $drift.MissingSteps += [PSCustomObject]@{
                StepName = $stepName
                PluginType = $configPlugin.typeName
                Message = $configStep.message
                Entity = $configStep.entity
                Reason = "Step not registered"
            }
        }
        else {
            $differences = @()

            $configStageValue = $script:DataverseStageValues[$configStep.stage]
            if ($dvStep.stage -ne $configStageValue) {
                $differences += "Stage: Dataverse=$($script:PluginStageMap[[int]$dvStep.stage]), Config=$($configStep.stage)"
            }

            $configModeValue = $script:DataverseModeValues[$configStep.mode]
            if ($dvStep.mode -ne $configModeValue) {
                $differences += "Mode: Dataverse=$($script:PluginModeMap[[int]$dvStep.mode]), Config=$($configStep.mode)"
            }

            if ($dvStep.rank -ne $configStep.executionOrder) {
                $differences += "ExecutionOrder: Dataverse=$($dvStep.rank), Config=$($configStep.executionOrder)"
            }

            $dvFiltering = if ($dvStep.filteringattributes) { $dvStep.filteringattributes } else { "" }
            $configFiltering = if ($configStep.filteringAttributes) { $configStep.filteringAttributes } else { "" }
            if ($dvFiltering -ne $configFiltering) {
                $differences += "FilteringAttributes: Dataverse='$dvFiltering', Config='$configFiltering'"
            }

            if ($differences.Count -gt 0) {
                $drift.ModifiedSteps += [PSCustomObject]@{
                    StepName = $stepName
                    StepId = $dvStep.sdkmessageprocessingstepid
                    Differences = $differences
                }
            }

            # Check images
            $dvImages = Get-StepImages -ApiUrl $ApiUrl -AuthHeaders $AuthHeaders -StepId $dvStep.sdkmessageprocessingstepid

            $configuredImageLookup = @{}
            foreach ($image in $configStep.images) {
                $configuredImageLookup[$image.name] = $image
            }

            foreach ($dvImage in $dvImages) {
                if (-not $configuredImageLookup.ContainsKey($dvImage.name)) {
                    $drift.OrphanedImages += [PSCustomObject]@{
                        ImageName = $dvImage.name
                        StepName = $stepName
                        ImageId = $dvImage.sdkmessageprocessingstepimageid
                        ImageType = $script:PluginImageTypeMap[[int]$dvImage.imagetype]
                    }
                }
            }

            foreach ($imageName in $configuredImageLookup.Keys) {
                $configImage = $configuredImageLookup[$imageName]
                $dvImage = $dvImages | Where-Object { $_.name -eq $imageName } | Select-Object -First 1

                if (-not $dvImage) {
                    $drift.MissingImages += [PSCustomObject]@{
                        ImageName = $imageName
                        StepName = $stepName
                        ImageType = $configImage.imageType
                        Attributes = $configImage.attributes
                    }
                }
                else {
                    $imageDiffs = @()

                    $configImageTypeValue = $script:DataverseImageTypeValues[$configImage.imageType]
                    if ($dvImage.imagetype -ne $configImageTypeValue) {
                        $imageDiffs += "ImageType: Dataverse=$($script:PluginImageTypeMap[[int]$dvImage.imagetype]), Config=$($configImage.imageType)"
                    }

                    $dvAttrs = if ($dvImage.attributes) { $dvImage.attributes } else { "" }
                    $configAttrs = if ($configImage.attributes) { $configImage.attributes } else { "" }
                    if ($dvAttrs -ne $configAttrs) {
                        $imageDiffs += "Attributes: Dataverse='$dvAttrs', Config='$configAttrs'"
                    }

                    if ($imageDiffs.Count -gt 0) {
                        $drift.ModifiedImages += [PSCustomObject]@{
                            ImageName = $imageName
                            StepName = $stepName
                            ImageId = $dvImage.sdkmessageprocessingstepimageid
                            Differences = $imageDiffs
                        }
                    }
                }
            }
        }
    }

    $drift.HasDrift = (
        $drift.OrphanedSteps.Count -gt 0 -or
        $drift.MissingSteps.Count -gt 0 -or
        $drift.ModifiedSteps.Count -gt 0 -or
        $drift.OrphanedImages.Count -gt 0 -or
        $drift.MissingImages.Count -gt 0 -or
        $drift.ModifiedImages.Count -gt 0
    )

    return $drift
}

function Write-DriftReport {
    <#
    .SYNOPSIS
        Outputs a formatted drift detection report.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Drift
    )

    Write-Log ""
    Write-Log ("=" * 60)
    Write-Log "Drift Report: $($Drift.AssemblyName)"
    Write-Log ("=" * 60)

    if (-not $Drift.HasDrift) {
        Write-LogSuccess "No drift detected - configuration matches Dataverse"
        return
    }

    if ($Drift.OrphanedSteps.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "ORPHANED STEPS ($($Drift.OrphanedSteps.Count)) - In Dataverse but not in config:"
        foreach ($step in $Drift.OrphanedSteps) {
            Write-Log "  - $($step.StepName)"
            Write-Log "    Stage: $($step.Stage), Mode: $($step.Mode)"
        }
    }

    if ($Drift.MissingSteps.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "MISSING STEPS ($($Drift.MissingSteps.Count)) - In config but not in Dataverse:"
        foreach ($step in $Drift.MissingSteps) {
            Write-Log "  - $($step.StepName)"
            Write-Log "    Plugin: $($step.PluginType)"
        }
    }

    if ($Drift.ModifiedSteps.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "MODIFIED STEPS ($($Drift.ModifiedSteps.Count)) - Configuration differs:"
        foreach ($step in $Drift.ModifiedSteps) {
            Write-Log "  - $($step.StepName)"
            foreach ($diff in $step.Differences) {
                Write-Log "    $diff"
            }
        }
    }

    if ($Drift.OrphanedImages.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "ORPHANED IMAGES ($($Drift.OrphanedImages.Count)):"
        foreach ($image in $Drift.OrphanedImages) {
            Write-Log "  - $($image.ImageName) on step: $($image.StepName)"
        }
    }

    if ($Drift.MissingImages.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "MISSING IMAGES ($($Drift.MissingImages.Count)):"
        foreach ($image in $Drift.MissingImages) {
            Write-Log "  - $($image.ImageName) on step: $($image.StepName)"
        }
    }

    if ($Drift.ModifiedImages.Count -gt 0) {
        Write-Log ""
        Write-LogWarning "MODIFIED IMAGES ($($Drift.ModifiedImages.Count)):"
        foreach ($image in $Drift.ModifiedImages) {
            Write-Log "  - $($image.ImageName) on step: $($image.StepName)"
            foreach ($diff in $image.Differences) {
                Write-Log "    $diff"
            }
        }
    }

    $totalDrift = $Drift.OrphanedSteps.Count + $Drift.MissingSteps.Count + $Drift.ModifiedSteps.Count +
                  $Drift.OrphanedImages.Count + $Drift.MissingImages.Count + $Drift.ModifiedImages.Count
    Write-Log ""
    Write-LogWarning "Total drift items: $totalDrift"
}
