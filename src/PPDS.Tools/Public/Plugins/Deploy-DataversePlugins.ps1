# Design Decision: Sequential Step Deployment
# ============================================
# Steps are deployed sequentially rather than in parallel (ForEach-Object -Parallel).
# Rationale:
#   1. Simpler error handling and debugging
#   2. Clear progress output for users
#   3. Avoids Dataverse API rate limiting issues
#   4. Maintains transactional semantics (partial failures are clear)
#   5. Most registrations have <50 steps, making parallelism unnecessary
# Future consideration: Add -Parallel switch for large registrations (100+ steps)

function Deploy-DataversePlugins {
    <#
    .SYNOPSIS
        Deploys plugin assemblies and registers steps to Dataverse.

    .DESCRIPTION
        Deploys plugin assemblies using Web API and registers/updates SDK message
        processing steps and images using the Dataverse Web API.
        Supports both classic plugin assemblies and plugin packages (NuGet).

    .PARAMETER RegistrationFile
        Path to the registrations.json file.

    .PARAMETER Connection
        DataverseConnection object from Connect-DataverseEnvironment.

    .PARAMETER Force
        Remove orphaned steps that exist in Dataverse but not in configuration.

    .PARAMETER SkipAssembly
        Skip deploying the assembly, only register/update steps.

    .PARAMETER DetectDrift
        Run drift detection after deployment.

    .PARAMETER WhatIf
        Show what would be deployed without making changes.

    .EXAMPLE
        $conn = Connect-DataverseEnvironment -Interactive
        Deploy-DataversePlugins -RegistrationFile "./registrations.json" -Connection $conn

    .EXAMPLE
        Deploy-DataversePlugins -RegistrationFile "./registrations.json" -Connection $conn -Force
        Deploys and removes orphaned steps.

    .OUTPUTS
        Deployment summary object.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistrationFile,

        [Parameter(Mandatory = $true)]
        [DataverseConnection]$Connection,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipAssembly,

        [Parameter()]
        [switch]$DetectDrift
    )

    $isWhatIf = $WhatIfPreference -or $PSCmdlet.MyInvocation.BoundParameters["WhatIf"]

    if (-not (Test-Path $RegistrationFile)) {
        throw "Registration file not found: $RegistrationFile"
    }

    $registrations = Read-RegistrationJson -Path $RegistrationFile
    if (-not $registrations -or -not $registrations.assemblies) {
        throw "Invalid or empty registrations.json"
    }

    Write-Log "Plugin Deployment Tool"
    if ($isWhatIf) {
        Write-LogWarning "Running in WhatIf mode - no changes will be made"
    }

    $apiUrl = Get-WebApiBaseUrl -Connection $Connection
    $authHeaders = Get-AuthHeaders -Connection $Connection

    Write-LogSuccess "Connected to: $($Connection.ConnectedOrgFriendlyName)"

    $totalStepsCreated = 0
    $totalStepsUpdated = 0
    $totalImagesCreated = 0
    $totalImagesUpdated = 0
    $totalOrphansWarned = 0
    $totalOrphansDeleted = 0

    foreach ($asmReg in $registrations.assemblies) {
        Write-Log ""
        Write-Log ("=" * 60)
        Write-Log "Deploying: $($asmReg.name) ($($asmReg.type))"
        Write-Log ("=" * 60)

        $solutionUniqueName = $asmReg.solution
        $solution = $null
        $publisherPrefix = $null

        if ($asmReg.type -eq "Nuget" -and -not $solutionUniqueName) {
            Write-LogError "Solution is required for plugin packages (Nuget type)"
            continue
        }

        if ($solutionUniqueName -and -not $isWhatIf) {
            Write-Log "Looking up solution: $solutionUniqueName"
            $solution = Get-Solution -ApiUrl $apiUrl -AuthHeaders $authHeaders -UniqueName $solutionUniqueName
            if (-not $solution) {
                Write-LogError "Solution not found: $solutionUniqueName"
                continue
            }
            $publisherPrefix = $solution.publisherprefix
            Write-LogSuccess "Solution found: $($solution.friendlyname) (prefix: $publisherPrefix)"
        }

        # Deploy assembly
        if (-not $SkipAssembly) {
            $registrationDir = Split-Path $RegistrationFile -Parent
            $rawPath = if ($asmReg.type -eq "Nuget" -and $asmReg.packagePath) {
                $asmReg.packagePath
            } else {
                $asmReg.path
            }

            # Resolve path based on prefix:
            # - "./" or ".\" = relative to current working directory
            # - absolute path = use as-is
            # - other relative paths (including "../") = relative to registrations.json location
            if ($rawPath -match '^\.[\\/]') {
                # Starts with "./" - relative to CWD, strip the "./"
                $deployPath = Join-Path (Get-Location) ($rawPath -replace '^\.[\\/]', '')
            }
            elseif ([System.IO.Path]::IsPathRooted($rawPath)) {
                # Absolute path - use as-is
                $deployPath = $rawPath
            }
            else {
                # Relative path (including "../") - relative to registrations.json
                $deployPath = Join-Path $registrationDir $rawPath
            }

            if (-not (Test-Path $deployPath)) {
                Write-LogWarning "Assembly/package not found: $deployPath"
                continue
            }

            $deploySuccess = Deploy-PluginAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                -Path $deployPath -AssemblyName $asmReg.name -Type $asmReg.type `
                -SolutionUniqueName $solutionUniqueName -PublisherPrefix $publisherPrefix `
                -WhatIf:$isWhatIf

            if (-not $deploySuccess -and -not $isWhatIf) {
                Write-LogError "Failed to deploy assembly, skipping step registration"
                continue
            }
        }

        # Get assembly record
        $assembly = $null
        if (-not $isWhatIf) {
            $assembly = Get-PluginAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders -Name $asmReg.name
            if (-not $assembly) {
                Write-LogError "Assembly not found in Dataverse: $($asmReg.name)"
                continue
            }
            Write-Log "Assembly ID: $($assembly.pluginassemblyid)"

            # Only add assembly to solution for classic assemblies, not NuGet packages
            # (NuGet packages are added via the plugin package, not the assembly)
            if ($solutionUniqueName -and $asmReg.type -ne "Nuget") {
                Add-SolutionComponent -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                    -SolutionUniqueName $solutionUniqueName `
                    -ComponentId $assembly.pluginassemblyid `
                    -ComponentType $script:ComponentType.PluginAssembly | Out-Null
            }
        }

        $configuredStepNames = @()

        # Process each plugin
        foreach ($plugin in $asmReg.plugins) {
            Write-Log ""
            Write-Log "Plugin: $($plugin.typeName)"

            $pluginType = $null
            if (-not $isWhatIf -and $assembly) {
                $pluginType = Get-PluginType -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                    -AssemblyId $assembly.pluginassemblyid -TypeName $plugin.typeName

                if (-not $pluginType -and $plugin.steps.Count -gt 0 -and $asmReg.type -eq "Assembly") {
                    Write-Log "  Registering new plugin type: $($plugin.typeName)"
                    $pluginType = New-PluginType -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                        -AssemblyId $assembly.pluginassemblyid -TypeName $plugin.typeName `
                        -SolutionUniqueName $solutionUniqueName
                    if ($pluginType) {
                        Write-LogSuccess "  Plugin type created"
                    }
                }
                elseif (-not $pluginType -and $plugin.steps.Count -gt 0) {
                    Write-LogWarning "  Plugin type not found: $($plugin.typeName)"
                    continue
                }
            }

            # Process steps
            foreach ($step in $plugin.steps) {
                Write-Log "  Step: $($step.name)"
                $configuredStepNames += $step.name

                $message = $null
                $filter = $null

                if (-not $isWhatIf) {
                    $message = Get-SdkMessage -ApiUrl $apiUrl -AuthHeaders $authHeaders -MessageName $step.message
                    if (-not $message) {
                        Write-LogError "    SDK Message not found: $($step.message)"
                        continue
                    }

                    $filterParams = @{
                        ApiUrl = $apiUrl
                        AuthHeaders = $authHeaders
                        MessageId = $message.sdkmessageid
                        EntityLogicalName = $step.entity
                    }
                    if ($step.secondaryEntity) {
                        $filterParams["SecondaryEntityLogicalName"] = $step.secondaryEntity
                    }
                    $filter = Get-SdkMessageFilter @filterParams
                    if (-not $filter) {
                        Write-LogError "    SDK Message Filter not found"
                        continue
                    }
                }

                $stageValue = $script:DataverseStageValues[$step.stage]
                $modeValue = $script:DataverseModeValues[$step.mode]

                $existingStep = $null
                if (-not $isWhatIf) {
                    try {
                        $existingStep = Get-ProcessingStep -ApiUrl $apiUrl -AuthHeaders $authHeaders -StepName $step.name
                    } catch {
                        Write-LogDebug "Step not found (expected for new steps): $($_.Exception.Message)"
                    }
                }

                $stepData = @{
                    Name = $step.name
                    Stage = $stageValue
                    Mode = $modeValue
                    ExecutionOrder = $step.executionOrder
                    FilteringAttributes = $step.filteringAttributes
                    Configuration = $step.configuration
                    PluginTypeId = $pluginType.plugintypeid
                    MessageId = $message.sdkmessageid
                    FilterId = $filter.sdkmessagefilterid
                }

                $stepId = $null
                if ($existingStep) {
                    Write-Log "    Updating existing step..."
                    if (-not $isWhatIf) {
                        Update-ProcessingStep -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                            -StepId $existingStep.sdkmessageprocessingstepid -StepData $stepData
                        $stepId = $existingStep.sdkmessageprocessingstepid
                        $totalStepsUpdated++
                        Write-LogSuccess "    Step updated"

                        if ($solutionUniqueName) {
                            $addResult = Add-SolutionComponent -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                -SolutionUniqueName $solutionUniqueName `
                                -ComponentId $stepId `
                                -ComponentType $script:ComponentType.SdkMessageProcessingStep
                            if ($addResult) {
                                Write-LogDebug "    Step added to solution"
                            }
                        }
                    } else {
                        Write-Log "    [WhatIf] Would update step"
                        $totalStepsUpdated++
                    }
                } else {
                    Write-Log "    Creating new step..."
                    if (-not $isWhatIf) {
                        $newStep = New-ProcessingStep -ApiUrl $apiUrl -AuthHeaders $authHeaders -StepData $stepData
                        $stepId = $newStep.sdkmessageprocessingstepid
                        $totalStepsCreated++
                        Write-LogSuccess "    Step created"

                        if ($solutionUniqueName) {
                            $addResult = Add-SolutionComponent -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                -SolutionUniqueName $solutionUniqueName `
                                -ComponentId $stepId `
                                -ComponentType $script:ComponentType.SdkMessageProcessingStep
                            if ($addResult) {
                                Write-LogDebug "    Step added to solution"
                            }
                        }
                    } else {
                        Write-Log "    [WhatIf] Would create step"
                        $totalStepsCreated++
                    }
                }

                # Process images
                foreach ($image in $step.images) {
                    Write-Log "    Image: $($image.name) ($($image.imageType))"

                    $imageTypeValue = $script:DataverseImageTypeValues[$image.imageType]

                    $existingImages = @()
                    if (-not $isWhatIf -and $stepId) {
                        try {
                            $existingImages = Get-StepImages -ApiUrl $apiUrl -AuthHeaders $authHeaders -StepId $stepId
                        } catch {
                            Write-LogDebug "Could not retrieve existing images: $($_.Exception.Message)"
                        }
                    }

                    $existingImage = $existingImages | Where-Object { $_.name -eq $image.name } | Select-Object -First 1

                    $imageData = @{
                        Name = $image.name
                        EntityAlias = if ($image.entityAlias) { $image.entityAlias } else { $image.name }
                        ImageType = $imageTypeValue
                        Attributes = $image.attributes
                        StepId = $stepId
                    }

                    if ($existingImage) {
                        if (-not $isWhatIf) {
                            Write-Log "      Updating existing image..."
                            try {
                                Update-StepImage -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                    -ImageId $existingImage.sdkmessageprocessingstepimageid -ImageData $imageData
                                $totalImagesUpdated++
                                Write-LogSuccess "      Image updated"
                            }
                            catch {
                                Write-LogWarning "      Failed to update image: $($_.Exception.Message)"
                            }
                        } else {
                            Write-Log "      [WhatIf] Would update image"
                            $totalImagesUpdated++
                        }
                    } else {
                        if (-not $isWhatIf) {
                            Write-Log "      Creating new image..."
                            try {
                                $newImage = New-StepImage -ApiUrl $apiUrl -AuthHeaders $authHeaders -ImageData $imageData
                                $totalImagesCreated++
                                Write-LogSuccess "      Image created"
                                # Note: Step images are subcomponents - they're automatically included
                                # with their parent step, so we don't add them to the solution separately
                            }
                            catch {
                                Write-LogWarning "      Failed to create image: $($_.Exception.Message)"
                            }
                        } else {
                            Write-Log "      [WhatIf] Would create image"
                            $totalImagesCreated++
                        }
                    }
                }
            }
        }

        # Check for orphaned steps
        if (-not $isWhatIf -and $assembly) {
            Write-Log ""
            Write-Log "Checking for orphaned steps..."

            $existingSteps = Get-ProcessingStepsForAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                -AssemblyId $assembly.pluginassemblyid

            foreach ($existingStep in $existingSteps) {
                if ($configuredStepNames -notcontains $existingStep.name) {
                    if ($Force) {
                        Write-LogWarning "Deleting orphaned step: $($existingStep.name)"
                        try {
                            Remove-ProcessingStep -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                -StepId $existingStep.sdkmessageprocessingstepid
                            $totalOrphansDeleted++
                            Write-LogSuccess "  Deleted"
                        } catch {
                            Write-LogError "  Failed to delete: $($_.Exception.Message)"
                        }
                    } else {
                        Write-LogWarning "Orphaned step found: $($existingStep.name)"
                        Write-Log "  Use -Force to delete orphaned steps"
                        $totalOrphansWarned++
                    }
                }
            }
        }
    }

    # Summary
    Write-Log ""
    Write-Log ("=" * 60)
    Write-Log "Deployment Summary"
    Write-Log ("=" * 60)
    Write-LogSuccess "Steps created: $totalStepsCreated"
    Write-LogSuccess "Steps updated: $totalStepsUpdated"
    Write-LogSuccess "Images created: $totalImagesCreated"
    Write-LogSuccess "Images updated: $totalImagesUpdated"

    if ($totalOrphansWarned -gt 0) {
        Write-LogWarning "Orphaned steps (not deleted): $totalOrphansWarned"
    }
    if ($totalOrphansDeleted -gt 0) {
        Write-LogWarning "Orphaned steps deleted: $totalOrphansDeleted"
    }

    if ($isWhatIf) {
        Write-Log ""
        Write-LogWarning "WhatIf mode: No actual changes were made"
    }

    # Run drift detection if requested
    if ($DetectDrift -and -not $isWhatIf) {
        Write-Log ""
        Write-Log "Running post-deployment drift detection..."
        Get-DataversePluginDrift -RegistrationFile $RegistrationFile -Connection $Connection
    }

    return [PSCustomObject]@{
        StepsCreated = $totalStepsCreated
        StepsUpdated = $totalStepsUpdated
        ImagesCreated = $totalImagesCreated
        ImagesUpdated = $totalImagesUpdated
        OrphansWarned = $totalOrphansWarned
        OrphansDeleted = $totalOrphansDeleted
    }
}
