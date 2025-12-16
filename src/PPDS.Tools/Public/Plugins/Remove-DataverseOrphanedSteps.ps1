function Remove-DataverseOrphanedSteps {
    <#
    .SYNOPSIS
        Removes orphaned plugin steps that exist in Dataverse but not in configuration.

    .DESCRIPTION
        Compares the registrations.json configuration with Dataverse and removes
        any steps that exist in Dataverse but are not defined in the configuration.
        This is useful for cleaning up after plugin refactoring or removal.

    .PARAMETER RegistrationFile
        Path to the registrations.json file.

    .PARAMETER Connection
        DataverseConnection object from Connect-DataverseEnvironment.

    .PARAMETER AssemblyName
        Specific assembly name to clean up. If not provided, cleans all assemblies.

    .PARAMETER WhatIf
        Show what would be removed without making changes.

    .EXAMPLE
        $conn = Connect-DataverseEnvironment -Interactive
        Remove-DataverseOrphanedSteps -RegistrationFile "./registrations.json" -Connection $conn

    .EXAMPLE
        Remove-DataverseOrphanedSteps -RegistrationFile "./registrations.json" -Connection $conn -WhatIf
        Shows orphaned steps without removing them.

    .OUTPUTS
        Summary object with count of removed steps and images.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistrationFile,

        [Parameter(Mandatory = $true)]
        [DataverseConnection]$Connection,

        [Parameter()]
        [string]$AssemblyName
    )

    $isWhatIf = $WhatIfPreference -or $PSCmdlet.MyInvocation.BoundParameters["WhatIf"]

    if (-not (Test-Path $RegistrationFile)) {
        throw "Registration file not found: $RegistrationFile"
    }

    $registrations = Read-RegistrationJson -Path $RegistrationFile
    if (-not $registrations -or -not $registrations.assemblies) {
        throw "Invalid or empty registrations.json"
    }

    Write-Log "Orphaned Step Removal Tool"
    if ($isWhatIf) {
        Write-LogWarning "Running in WhatIf mode - no changes will be made"
    }

    $apiUrl = Get-WebApiBaseUrl -Connection $Connection
    $authHeaders = Get-AuthHeaders -Connection $Connection

    Write-LogSuccess "Connected to: $($Connection.ConnectedOrgFriendlyName)"

    $totalStepsDeleted = 0
    $totalImagesDeleted = 0
    $totalPluginTypesDeleted = 0

    foreach ($asmReg in $registrations.assemblies) {
        if ($AssemblyName -and $asmReg.name -ne $AssemblyName) {
            continue
        }

        Write-Log ""
        Write-Log ("=" * 60)
        Write-Log "Cleaning: $($asmReg.name)"
        Write-Log ("=" * 60)

        # Get assembly from Dataverse
        $assembly = Get-PluginAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders -Name $asmReg.name
        if (-not $assembly) {
            Write-LogWarning "Assembly not found in Dataverse: $($asmReg.name)"
            continue
        }

        # Build list of configured step names
        $configuredStepNames = @()
        foreach ($plugin in $asmReg.plugins) {
            foreach ($step in $plugin.steps) {
                $configuredStepNames += $step.name
            }
        }

        # Get all steps for this assembly from Dataverse
        $existingSteps = Get-ProcessingStepsForAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders `
            -AssemblyId $assembly.pluginassemblyid

        Write-Log "Found $($existingSteps.Count) step(s) in Dataverse"
        Write-Log "Configuration has $($configuredStepNames.Count) step(s)"

        # Find and remove orphaned steps
        foreach ($existingStep in $existingSteps) {
            if ($configuredStepNames -notcontains $existingStep.name) {
                if ($isWhatIf) {
                    Write-LogWarning "[WhatIf] Would delete orphaned step: $($existingStep.name)"
                    $totalStepsDeleted++
                }
                elseif ($PSCmdlet.ShouldProcess($existingStep.name, "Delete orphaned step")) {
                    Write-LogWarning "Deleting orphaned step: $($existingStep.name)"

                    # Delete images first
                    try {
                        $stepImages = Get-StepImages -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                            -StepId $existingStep.sdkmessageprocessingstepid
                        foreach ($image in $stepImages) {
                            Write-Log "  Deleting image: $($image.name)"
                            Remove-StepImage -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                -ImageId $image.sdkmessageprocessingstepimageid
                            $totalImagesDeleted++
                        }
                    } catch {
                        Write-LogDebug "  Could not query/delete images: $($_.Exception.Message)"
                    }

                    # Delete the step
                    try {
                        Remove-ProcessingStep -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                            -StepId $existingStep.sdkmessageprocessingstepid
                        $totalStepsDeleted++
                        Write-LogSuccess "  Step deleted"
                    } catch {
                        Write-LogError "  Failed to delete step: $($_.Exception.Message)"
                    }
                }
            }
        }

        # Check for orphaned plugin types (if allTypeNames is available)
        if ($asmReg.allTypeNames -and $asmReg.allTypeNames.Count -gt 0) {
            Write-Log ""
            Write-Log "Checking for orphaned plugin types..."

            $existingPluginTypes = Get-PluginTypesForAssembly -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                -AssemblyId $assembly.pluginassemblyid

            foreach ($existingType in $existingPluginTypes) {
                if ($existingType.typename -notin $asmReg.allTypeNames) {
                    $stepCount = Get-PluginTypeStepCount -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                        -PluginTypeId $existingType.plugintypeid

                    if ($stepCount -gt 0) {
                        Write-LogWarning "Orphaned plugin type '$($existingType.typename)' has $stepCount step(s)"
                        Write-Log "  Delete steps first before removing plugin type"
                    }
                    else {
                        if ($isWhatIf) {
                            Write-LogWarning "[WhatIf] Would delete orphaned plugin type: $($existingType.typename)"
                            $totalPluginTypesDeleted++
                        }
                        elseif ($PSCmdlet.ShouldProcess($existingType.typename, "Delete orphaned plugin type")) {
                            Write-LogWarning "Deleting orphaned plugin type: $($existingType.typename)"
                            try {
                                Remove-PluginType -ApiUrl $apiUrl -AuthHeaders $authHeaders `
                                    -PluginTypeId $existingType.plugintypeid
                                $totalPluginTypesDeleted++
                                Write-LogSuccess "  Plugin type deleted"
                            } catch {
                                Write-LogError "  Failed to delete plugin type: $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }
    }

    # Summary
    Write-Log ""
    Write-Log ("=" * 60)
    Write-Log "Cleanup Summary"
    Write-Log ("=" * 60)

    if ($totalStepsDeleted -eq 0 -and $totalImagesDeleted -eq 0 -and $totalPluginTypesDeleted -eq 0) {
        Write-LogSuccess "No orphaned components found"
    }
    else {
        if ($isWhatIf) {
            Write-LogWarning "Would delete:"
        } else {
            Write-LogSuccess "Deleted:"
        }
        Write-Log "  Steps: $totalStepsDeleted"
        Write-Log "  Images: $totalImagesDeleted"
        Write-Log "  Plugin types: $totalPluginTypesDeleted"
    }

    if ($isWhatIf) {
        Write-Log ""
        Write-LogWarning "WhatIf mode: No actual changes were made"
    }

    return [PSCustomObject]@{
        StepsDeleted = $totalStepsDeleted
        ImagesDeleted = $totalImagesDeleted
        PluginTypesDeleted = $totalPluginTypesDeleted
    }
}
